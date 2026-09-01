// ============================================================================
// Stage 8.7 — Multi-dimensional invite rate limiting + global circuit breaker
// ============================================================================
// Tier resolution (Stage 8.8): the schedule applied to a caller is derived from
// that workspace's own entitlement, read from `workspaces.tier`. Previously
// `resolveRateTier()` read only the deploy-wide `INVITE_RATE_TIER_DEFAULT` env
// var and defaulted to `pro_plus`; no call site ever passed a tier, so
// PRO_SCHEDULES was unreachable and every merchant — Free, Pro or Pro+ —
// received Pro+ limits.
//
// Resolution order, most to least specific:
//   1. an explicit `ctx.tier`
//   2. `workspaces.tier` for `ctx.workspaceId`
//   3. `INVITE_RATE_TIER_DEFAULT` (transitional override for deployments whose
//      entitlements are not yet stamped server-side)
//   4. the strictest schedule
//
// Steps 3 and 4 are the fail-closed path: an unknown tier is never granted the
// looser schedule.
// ============================================================================

import type { Json } from "./database.types.ts";
import type { AdminClient } from "./sync_ops.ts";
import { CORS_HEADERS } from "./http.ts";
import { bucketKeySegment, normalizeEmail } from "./validation.ts";

export type RateAction =
  | "worker_invite"
  | "share"
  | "referral"
  | "renew_invite";

export type RateTier = "free" | "pro" | "pro_plus";

/** Ascending permissiveness. Index 0 is the fail-closed choice. */
export const RATE_TIERS_BY_STRICTNESS: readonly RateTier[] = [
  "free",
  "pro",
  "pro_plus",
];

export const STRICTEST_RATE_TIER: RateTier = RATE_TIERS_BY_STRICTNESS[0];

export interface RateLimitCheck {
  key: string;
  capacity: number;
  refill_per_hour: number;
  cost?: number;
}

export interface InviteRateLimitContext {
  action: RateAction;
  workspaceId?: string;
  clientIp: string;
  destEmail?: string;
  renewKey?: string;
  tier?: RateTier;
  queueOnGlobalTrip?: {
    workspaceId: string;
    kind: string;
    payload: Record<string, unknown>;
  };
}

export interface RateLimitEvaluation {
  allowed: boolean;
  retryAfterSeconds: number;
}

interface BucketSchedule {
  capacity: number;
  refillPerHour: number;
}

interface ActionSchedule {
  workspaceHour?: BucketSchedule;
  workspaceDay?: BucketSchedule;
  ipHour: BucketSchedule;
  destEmail?: BucketSchedule;
  destDomain?: BucketSchedule;
  renewHour?: BucketSchedule;
  globalHour: BucketSchedule;
}

const PRO_PLUS_SCHEDULES: Record<RateAction, ActionSchedule> = {
  worker_invite: {
    workspaceHour: { capacity: 3, refillPerHour: 3 },
    workspaceDay: { capacity: 10, refillPerHour: 10 / 24 },
    ipHour: { capacity: 30, refillPerHour: 30 },
    destEmail: { capacity: 1, refillPerHour: 1 },
    destDomain: { capacity: 5, refillPerHour: 5 },
    globalHour: { capacity: 200, refillPerHour: 200 },
  },
  share: {
    workspaceHour: { capacity: 20, refillPerHour: 20 },
    workspaceDay: { capacity: 100, refillPerHour: 100 / 24 },
    ipHour: { capacity: 30, refillPerHour: 30 },
    destEmail: { capacity: 1, refillPerHour: 1 },
    destDomain: { capacity: 5, refillPerHour: 5 },
    globalHour: { capacity: 200, refillPerHour: 200 },
  },
  referral: {
    workspaceHour: { capacity: 20, refillPerHour: 20 },
    workspaceDay: { capacity: 100, refillPerHour: 100 / 24 },
    ipHour: { capacity: 30, refillPerHour: 30 },
    destEmail: { capacity: 1, refillPerHour: 1 },
    destDomain: { capacity: 5, refillPerHour: 5 },
    globalHour: { capacity: 200, refillPerHour: 200 },
  },
  renew_invite: {
    ipHour: { capacity: 10, refillPerHour: 10 },
    renewHour: { capacity: 5, refillPerHour: 2 },
    globalHour: { capacity: 200, refillPerHour: 200 },
  },
};

const PRO_SCHEDULES: Record<RateAction, ActionSchedule> = {
  worker_invite: {
    workspaceHour: { capacity: 2, refillPerHour: 2 },
    workspaceDay: { capacity: 5, refillPerHour: 5 / 24 },
    ipHour: { capacity: 15, refillPerHour: 15 },
    destEmail: { capacity: 1, refillPerHour: 1 },
    destDomain: { capacity: 3, refillPerHour: 3 },
    globalHour: { capacity: 100, refillPerHour: 100 },
  },
  share: {
    workspaceHour: { capacity: 10, refillPerHour: 10 },
    workspaceDay: { capacity: 50, refillPerHour: 50 / 24 },
    ipHour: { capacity: 15, refillPerHour: 15 },
    destEmail: { capacity: 1, refillPerHour: 1 },
    destDomain: { capacity: 3, refillPerHour: 3 },
    globalHour: { capacity: 100, refillPerHour: 100 },
  },
  referral: {
    workspaceHour: { capacity: 10, refillPerHour: 10 },
    workspaceDay: { capacity: 50, refillPerHour: 50 / 24 },
    ipHour: { capacity: 15, refillPerHour: 15 },
    destEmail: { capacity: 1, refillPerHour: 1 },
    destDomain: { capacity: 3, refillPerHour: 3 },
    globalHour: { capacity: 100, refillPerHour: 100 },
  },
  renew_invite: {
    ipHour: { capacity: 5, refillPerHour: 5 },
    renewHour: { capacity: 3, refillPerHour: 1 },
    globalHour: { capacity: 100, refillPerHour: 100 },
  },
};

/**
 * Free tier.
 *
 * Per docs/product/pricing-feature-matrix.md, workers, multi-device sync and the
 * customer portal are Pro+ features, so a correctly entitled Free workspace
 * should never reach these endpoints at all. That gate belongs to the
 * entitlement layer, which is not yet server-side — see the Stage 8.8 report.
 * Until it exists this schedule is the backstop, and it is deliberately the
 * tightest of the three rather than zero: zero would hard-break the currently
 * working invite flow for every workspace whose tier is not yet stamped.
 *
 * `globalHour` matches PRO so that a Free caller evaluating the shared global
 * breaker cannot shrink it below the Pro capacity.
 */
const FREE_SCHEDULES: Record<RateAction, ActionSchedule> = {
  worker_invite: {
    workspaceHour: { capacity: 1, refillPerHour: 1 },
    workspaceDay: { capacity: 2, refillPerHour: 2 / 24 },
    ipHour: { capacity: 5, refillPerHour: 5 },
    destEmail: { capacity: 1, refillPerHour: 1 },
    destDomain: { capacity: 2, refillPerHour: 2 },
    globalHour: { capacity: 100, refillPerHour: 100 },
  },
  share: {
    workspaceHour: { capacity: 5, refillPerHour: 5 },
    workspaceDay: { capacity: 10, refillPerHour: 10 / 24 },
    ipHour: { capacity: 5, refillPerHour: 5 },
    destEmail: { capacity: 1, refillPerHour: 1 },
    destDomain: { capacity: 2, refillPerHour: 2 },
    globalHour: { capacity: 100, refillPerHour: 100 },
  },
  referral: {
    workspaceHour: { capacity: 5, refillPerHour: 5 },
    workspaceDay: { capacity: 10, refillPerHour: 10 / 24 },
    ipHour: { capacity: 5, refillPerHour: 5 },
    destEmail: { capacity: 1, refillPerHour: 1 },
    destDomain: { capacity: 2, refillPerHour: 2 },
    globalHour: { capacity: 100, refillPerHour: 100 },
  },
  renew_invite: {
    ipHour: { capacity: 3, refillPerHour: 3 },
    renewHour: { capacity: 2, refillPerHour: 1 },
    globalHour: { capacity: 100, refillPerHour: 100 },
  },
};

export const schedules: Record<RateTier, Record<RateAction, ActionSchedule>> = {
  free: FREE_SCHEDULES,
  pro: PRO_SCHEDULES,
  pro_plus: PRO_PLUS_SCHEDULES,
};

/** Accepts `pro_plus`, `proplus`, `pro+` and friends. Null when unrecognised. */
export function normalizeRateTier(raw: unknown): RateTier | null {
  if (typeof raw !== "string") return null;
  const value = raw.trim().toLowerCase();
  if (value === "free") return "free";
  if (value === "pro") return "pro";
  if (value === "pro_plus" || value === "proplus" || value === "pro+") {
    return "pro_plus";
  }
  return null;
}

/**
 * Resolves the schedule tier for a caller.
 *
 * @param explicit tier already known for this caller, if any.
 * @returns the explicit tier, else the `INVITE_RATE_TIER_DEFAULT` override,
 *   else the strictest tier. Never returns the loosest tier by default.
 */
export function resolveRateTier(explicit?: RateTier | string | null): RateTier {
  const fromCaller = normalizeRateTier(explicit);
  if (fromCaller) return fromCaller;

  const fromEnv = normalizeRateTier(Deno.env.get("INVITE_RATE_TIER_DEFAULT"));
  if (fromEnv) return fromEnv;

  return STRICTEST_RATE_TIER;
}

/**
 * Reads the workspace's server-side entitlement tier.
 * Returns null when unknown (column not yet stamped, row missing, or the read
 * failed), which routes the caller to the fail-closed path.
 */
export async function fetchWorkspaceTier(
  admin: AdminClient,
  workspaceId: string,
): Promise<RateTier | null> {
  const { data, error } = await admin
    .from("workspaces")
    .select("tier")
    .eq("id", workspaceId)
    .maybeSingle();

  if (error) {
    console.error(
      "workspace_tier_lookup_failed",
      JSON.stringify({ code: error.code ?? null }),
    );
    return null;
  }

  return normalizeRateTier((data as { tier?: string | null } | null)?.tier);
}

export function clientIp(req: Request): string {
  const forwarded = req.headers.get("x-forwarded-for");
  if (forwarded) {
    const first = forwarded.split(",")[0]?.trim();
    if (first) return first;
  }
  const cfIp = req.headers.get("cf-connecting-ip")?.trim();
  if (cfIp) return cfIp;
  return "unknown";
}

export function emailDomain(email: string): string | null {
  const normalized = normalizeEmail(email);
  const at = normalized.lastIndexOf("@");
  if (at <= 0 || at === normalized.length - 1) return null;
  return normalized.slice(at + 1);
}

function workspaceKindKey(action: RateAction): string {
  switch (action) {
    case "worker_invite":
      return "worker";
    case "share":
      return "share";
    case "referral":
      return "referral";
    default:
      return action;
  }
}

/**
 * Builds the per-dimension bucket checks for a call.
 * Every caller-controlled key segment is sanitised and length-bounded:
 * `rate_limit_buckets.bucket_key` is a primary key, so unbounded segments would
 * let a caller grow that table without limit.
 */
export function buildInviteRateLimitChecks(
  ctx: InviteRateLimitContext,
): RateLimitCheck[] {
  const tier = resolveRateTier(ctx.tier);
  const schedule = schedules[tier][ctx.action];
  const checks: RateLimitCheck[] = [];

  if (ctx.workspaceId && schedule.workspaceHour) {
    const kind = workspaceKindKey(ctx.action);
    checks.push({
      key: `ws:${bucketKeySegment(ctx.workspaceId)}:${kind}:h`,
      capacity: schedule.workspaceHour.capacity,
      refill_per_hour: schedule.workspaceHour.refillPerHour,
    });
  }

  if (ctx.workspaceId && schedule.workspaceDay) {
    const kind = workspaceKindKey(ctx.action);
    checks.push({
      key: `ws:${bucketKeySegment(ctx.workspaceId)}:${kind}:d`,
      capacity: schedule.workspaceDay.capacity,
      refill_per_hour: schedule.workspaceDay.refillPerHour,
    });
  }

  if (schedule.renewHour && ctx.renewKey) {
    checks.push({
      key: `renew:${bucketKeySegment(ctx.renewKey)}:h`,
      capacity: schedule.renewHour.capacity,
      refill_per_hour: schedule.renewHour.refillPerHour,
    });
  }

  checks.push({
    key: `ip:${bucketKeySegment(ctx.clientIp, 45)}:invite:h`,
    capacity: schedule.ipHour.capacity,
    refill_per_hour: schedule.ipHour.refillPerHour,
  });

  if (ctx.destEmail && schedule.destEmail) {
    const normalized = normalizeEmail(ctx.destEmail);
    checks.push({
      key: `email:${bucketKeySegment(normalized, 254)}`,
      capacity: schedule.destEmail.capacity,
      refill_per_hour: schedule.destEmail.refillPerHour,
    });

    const domain = emailDomain(normalized);
    if (domain && schedule.destDomain) {
      checks.push({
        key: `domain:${bucketKeySegment(domain, 253)}`,
        capacity: schedule.destDomain.capacity,
        refill_per_hour: schedule.destDomain.refillPerHour,
      });
    }
  }

  return checks;
}

export function globalInviteCheck(
  ctx: InviteRateLimitContext,
): RateLimitCheck {
  const tier = resolveRateTier(ctx.tier);
  const schedule = schedules[tier][ctx.action];
  return {
    key: "global:invite:h",
    capacity: schedule.globalHour.capacity,
    refill_per_hour: schedule.globalHour.refillPerHour,
  };
}

function readEvaluation(
  data: unknown,
  rpcName: string,
): RateLimitEvaluation {
  const row = Array.isArray(data) ? data[0] : data;
  if (!row || typeof row !== "object") {
    // An empty result is not a grant: the limiter could not prove the call is
    // within budget, so deny.
    console.error("rate_limit_empty_result", JSON.stringify({ rpc: rpcName }));
    return { allowed: false, retryAfterSeconds: 60 };
  }

  const allowed = Boolean((row as { allowed?: boolean }).allowed);
  const retryRaw =
    (row as { retry_after_seconds?: number }).retry_after_seconds;
  const retryAfterSeconds = typeof retryRaw === "number" && retryRaw > 0
    ? Math.ceil(retryRaw)
    : allowed
    ? 0
    : 3600;

  return { allowed, retryAfterSeconds };
}

async function consumeChecks(
  admin: AdminClient,
  checks: RateLimitCheck[],
): Promise<RateLimitEvaluation> {
  if (checks.length === 0) {
    return { allowed: true, retryAfterSeconds: 0 };
  }

  const { data, error } = await admin.rpc("consume_rate_limits", {
    p_checks: checks as unknown as Json,
  });

  if (error) {
    console.error(
      "consume_rate_limits_failed",
      JSON.stringify({ code: error.code ?? null }),
      error.message,
    );
    return { allowed: false, retryAfterSeconds: 3600 };
  }

  return readEvaluation(data, "consume_rate_limits");
}

async function consumeSingleCheck(
  admin: AdminClient,
  check: RateLimitCheck,
): Promise<RateLimitEvaluation> {
  const { data, error } = await admin.rpc("consume_rate_limit", {
    p_bucket_key: check.key,
    p_capacity: check.capacity,
    p_refill_per_hour: check.refill_per_hour,
    p_cost: check.cost ?? 1,
  });

  if (error) {
    console.error(
      "consume_rate_limit_failed",
      JSON.stringify({ code: error.code ?? null }),
      error.message,
    );
    return { allowed: false, retryAfterSeconds: 3600 };
  }

  return readEvaluation(data, "consume_rate_limit");
}

/** Consumes a single named bucket. Used by unauthenticated analytics paths. */
export async function consumeNamedBucket(
  admin: AdminClient,
  check: RateLimitCheck,
): Promise<RateLimitEvaluation> {
  return await consumeSingleCheck(admin, check);
}

// ── Sign-in abuse limiter (FAIL OPEN) ───────────────────────────────────────
//
// verify-google-token is the SOLE token issuance path for the product. Every
// other limiter in this module fails CLOSED, which is right when the worst
// case is an undelivered invite. Here the worst case is every merchant in the
// market locked out of their own ledger, which is far worse than the abuse the
// limiter prevents. So this pair fails OPEN on any limiter malfunction.
//
// Two properties keep that from being a free pass for attackers:
//
//   1. Only FAILED verifications consume budget. A legitimate sign-in never
//      touches the bucket. This matters specifically for this product's market:
//      Yemeni carriers put very large numbers of subscribers behind a handful of
//      CGNAT addresses, so an IP limit that counted successes would eventually
//      lock out an entire carrier. Counting only failures means a shared IP is
//      throttled solely by how much invalid traffic it emits.
//   2. The gate is a peek, not a consume, so a blocked attacker cannot deepen
//      their own hole and legitimate traffic from the same IP recovers as the
//      bucket refills.

/** Failed sign-ins tolerated per IP per hour before the gate closes. */
export const AUTH_FAILURE_CAPACITY = 20;
export const AUTH_FAILURE_REFILL_PER_HOUR = 20;

export function authFailureBucketKey(ip: string): string {
  return `authfail:${bucketKeySegment(ip, 45)}:h`;
}

/**
 * Decides whether to admit an unauthenticated sign-in attempt.
 *
 * FAILS OPEN: any RPC error, malformed result or empty result admits the
 * request. Only an explicit `allowed === false` from the limiter blocks it.
 */
export async function authFailureGate(
  admin: AdminClient,
  ip: string,
): Promise<RateLimitEvaluation> {
  try {
    const { data, error } = await admin.rpc("peek_rate_limit", {
      p_bucket_key: authFailureBucketKey(ip),
      p_capacity: AUTH_FAILURE_CAPACITY,
      p_refill_per_hour: AUTH_FAILURE_REFILL_PER_HOUR,
      p_cost: 1,
    });

    if (error) {
      console.error(
        "auth_failure_gate_unavailable_failing_open",
        JSON.stringify({ code: error.code ?? null }),
      );
      return { allowed: true, retryAfterSeconds: 0 };
    }

    const row = Array.isArray(data) ? data[0] : data;
    if (!row || typeof row !== "object") {
      console.error("auth_failure_gate_empty_result_failing_open");
      return { allowed: true, retryAfterSeconds: 0 };
    }

    // Anything other than an explicit denial is a grant.
    if ((row as { allowed?: unknown }).allowed !== false) {
      return { allowed: true, retryAfterSeconds: 0 };
    }

    const retryRaw = (row as { retry_after_seconds?: unknown })
      .retry_after_seconds;
    const retryAfterSeconds = typeof retryRaw === "number" && retryRaw > 0
      ? Math.ceil(retryRaw)
      : 300;
    return { allowed: false, retryAfterSeconds };
  } catch (thrown) {
    // A thrown client error (network, timeout) must not become a lockout.
    console.error(
      "auth_failure_gate_threw_failing_open",
      thrown instanceof Error ? thrown.message : String(thrown),
    );
    return { allowed: true, retryAfterSeconds: 0 };
  }
}

/**
 * Charges one token after a verification failure. Best effort: a limiter that
 * cannot record the failure must never fail the request it was called from.
 */
export async function recordAuthFailure(
  admin: AdminClient,
  ip: string,
): Promise<void> {
  try {
    const { error } = await admin.rpc("consume_rate_limit", {
      p_bucket_key: authFailureBucketKey(ip),
      p_capacity: AUTH_FAILURE_CAPACITY,
      p_refill_per_hour: AUTH_FAILURE_REFILL_PER_HOUR,
      p_cost: 1,
    });
    if (error) {
      console.error(
        "record_auth_failure_failed",
        JSON.stringify({ code: error.code ?? null }),
      );
    }
  } catch (thrown) {
    console.error(
      "record_auth_failure_threw",
      thrown instanceof Error ? thrown.message : String(thrown),
    );
  }
}

async function recordGlobalCircuitTrip(
  admin: AdminClient,
  ctx: InviteRateLimitContext,
  retryAfterSeconds: number,
): Promise<void> {
  const queue = ctx.queueOnGlobalTrip;
  if (queue) {
    const availableAt = new Date(Date.now() + retryAfterSeconds * 1000);
    const { error: queueError } = await admin.from("invite_send_queue").insert({
      workspace_id: queue.workspaceId,
      kind: queue.kind,
      payload: queue.payload as Json,
      status: "pending",
      available_at: availableAt.toISOString(),
    });
    if (queueError) {
      console.error("invite_send_queue_insert_failed:", queueError.message);
    }
  }

  const { error: alertError } = await admin.from("ops_alert_events").insert({
    alert_type: "global_invite_circuit_open",
    detail: {
      action: ctx.action,
      workspace_id: ctx.workspaceId ?? queue?.workspaceId ?? null,
      retry_after_seconds: retryAfterSeconds,
    } as Json,
  });
  if (alertError) {
    console.error("ops_alert_events_insert_failed:", alertError.message);
  }
}

/**
 * Evaluates every dimension for a call, then the global circuit breaker.
 *
 * Resolves the caller's tier from their workspace entitlement when the context
 * does not already carry one, so no call site can silently fall back to the
 * loosest schedule by forgetting to pass it.
 */
export async function evaluateInviteRateLimit(
  admin: AdminClient,
  ctx: InviteRateLimitContext,
): Promise<RateLimitEvaluation> {
  let resolved = ctx;
  if (!ctx.tier && ctx.workspaceId) {
    const tier = await fetchWorkspaceTier(admin, ctx.workspaceId);
    resolved = { ...ctx, tier: resolveRateTier(tier) };
  }

  const dimensionChecks = buildInviteRateLimitChecks(resolved);
  const dimensionResult = await consumeChecks(admin, dimensionChecks);
  if (!dimensionResult.allowed) {
    return dimensionResult;
  }

  const globalResult = await consumeSingleCheck(
    admin,
    globalInviteCheck(resolved),
  );
  if (!globalResult.allowed) {
    await recordGlobalCircuitTrip(
      admin,
      resolved,
      globalResult.retryAfterSeconds,
    );
  }

  return globalResult;
}

/** Opaque 429. Never names the dimension that tripped (anti-enumeration). */
export function rateLimitedResponse(retryAfterSeconds: number): Response {
  const retry = Math.max(1, Math.ceil(retryAfterSeconds));
  const body = {
    error: "Rate limited",
    code: "rate_limited",
    retry_after: retry,
  };

  return new Response(JSON.stringify(body), {
    status: 429,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json",
      "Retry-After": String(retry),
    },
  });
}
