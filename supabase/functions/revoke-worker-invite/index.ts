// ============================================================================
// Edge Function: revoke-worker-invite
// ============================================================================
// Stage 8.5 — Owner revokes a pending worker invite.
// ============================================================================

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import type { Database } from "../_shared/database.types.ts";
import {
  ForbiddenError,
  InternalError,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
  toErrorResponse,
  ValidationError,
} from "../_shared/http.ts";
import { requireSyncJwt } from "../_shared/verify_sync_jwt.ts";
import { readJsonBody, requireUuid } from "../_shared/validation.ts";

interface RevokeRequest {
  member_id?: string;
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

        const body = await readJsonBody<RevokeRequest>(req);
        const memberId = requireUuid(body?.member_id, "member_id");

        const admin = ctx.supabaseAdmin;
        const workspaceId = claims.workspace_id;

        const { data: member, error: memberError } = await admin
          .from("workspace_members")
          .select("id, workspace_id, status, seat_index")
          .eq("id", memberId)
          .eq("workspace_id", workspaceId)
          .maybeSingle();

        if (memberError) {
          console.error("member_lookup_failed:", memberError.message);
          throw new InternalError("Revoke failed");
        }

        if (!member) {
          return jsonResponse(
            { error: "Not found", code: "not_found" },
            404,
            req,
          );
        }

        if (member.status !== "pending" || member.seat_index === 0) {
          throw new ValidationError("Cannot revoke this member");
        }

        // Revoke the token first. If the delete then fails the invite is
        // already dead, which is the safe direction; doing it the other way
        // round would leave a live token pointing at a deleted seat.
        const { error: tokenError } = await admin
          .from("deep_link_tokens")
          .update({ state: "revoked" })
          .eq("workspace_id", workspaceId)
          .eq("kind", "worker_invite")
          .contains("intent_payload", { member_id: memberId })
          .eq("state", "active");

        if (tokenError) {
          console.error("revoke_token_update_failed:", tokenError.message);
          throw new InternalError("Revoke failed");
        }

        // Hard-delete the pending seat so UNIQUE (workspace_id, seat_index)
        // frees. This is the one deliberate exception to soft-delete-only: a
        // pending invite holds no financial data, and the seat index must be
        // reusable. Active members are never revoked through this path.
        const { error: deleteError } = await admin
          .from("workspace_members")
          .delete()
          .eq("id", memberId)
          .eq("workspace_id", workspaceId)
          .eq("status", "pending");

        if (deleteError) {
          console.error("member_delete_failed:", deleteError.message);
          throw new InternalError("Revoke failed");
        }

        return jsonResponse({ success: true, member_id: memberId }, 200, req);
      } catch (error) {
        return toErrorResponse("revoke-worker-invite", error, req);
      }
    },
  ),
};
