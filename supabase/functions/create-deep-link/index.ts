// ============================================================================
// Edge Function: create-deep-link
// ============================================================================
// Stage 8.5 — Mint share / referral deep-link tokens.
// ============================================================================

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import type { Database, Json } from "../_shared/database.types.ts";
import {
  buildDeepLinkUrl,
  logDeepLinkEvent,
  mintExpiresAt,
  mintOpaqueToken,
} from "../_shared/deep_link_mint.ts";
import {
  type DeepLinkIntentPayload,
  isTokenKind,
  type ReferralIntent,
  type ShareIntent,
  type TokenKind,
} from "../_shared/deep_link_types.ts";
import {
  clientIp,
  evaluateInviteRateLimit,
  rateLimitedResponse,
} from "../_shared/rate_limit.ts";
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
import {
  isValidEmail,
  normalizeEmail,
  readJsonBody,
} from "../_shared/validation.ts";

interface CreateRequest {
  kind?: string;
  intent_payload?: Record<string, unknown>;
}

function validateIntent(
  kind: TokenKind,
  raw: Record<string, unknown> | undefined,
): DeepLinkIntentPayload | null {
  if (!raw) return null;
  if (kind === "share") {
    const contactId = raw.contact_id;
    if (typeof contactId !== "string" || contactId.length === 0) return null;
    return { contact_id: contactId } satisfies ShareIntent;
  }
  if (kind === "referral") {
    const referrerId = raw.referrer_id;
    if (typeof referrerId !== "string" || referrerId.length === 0) return null;
    return { referrer_id: referrerId } satisfies ReferralIntent;
  }
  // worker_invite is minted by invite-worker only
  return null;
}

function canMint(role: string, kind: TokenKind): boolean {
  if (kind === "share") {
    return role === "owner" || role === "editor";
  }
  if (kind === "referral") {
    return role === "owner";
  }
  return false;
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
        const body = await readJsonBody<CreateRequest>(req);
        const kindRaw = body.kind?.trim() ?? "";

        if (!isTokenKind(kindRaw) || kindRaw === "worker_invite") {
          throw new ValidationError("Invalid kind");
        }

        if (!canMint(claims.workspace_role, kindRaw)) {
          throw new ForbiddenError("Insufficient role for this link kind");
        }

        const intent = validateIntent(kindRaw, body.intent_payload);
        if (!intent) {
          throw new ValidationError("Invalid intent_payload");
        }

        const admin = ctx.supabaseAdmin;
        const workspaceId = claims.workspace_id;

        // Only used as a rate-limit dimension; it is never persisted. Must be a
        // well-formed address so it cannot become an arbitrary bucket key.
        const destEmailRaw = body.intent_payload?.email;
        const destEmail = typeof destEmailRaw === "string" &&
            isValidEmail(normalizeEmail(destEmailRaw))
          ? normalizeEmail(destEmailRaw)
          : undefined;

        const rateResult = await evaluateInviteRateLimit(admin, {
          action: kindRaw,
          workspaceId,
          clientIp: clientIp(req),
          destEmail,
          queueOnGlobalTrip: {
            workspaceId,
            kind: kindRaw,
            payload: {
              intent_payload: intent,
            },
          },
        });
        if (!rateResult.allowed) {
          return rateLimitedResponse(rateResult.retryAfterSeconds);
        }

        const token = mintOpaqueToken();
        const expiresAt = mintExpiresAt(kindRaw);

        const { error } = await admin.from("deep_link_tokens").insert({
          token,
          workspace_id: workspaceId,
          kind: kindRaw,
          intent_payload: intent as unknown as Json,
          expires_at: expiresAt.toISOString(),
          state: "active",
          created_by: claims.identity_hash,
        });

        if (error) {
          console.error("create_deep_link_insert_failed:", error.message);
          throw new InternalError("Create failed");
        }

        await logDeepLinkEvent(admin, "created", token, {
          kind: kindRaw,
          workspace_id: workspaceId,
        });

        return jsonResponse(
          {
            token,
            url: buildDeepLinkUrl(token),
            expires_at: expiresAt.toISOString(),
          },
          200,
          req,
        );
      } catch (error) {
        // Previously every failure — including a database outage — returned
        // 401, which told the client to re-authenticate instead of retry.
        return toErrorResponse("create-deep-link", error, req);
      }
    },
  ),
};
