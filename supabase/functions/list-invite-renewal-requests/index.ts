// ============================================================================
// Edge Function: list-invite-renewal-requests
// ============================================================================
// Stage 8.5/8.6 — Owner inbox: pending invite renewal requests.
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

const MAX_PENDING_REQUESTS = 50;

export default {
  fetch: withSupabase<Database>(
    { auth: ["publishable"] },
    async (req, ctx) => {
      if (req.method === "OPTIONS") {
        return optionsResponse(req);
      }

      if (req.method !== "GET" && req.method !== "POST") {
        return methodNotAllowed(req);
      }

      try {
        const claims = await requireSyncJwt(req);

        if (claims.workspace_role !== "owner") {
          throw new ForbiddenError("Owner role required");
        }

        const admin = ctx.supabaseAdmin;
        const workspaceId = claims.workspace_id;

        const { data, error } = await admin
          .from("invite_renewal_requests")
          .select(
            "id, workspace_id, original_token, kind, intent_payload, created_at",
          )
          .eq("workspace_id", workspaceId)
          .eq("status", "pending")
          .order("created_at", { ascending: false })
          .limit(MAX_PENDING_REQUESTS);

        if (error) {
          console.error("renewal_requests_list_failed:", error.message);
          throw new InternalError("List failed");
        }

        return jsonResponse({ requests: data ?? [] }, 200, req);
      } catch (error) {
        return toErrorResponse("list-invite-renewal-requests", error, req);
      }
    },
  ),
};
