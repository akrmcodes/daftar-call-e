// ============================================================================
// Edge Function: fulfill-invite-renewal-request
// ============================================================================
// Stage 8.5/8.6 — Owner marks a renewal request fulfilled after re-invite.
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
} from "../_shared/http.ts";
import { requireSyncJwt } from "../_shared/verify_sync_jwt.ts";
import { readJsonBody, requireUuid } from "../_shared/validation.ts";

interface FulfillRequest {
  renewal_id?: string;
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

        const body = await readJsonBody<FulfillRequest>(req);
        const renewalId = requireUuid(body?.renewal_id, "renewal_id");

        const admin = ctx.supabaseAdmin;
        const workspaceId = claims.workspace_id;

        const { data, error } = await admin
          .from("invite_renewal_requests")
          .update({ status: "fulfilled" })
          .eq("id", renewalId)
          .eq("workspace_id", workspaceId)
          .eq("status", "pending")
          .select("id")
          .maybeSingle();

        if (error) {
          console.error("renewal_request_fulfill_failed:", error.message);
          throw new InternalError("Fulfil failed");
        }

        if (!data) {
          return jsonResponse(
            { error: "Not found", code: "not_found" },
            404,
            req,
          );
        }

        return jsonResponse({ success: true, renewal_id: renewalId }, 200, req);
      } catch (error) {
        return toErrorResponse("fulfill-invite-renewal-request", error, req);
      }
    },
  ),
};
