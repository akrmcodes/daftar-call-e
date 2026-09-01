// ============================================================================
// Edge Function: log-deep-link-click
// ============================================================================
// Stage 8.5 — Landing-page click analytics (Decision 2A).
//
// Stage 8.8 hardening:
//   This function carried its own hand-rolled token bucket that was both racy
//   and non-functional. On a hit it wrote back `last_refill` as the value it
//   had just read rather than "now", so elapsed time was re-counted from the
//   original anchor on every call: after one hour the bucket refilled to
//   capacity on every request and the limiter stopped limiting. It now uses the
//   same atomic `consume_rate_limit` RPC as every other endpoint.
// ============================================================================

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import type { Database } from "../_shared/database.types.ts";
import { logDeepLinkEvent } from "../_shared/deep_link_mint.ts";
import { clientIp, consumeNamedBucket } from "../_shared/rate_limit.ts";
import {
  corsHeaders,
  methodNotAllowed,
  optionsResponse,
} from "../_shared/http.ts";
import {
  bucketKeySegment,
  isValidOpaqueToken,
  optionalString,
  readJsonBody,
  truncate,
  USER_AGENT_MAX_LENGTH,
} from "../_shared/validation.ts";

interface ClickRequest {
  token?: string;
  platform?: string;
  user_agent?: string;
}

const CLICK_BUCKET_CAPACITY = 30;
const CLICK_BUCKET_REFILL_PER_HOUR = 15;
const PLATFORM_MAX_LENGTH = 32;

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

      // Analytics is best-effort: every path answers 204 so a landing page
      // never learns whether a token exists, and never blocks on our failures.
      const noContent = () =>
        new Response(null, { status: 204, headers: corsHeaders(req) });

      try {
        const body = await readJsonBody<ClickRequest>(req);
        const token = body.token?.trim() ?? "";
        if (!isValidOpaqueToken(token)) {
          return noContent();
        }

        const allowed = await consumeNamedBucket(ctx.supabaseAdmin, {
          key: `click:${bucketKeySegment(clientIp(req), 45)}`,
          capacity: CLICK_BUCKET_CAPACITY,
          refill_per_hour: CLICK_BUCKET_REFILL_PER_HOUR,
        });
        if (!allowed.allowed) {
          return noContent();
        }

        // A long User-Agent is not a client error, so truncate rather than
        // reject — but never store it unbounded.
        const rawUserAgent = typeof body.user_agent === "string"
          ? body.user_agent
          : req.headers.get("user-agent") ?? "";

        await logDeepLinkEvent(ctx.supabaseAdmin, "click", token, {
          platform: optionalString(
            body.platform,
            "platform",
            PLATFORM_MAX_LENGTH,
          ),
          user_agent: rawUserAgent.length > 0
            ? truncate(rawUserAgent, USER_AGENT_MAX_LENGTH)
            : null,
        });

        return noContent();
      } catch (error) {
        console.error("[log-deep-link-click] unhandled:", error);
        return noContent();
      }
    },
  ),
};
