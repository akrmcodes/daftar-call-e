// ============================================================================
// Edge Function: request-new-invite
// ============================================================================
// Stage 8.5.1 — Expired-link ceremony: stub merchant ping (no FCM).
// ============================================================================

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import type { Database } from "../_shared/database.types.ts";
import { logDeepLinkEvent } from "../_shared/deep_link_mint.ts";
import type { TokenKind } from "../_shared/deep_link_types.ts";
import {
  clientIp,
  evaluateInviteRateLimit,
  rateLimitedResponse,
} from "../_shared/rate_limit.ts";
import {
  InternalError,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
  toErrorResponse,
  ValidationError,
} from "../_shared/http.ts";
import { tryRequireSyncJwt } from "../_shared/verify_sync_jwt.ts";
import { isValidOpaqueToken, readJsonBody } from "../_shared/validation.ts";

interface RenewRequest {
  token?: string;
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
        const body = await readJsonBody<RenewRequest>(req);
        const token = body.token?.trim() ?? "";
        if (!isValidOpaqueToken(token)) {
          throw new ValidationError("Invalid token");
        }

        const admin = ctx.supabaseAdmin;

        let requesterHash: string | null = null;
        const claims = await tryRequireSyncJwt(req);
        if (claims) {
          requesterHash = claims.identity_hash;
        }

        const rateKey = requesterHash ?? token.slice(0, 16);
        const rateResult = await evaluateInviteRateLimit(admin, {
          action: "renew_invite",
          clientIp: clientIp(req),
          renewKey: rateKey,
        });
        if (!rateResult.allowed) {
          return rateLimitedResponse(rateResult.retryAfterSeconds);
        }

        const { data, error } = await admin
          .from("deep_link_tokens")
          .select("token, kind, intent_payload, workspace_id, state")
          .eq("token", token)
          .maybeSingle();

        if (error || !data) {
          if (error) {
            console.error("renew_token_lookup_failed:", error.message);
          }
          // Anti-enumeration: succeed-shaped without revealing absence.
          return jsonResponse({ status: "notified" }, 200, req);
        }

        const row = data as {
          token: string;
          kind: TokenKind;
          intent_payload: Record<string, unknown>;
          workspace_id: string | null;
          state: string;
        };

        if (!row.workspace_id) {
          return jsonResponse({ status: "notified" }, 200, req);
        }

        const { error: insertError } = await admin
          .from("invite_renewal_requests")
          .insert({
            workspace_id: row.workspace_id,
            original_token: token,
            kind: row.kind,
            intent_payload: row.intent_payload,
            requester_identity_hash: requesterHash,
            status: "pending",
          });

        if (insertError) {
          console.error(
            "invite_renewal_requests_insert_failed:",
            insertError.message,
          );
          throw new InternalError("Request failed");
        }

        await logDeepLinkEvent(admin, "renewal_requested", token, {
          workspace_id: row.workspace_id,
          prior_state: row.state,
        });

        return jsonResponse(
          {
            status: "notified",
            workspace_id: row.workspace_id,
          },
          200,
          req,
        );
      } catch (error) {
        return toErrorResponse("request-new-invite", error, req);
      }
    },
  ),
};
