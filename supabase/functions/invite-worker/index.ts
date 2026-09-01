// ============================================================================
// Edge Function: invite-worker
// ============================================================================
// Stage 8.5 — Owner invites a worker by email with seat-cap enforcement.
//
// Stage 8.8 hardening (D1):
//   The concurrent-Editor cap was not enforced. The tally counted only rows
//   with role = 'editor' and omitted the Owner, who is editor-capable by
//   definition. Because a third worker is already rejected by the seat cap
//   earlier in the handler, `editors.length >= 2` could never be true — dead
//   code. A workspace could therefore reach Owner + 2 Editors: three
//   concurrent writers, three conflict pairs, where the client merge engine and
//   conflict-review UI were sized for exactly one pair.
//
//   Seat and editor caps keep their distinct failure modes:
//     seat cap   → 409 seat_cap_exceeded
//     editor cap → silent downgrade to viewer, reported via `role`
//
//   Both now resolve inside claim_worker_seat() under a workspace row lock, so
//   concurrent invites cannot both observe a stale tally.
// ============================================================================

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import type { Database, Json } from "../_shared/database.types.ts";
import { computeDeepLinkExpiresAt } from "../_shared/deep_link_types.ts";
import {
  buildDeepLinkUrl,
  mintOpaqueToken,
  tokenFingerprint,
} from "../_shared/deep_link_mint.ts";
import {
  clientIp,
  evaluateInviteRateLimit,
  rateLimitedResponse,
} from "../_shared/rate_limit.ts";
import {
  ConflictError,
  ForbiddenError,
  InternalError,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
  toErrorResponse,
  ValidationError,
} from "../_shared/http.ts";
import { requireSyncJwt } from "../_shared/verify_sync_jwt.ts";
import { readJsonBody, requireEmail } from "../_shared/validation.ts";

interface InviteRequest {
  invitee_email?: string;
  role?: string;
}

interface SeatClaim {
  member_id: string | null;
  effective_role: "owner" | "editor" | "viewer" | null;
  seat_index: number | null;
  outcome: string;
}

function requireWorkerRole(raw: unknown): "editor" | "viewer" {
  const role = typeof raw === "string" ? raw.trim().toLowerCase() : "viewer";
  if (role !== "editor" && role !== "viewer") {
    throw new ValidationError("Invalid role");
  }
  return role;
}

export default {
  fetch: withSupabase<Database>(
    { auth: ["publishable"] },
    async (req, ctx) => {
      if (req.method === "OPTIONS") {
        return optionsResponse(req);
      }
      if (req.method !== "POST") {
        return methodNotAllowed(req);
      }

      try {
        const claims = await requireSyncJwt(req);
        if (claims.workspace_role !== "owner") {
          throw new ForbiddenError("Owner role required");
        }

        const body = await readJsonBody<InviteRequest>(req);
        const inviteeEmail = requireEmail(body?.invitee_email, "invitee_email");
        const requestedRole = requireWorkerRole(body?.role);

        const workspaceId = claims.workspace_id;
        const admin = ctx.supabaseAdmin;

        // Never log the invitee address (PII) or the invite URL (it embeds the
        // bearer token — anyone with log access could redeem the invite).
        console.info(
          "invite_worker_start",
          JSON.stringify({
            workspace_id: workspaceId,
            requested_role: requestedRole,
          }),
        );

        const rateResult = await evaluateInviteRateLimit(admin, {
          action: "worker_invite",
          workspaceId,
          clientIp: clientIp(req),
          destEmail: inviteeEmail,
          queueOnGlobalTrip: {
            workspaceId,
            kind: "worker_invite",
            payload: {
              invitee_email: inviteeEmail,
              role: requestedRole,
            },
          },
        });
        if (!rateResult.allowed) {
          console.info(
            "invite_worker_rate_limited",
            JSON.stringify({
              workspace_id: workspaceId,
              retry_after: rateResult.retryAfterSeconds,
            }),
          );
          return rateLimitedResponse(rateResult.retryAfterSeconds);
        }

        const { data: seatData, error: seatError } = await admin.rpc(
          "claim_worker_seat",
          {
            p_workspace_id: workspaceId,
            p_invited_email: inviteeEmail,
            p_requested_role: requestedRole,
          },
        );

        if (seatError) {
          console.error("claim_worker_seat_failed:", seatError.message);
          throw new InternalError("Invite failed");
        }

        const seat = (Array.isArray(seatData) ? seatData[0] : seatData) as
          | SeatClaim
          | null;

        if (!seat) {
          throw new InternalError("Invite failed");
        }
        if (seat.outcome === "seat_cap_exceeded") {
          console.info(
            "invite_worker_seat_cap_exceeded",
            JSON.stringify({ workspace_id: workspaceId }),
          );
          throw new ConflictError("Seat cap exceeded", "seat_cap_exceeded");
        }
        if (seat.outcome === "workspace_not_found") {
          throw new ForbiddenError("Workspace unavailable");
        }
        if (!seat.member_id || !seat.effective_role) {
          throw new InternalError("Invite failed");
        }

        const memberId = seat.member_id;
        const effectiveRole = seat.effective_role;
        const wasReused = seat.outcome === "reused";

        if (effectiveRole !== requestedRole) {
          console.info(
            "invite_worker_role_downgraded",
            JSON.stringify({
              workspace_id: workspaceId,
              requested_role: requestedRole,
              effective_role: effectiveRole,
            }),
          );
        }

        // A reused seat may still carry a live token from the previous invite.
        const { error: supersedeError } = await admin
          .from("deep_link_tokens")
          .update({ state: "superseded" })
          .eq("workspace_id", workspaceId)
          .eq("kind", "worker_invite")
          .contains("intent_payload", { member_id: memberId })
          .eq("state", "active");

        if (supersedeError) {
          // The unique index on (member_id) for active worker_invite tokens
          // would reject the new token, so this must not be ignored.
          console.error(
            "invite_worker_supersede_failed:",
            supersedeError.message,
          );
          throw new InternalError("Invite failed");
        }

        const expiresAt = computeDeepLinkExpiresAt("worker_invite");
        const token = mintOpaqueToken();

        const { error: tokenError } = await admin.from("deep_link_tokens")
          .insert({
            token,
            workspace_id: workspaceId,
            kind: "worker_invite",
            intent_payload: {
              invited_email: inviteeEmail,
              role: effectiveRole,
              member_id: memberId,
            } as unknown as Json,
            expires_at: expiresAt.toISOString(),
            state: "active",
            created_by: claims.identity_hash,
          });

        if (tokenError) {
          console.error("deep_link_tokens_insert_failed:", tokenError.message);
          if (!wasReused) {
            // Free the pending seat: UNIQUE (workspace_id, seat_index) would
            // otherwise block the retry.
            const { error: rollbackError } = await admin
              .from("workspace_members")
              .delete()
              .eq("id", memberId)
              .eq("workspace_id", workspaceId)
              .eq("status", "pending");
            if (rollbackError) {
              console.error(
                "invite_worker_seat_rollback_failed:",
                rollbackError.message,
              );
            }
          }
          throw new InternalError("Invite failed");
        }

        console.info(
          "invite_worker_ok",
          JSON.stringify({
            workspace_id: workspaceId,
            member_id: memberId,
            effective_role: effectiveRole,
            token: tokenFingerprint(token),
          }),
        );

        return jsonResponse(
          {
            member_id: memberId,
            invite_url: buildDeepLinkUrl(token),
            role: effectiveRole,
            requested_role: requestedRole,
            role_downgraded: effectiveRole !== requestedRole,
            expires_at: expiresAt.toISOString(),
          },
          200,
          req,
        );
      } catch (error) {
        return toErrorResponse("invite-worker", error, req);
      }
    },
  ),
};
