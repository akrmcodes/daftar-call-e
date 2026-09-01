// ============================================================================
// Edge Function: resolve-deep-link
// ============================================================================
// Stage 8.5 — Read-only deep-link preview (no mutation).
// ============================================================================

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import type { Database } from "../_shared/database.types.ts";
import {
  type DeepLinkIntentPayload,
  type TokenKind,
  type TokenState,
} from "../_shared/deep_link_types.ts";
import {
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
} from "../_shared/http.ts";
import { tryRequireSyncJwt } from "../_shared/verify_sync_jwt.ts";
import {
  DEVICE_ID_MAX_LENGTH,
  isValidOpaqueToken,
  optionalString,
  readJsonBody,
} from "../_shared/validation.ts";

interface ResolveRequest {
  token?: string;
}

interface TokenRow {
  token: string;
  kind: TokenKind;
  intent_payload: DeepLinkIntentPayload;
  workspace_id: string | null;
  state: TokenState;
  expires_at: string;
  claimed_by: string | null;
}

export type DeepLinkResolveResult =
  | {
    status: "active";
    kind: TokenKind;
    intent: DeepLinkIntentPayload & { workspace_id?: string | null };
  }
  | { status: "expired" }
  | { status: "revoked" }
  | { status: "not_found" }
  | { status: "already_claimed"; claimed_by: "by_you" | "by_other" };

function mapTerminalState(
  row: TokenRow,
  claimer: string | null,
): DeepLinkResolveResult {
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

/** Anti-enumeration: collapse `not_found` → `revoked` for anonymous callers. */
function toAnonymousResolveResult(
  result: DeepLinkResolveResult,
): DeepLinkResolveResult {
  if (result.status === "not_found") {
    return { status: "revoked" };
  }
  return result;
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
        const body = await readJsonBody<ResolveRequest>(req);
        const token = body.token?.trim() ?? "";
        const claims = await tryRequireSyncJwt(req);

        if (!isValidOpaqueToken(token)) {
          const result: DeepLinkResolveResult = { status: "not_found" };
          return jsonResponse(
            claims ? result : toAnonymousResolveResult(result),
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
            "token, kind, intent_payload, workspace_id, state, expires_at, claimed_by",
          )
          .eq("token", token)
          .maybeSingle();

        if (error || !data) {
          if (error) {
            console.error("resolve_deep_link_lookup_failed:", error.message);
          }
          const result: DeepLinkResolveResult = { status: "not_found" };
          return jsonResponse(
            claims ? result : toAnonymousResolveResult(result),
            200,
            req,
          );
        }

        const row = data as unknown as TokenRow;

        if (
          row.state === "active" &&
          new Date(row.expires_at).getTime() < Date.now()
        ) {
          const result: DeepLinkResolveResult = { status: "expired" };
          return jsonResponse(
            claims ? result : toAnonymousResolveResult(result),
            200,
            req,
          );
        }

        if (row.state !== "active") {
          const result = mapTerminalState(row, claimer);
          return jsonResponse(
            claims ? result : toAnonymousResolveResult(result),
            200,
            req,
          );
        }

        const intent = {
          ...(row.intent_payload as unknown as Record<string, unknown>),
          workspace_id: row.workspace_id,
        };

        const result: DeepLinkResolveResult = {
          status: "active",
          kind: row.kind,
          intent: intent as DeepLinkIntentPayload & {
            workspace_id?: string | null;
          },
        };

        return jsonResponse(result, 200, req);
      } catch (error) {
        console.error("[resolve-deep-link] unhandled:", error);
        return jsonResponse(
          toAnonymousResolveResult({ status: "not_found" }),
          200,
          req,
        );
      }
    },
  ),
};
