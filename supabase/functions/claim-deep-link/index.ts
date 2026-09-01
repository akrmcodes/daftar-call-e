// ============================================================================
// Edge Function: claim-deep-link
// ============================================================================
// Stage 8.5 — Validate + bind deep-link tokens; typed claim results.
//
// Stage 8.8 hardening:
//   • The worker-activation write ignored its error. A failed activation still
//     marked the token claimed, permanently stranding the invitee: the token
//     was spent and the membership stayed pending.
//   • The claim was not atomic. Two concurrent claims both activated the
//     membership before either flipped the token, so a second identity could
//     bind to the same seat. The state transition now uses a conditional
//     update whose affected-row count is checked, and it happens BEFORE the
//     membership write so the token is the single point of serialisation.
// ============================================================================

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import type { Database } from "../_shared/database.types.ts";
import { logDeepLinkEvent } from "../_shared/deep_link_mint.ts";
import {
  type DeepLinkClaimResult,
  type DeepLinkIntentPayload,
  toAnonymousClaimResult,
  type TokenKind,
  type TokenState,
  type WorkerInviteIntent,
} from "../_shared/deep_link_types.ts";
import type { AdminClient } from "../_shared/sync_ops.ts";
import {
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
} from "../_shared/http.ts";
import {
  type SyncJwtClaims,
  tryRequireSyncJwt,
} from "../_shared/verify_sync_jwt.ts";
import {
  DEVICE_ID_MAX_LENGTH,
  isValidOpaqueToken,
  normalizeEmail,
  optionalString,
  readJsonBody,
} from "../_shared/validation.ts";

interface ClaimRequest {
  token?: string;
  google_email?: string;
}

interface TokenRow {
  token: string;
  kind: TokenKind;
  intent_payload: DeepLinkIntentPayload;
  workspace_id: string | null;
  state: TokenState;
  expires_at: string;
  claimed_by: string | null;
  claimed_at: string | null;
}

function isWorkerInviteIntent(
  intent: DeepLinkIntentPayload,
): intent is WorkerInviteIntent {
  return "member_id" in intent && "invited_email" in intent;
}

/**
 * Flips an active token to claimed, returning false when another request got
 * there first. The `state = 'active'` predicate makes this a compare-and-swap.
 */
async function transitionToClaimed(
  admin: AdminClient,
  token: string,
  claimer: string,
): Promise<boolean> {
  const { data, error } = await admin
    .from("deep_link_tokens")
    .update({
      state: "claimed",
      claimed_by: claimer,
      claimed_at: new Date().toISOString(),
    })
    .eq("token", token)
    .eq("state", "active")
    .select("token");

  if (error) {
    console.error("deep_link_claim_update_failed:", error.message);
    return false;
  }
  return (data ?? []).length > 0;
}

/** Reverts a claim when a dependent step fails, so the invite stays usable. */
async function revertClaim(admin: AdminClient, token: string): Promise<void> {
  const { error } = await admin
    .from("deep_link_tokens")
    .update({ state: "active", claimed_by: null, claimed_at: null })
    .eq("token", token)
    .eq("state", "claimed");
  if (error) {
    console.error("deep_link_claim_revert_failed:", error.message);
  }
}

async function claimActiveToken(
  admin: AdminClient,
  row: TokenRow,
  claims: SyncJwtClaims | null,
  deviceHash: string | null,
  googleEmail: string | null,
): Promise<DeepLinkClaimResult> {
  const claimer = claims?.identity_hash ?? deviceHash;
  if (!claimer) {
    return { status: "not_found" };
  }

  if (row.kind !== "worker_invite") {
    return await transitionToClaimed(admin, row.token, claimer)
      ? {
        status: "ok",
        kind: row.kind,
        intent: {
          ...(row.intent_payload as unknown as Record<string, unknown>),
          workspace_id: row.workspace_id,
        } as unknown as DeepLinkIntentPayload,
      }
      : { status: "already_claimed", claimed_by: "by_other" };
  }

  // Worker invites bind a seat, so every identity precondition is checked
  // before the token is spent.
  if (!claims || !isWorkerInviteIntent(row.intent_payload)) {
    return { status: "not_found" };
  }

  const invited = normalizeEmail(row.intent_payload.invited_email);

  const { data: member, error: memberError } = await admin
    .from("workspace_members")
    .select("id, invited_email, status, workspace_id")
    .eq("id", row.intent_payload.member_id)
    .maybeSingle();

  if (memberError) {
    console.error("claim_member_lookup_failed:", memberError.message);
    return { status: "not_found" };
  }

  const memberRow = member as {
    id: string;
    invited_email: string | null;
    status: string;
    workspace_id: string;
  } | null;

  if (!memberRow || memberRow.workspace_id !== row.workspace_id) {
    return { status: "not_found" };
  }

  const memberEmail = memberRow.invited_email
    ? normalizeEmail(memberRow.invited_email)
    : "";
  if (memberEmail !== invited) {
    return { status: "not_found" };
  }

  const normalizedGoogle = googleEmail ? normalizeEmail(googleEmail) : "";
  if (!normalizedGoogle || normalizedGoogle !== invited) {
    return { status: "not_found" };
  }

  // Spend the token first: it is the serialisation point for the seat binding.
  if (!await transitionToClaimed(admin, row.token, claimer)) {
    return { status: "already_claimed", claimed_by: "by_other" };
  }

  const { error: activateError } = await admin
    .from("workspace_members")
    .update({
      status: "active",
      identity_hash: claims.identity_hash,
      updated_at: new Date().toISOString(),
    })
    .eq("id", memberRow.id)
    .eq("workspace_id", memberRow.workspace_id);

  if (activateError) {
    console.error("claim_member_activate_failed:", activateError.message);
    await revertClaim(admin, row.token);
    return { status: "not_found" };
  }

  return {
    status: "ok",
    kind: row.kind,
    intent: {
      ...(row.intent_payload as unknown as Record<string, unknown>),
      workspace_id: row.workspace_id,
    } as unknown as DeepLinkIntentPayload,
  };
}

function mapTerminalState(
  row: TokenRow,
  claimer: string | null,
): DeepLinkClaimResult {
  if (row.state === "expired") {
    return { status: "expired" };
  }
  if (row.state === "revoked" || row.state === "superseded") {
    return { status: "revoked" };
  }
  if (row.state === "claimed") {
    if (claimer && row.claimed_by === claimer) {
      return { status: "already_claimed", claimed_by: "by_you" };
    }
    return { status: "already_claimed", claimed_by: "by_other" };
  }
  return { status: "not_found" };
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

      // Every outcome is a 200 with a typed `status`, so a caller cannot
      // distinguish "no such token" from "revoked" by status code or shape.
      try {
        const body = await readJsonBody<ClaimRequest>(req);
        const token = body.token?.trim() ?? "";
        const googleEmail = optionalString(
          body.google_email,
          "google_email",
          254,
        );
        const claims = await tryRequireSyncJwt(req);

        if (!isValidOpaqueToken(token)) {
          return jsonResponse(
            toAnonymousClaimResult({ status: "not_found" }),
            200,
            req,
          );
        }

        const deviceHash = optionalString(
          req.headers.get("x-device-id"),
          "x-device-id",
          DEVICE_ID_MAX_LENGTH,
        );
        const claimer = claims?.identity_hash ?? deviceHash;
        const admin = ctx.supabaseAdmin;

        const { data, error } = await admin
          .from("deep_link_tokens")
          .select(
            "token, kind, intent_payload, workspace_id, state, expires_at, claimed_by, claimed_at",
          )
          .eq("token", token)
          .maybeSingle();

        if (error || !data) {
          if (error) {
            console.error("deep_link_lookup_failed:", error.message);
          }
          const result: DeepLinkClaimResult = { status: "not_found" };
          await logDeepLinkEvent(admin, "claim_terminal", token, {
            status: "not_found",
          });
          return jsonResponse(
            claims ? result : toAnonymousClaimResult(result),
            200,
            req,
          );
        }

        const row = data as unknown as TokenRow;

        if (
          row.state === "active" &&
          new Date(row.expires_at).getTime() < Date.now()
        ) {
          const { error: expireError } = await admin
            .from("deep_link_tokens")
            .update({ state: "expired" })
            .eq("token", token)
            .eq("state", "active");
          if (expireError) {
            console.error("deep_link_expire_failed:", expireError.message);
          }
          const result: DeepLinkClaimResult = { status: "expired" };
          await logDeepLinkEvent(admin, "claim_terminal", token, {
            status: "expired",
          });
          return jsonResponse(
            claims ? result : toAnonymousClaimResult(result),
            200,
            req,
          );
        }

        if (row.state !== "active") {
          const result = mapTerminalState(row, claimer);
          await logDeepLinkEvent(admin, "claim_terminal", token, {
            status: result.status,
          });
          return jsonResponse(
            claims ? result : toAnonymousClaimResult(result),
            200,
            req,
          );
        }

        const result = await claimActiveToken(
          admin,
          row,
          claims,
          deviceHash,
          googleEmail,
        );
        await logDeepLinkEvent(
          admin,
          result.status === "ok" ? "claim_ok" : "claim_terminal",
          token,
          result.status === "ok"
            ? { kind: result.kind }
            : { status: result.status },
        );

        return jsonResponse(
          claims ? result : toAnonymousClaimResult(result),
          200,
          req,
        );
      } catch (error) {
        console.error("[claim-deep-link] unhandled:", error);
        return jsonResponse(
          toAnonymousClaimResult({ status: "not_found" }),
          200,
          req,
        );
      }
    },
  ),
};
