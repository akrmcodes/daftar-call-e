import { assert, assertEquals } from "@std/assert";
import {
  AUTH_FAILURE_CAPACITY,
  authFailureBucketKey,
  authFailureGate,
  buildInviteRateLimitChecks,
  clientIp,
  emailDomain,
  globalInviteCheck,
  normalizeRateTier,
  RATE_TIERS_BY_STRICTNESS,
  type RateAction,
  rateLimitedResponse,
  recordAuthFailure,
  resolveRateTier,
  schedules,
  STRICTEST_RATE_TIER,
} from "./rate_limit.ts";
import { FakeAdminClient } from "./test_support.ts";

const TIER_ENV = "INVITE_RATE_TIER_DEFAULT";

/** Runs `fn` with INVITE_RATE_TIER_DEFAULT set (or cleared) and restores it. */
function withTierEnv(value: string | null, fn: () => void): void {
  const previous = Deno.env.get(TIER_ENV);
  try {
    if (value === null) Deno.env.delete(TIER_ENV);
    else Deno.env.set(TIER_ENV, value);
    fn();
  } finally {
    if (previous === undefined) Deno.env.delete(TIER_ENV);
    else Deno.env.set(TIER_ENV, previous);
  }
}

Deno.test("clientIp prefers x-forwarded-for first hop", () => {
  const req = new Request("https://example.com", {
    headers: { "x-forwarded-for": "203.0.113.1, 10.0.0.1" },
  });
  assertEquals(clientIp(req), "203.0.113.1");
});

Deno.test("clientIp falls back to cf-connecting-ip", () => {
  const req = new Request("https://example.com", {
    headers: { "cf-connecting-ip": "198.51.100.2" },
  });
  assertEquals(clientIp(req), "198.51.100.2");
});

Deno.test("emailDomain normalizes and extracts domain", () => {
  assertEquals(emailDomain("  Worker@Example.COM "), "example.com");
  assertEquals(emailDomain("invalid"), null);
});

Deno.test("pro_plus worker invite checks include workspace, ip, email, domain", () => {
  const checks = buildInviteRateLimitChecks({
    action: "worker_invite",
    workspaceId: "ws-1",
    clientIp: "1.2.3.4",
    destEmail: "a@mail.test",
    tier: "pro_plus",
  });

  const keys = checks.map((c) => c.key).sort();
  assertEquals(keys, [
    "domain:mail.test",
    "email:a@mail.test",
    "ip:1.2.3.4:invite:h",
    "ws:ws-1:worker:d",
    "ws:ws-1:worker:h",
  ]);
});

Deno.test("pro schedule is tighter than pro_plus for worker invites", () => {
  const pro = buildInviteRateLimitChecks({
    action: "worker_invite",
    workspaceId: "ws-1",
    clientIp: "1.2.3.4",
    destEmail: "a@mail.test",
    tier: "pro",
  });
  const proPlus = buildInviteRateLimitChecks({
    action: "worker_invite",
    workspaceId: "ws-1",
    clientIp: "1.2.3.4",
    destEmail: "a@mail.test",
    tier: "pro_plus",
  });

  const proHour = pro.find((c) => c.key.endsWith(":worker:h"));
  const plusHour = proPlus.find((c) => c.key.endsWith(":worker:h"));
  assertEquals(proHour?.capacity, 2);
  assertEquals(plusHour?.capacity, 3);
  assertEquals(
    (schedules.pro.worker_invite.workspaceHour?.capacity ?? 0) <
      (schedules.pro_plus.worker_invite.workspaceHour?.capacity ?? 0),
    true,
  );
});

Deno.test("renew_invite uses renew and ip buckets only", () => {
  const checks = buildInviteRateLimitChecks({
    action: "renew_invite",
    clientIp: "9.9.9.9",
    renewKey: "abc123",
    tier: "pro_plus",
  });

  assertEquals(checks.map((c) => c.key).sort(), [
    "ip:9.9.9.9:invite:h",
    "renew:abc123:h",
  ]);
});

Deno.test("global invite check is shared across actions", () => {
  const worker = globalInviteCheck({
    action: "worker_invite",
    clientIp: "1.1.1.1",
    tier: "pro_plus",
  });
  const share = globalInviteCheck({
    action: "share",
    clientIp: "1.1.1.1",
    tier: "pro_plus",
  });
  assertEquals(worker.key, "global:invite:h");
  assertEquals(share.key, "global:invite:h");
});

Deno.test("rateLimitedResponse is opaque 429 with Retry-After", async () => {
  const response = rateLimitedResponse(125);
  assertEquals(response.status, 429);
  assertEquals(response.headers.get("Retry-After"), "125");

  const body = await response.json() as Record<string, unknown>;
  assertEquals(body.code, "rate_limited");
  assertEquals(body.retry_after, 125);
  assertEquals("dimension" in body, false);
  assertEquals(JSON.stringify(body).includes("ws:"), false);
  assertEquals(JSON.stringify(body).includes("email:"), false);
});

// ── D2: per-caller tier resolution ──────────────────────────────────────────
// resolveRateTier() previously read only the deploy-wide env var and defaulted
// to pro_plus, so PRO_SCHEDULES was unreachable and every merchant received
// Pro+ limits.

Deno.test("tier normalization accepts the spellings the client uses", () => {
  assertEquals(normalizeRateTier("free"), "free");
  assertEquals(normalizeRateTier("pro"), "pro");
  assertEquals(normalizeRateTier("pro_plus"), "pro_plus");
  assertEquals(normalizeRateTier("proPlus".toLowerCase()), "pro_plus");
  assertEquals(normalizeRateTier("PRO_PLUS"), "pro_plus");
  assertEquals(normalizeRateTier("  Pro+  "), "pro_plus");
});

Deno.test("tier normalization returns null for unknown input", () => {
  for (const value of ["", "enterprise", "premium", null, undefined, 7, {}]) {
    assertEquals(normalizeRateTier(value), null);
  }
});

Deno.test("an explicit tier wins over the env override", () => {
  withTierEnv("pro_plus", () => {
    assertEquals(resolveRateTier("pro"), "pro");
    assertEquals(resolveRateTier("free"), "free");
  });
});

Deno.test("the env override applies only when the caller tier is unknown", () => {
  withTierEnv("pro", () => {
    assertEquals(resolveRateTier(null), "pro");
    assertEquals(resolveRateTier(undefined), "pro");
    assertEquals(resolveRateTier("nonsense"), "pro");
  });
});

Deno.test("an unknown tier with no override fails closed to the strictest", () => {
  withTierEnv(null, () => {
    assertEquals(resolveRateTier(null), STRICTEST_RATE_TIER);
    assertEquals(resolveRateTier(undefined), "free");
    assertEquals(resolveRateTier("enterprise"), "free");
  });
});

Deno.test("an unparseable env override also fails closed", () => {
  withTierEnv("platinum", () => {
    assertEquals(resolveRateTier(null), "free");
  });
});

Deno.test("tiers are ordered strictest first", () => {
  assertEquals([...RATE_TIERS_BY_STRICTNESS], ["free", "pro", "pro_plus"]);
  assertEquals(STRICTEST_RATE_TIER, "free");
});

Deno.test("every action has a schedule for every tier", () => {
  const actions: RateAction[] = [
    "worker_invite",
    "share",
    "referral",
    "renew_invite",
  ];
  for (const tier of RATE_TIERS_BY_STRICTNESS) {
    for (const action of actions) {
      const schedule = schedules[tier][action];
      assert(schedule, `${tier}/${action} must exist`);
      assert(schedule.ipHour.capacity > 0);
      assert(schedule.globalHour.capacity > 0);
    }
  }
});

Deno.test("capacities increase monotonically with tier permissiveness", () => {
  const actions: RateAction[] = ["worker_invite", "share", "referral"];
  for (const action of actions) {
    const free = schedules.free[action];
    const pro = schedules.pro[action];
    const proPlus = schedules.pro_plus[action];

    assert(
      (free.workspaceHour?.capacity ?? 0) <= (pro.workspaceHour?.capacity ?? 0),
      `${action}: free must not exceed pro`,
    );
    assert(
      (pro.workspaceHour?.capacity ?? 0) <=
        (proPlus.workspaceHour?.capacity ?? 0),
      `${action}: pro must not exceed pro_plus`,
    );
    assert(free.ipHour.capacity <= pro.ipHour.capacity);
    assert(pro.ipHour.capacity <= proPlus.ipHour.capacity);
  }
});

Deno.test("a free caller cannot shrink the shared global breaker below pro", () => {
  for (const action of ["worker_invite", "share", "referral", "renew_invite"]) {
    assertEquals(
      schedules.free[action as RateAction].globalHour.capacity,
      schedules.pro[action as RateAction].globalHour.capacity,
    );
  }
});

Deno.test("an unknown tier yields the free schedule, not pro_plus", () => {
  withTierEnv(null, () => {
    const checks = buildInviteRateLimitChecks({
      action: "worker_invite",
      workspaceId: "ws-1",
      clientIp: "1.2.3.4",
    });
    const hourly = checks.find((c) => c.key.endsWith(":worker:h"));
    assertEquals(
      hourly?.capacity,
      schedules.free.worker_invite.workspaceHour?.capacity,
    );
    assertEquals(hourly?.capacity, 1);
  });
});

Deno.test("globalInviteCheck also fails closed on an unknown tier", () => {
  withTierEnv(null, () => {
    const check = globalInviteCheck({
      action: "worker_invite",
      clientIp: "1.1.1.1",
    });
    assertEquals(check.capacity, 100);
  });
});

// ── Bucket-key hygiene ──────────────────────────────────────────────────────
// bucket_key is the primary key of rate_limit_buckets, so caller-controlled
// segments must be bounded and sanitised.

Deno.test("bucket keys bound caller-controlled segments", () => {
  const checks = buildInviteRateLimitChecks({
    action: "worker_invite",
    workspaceId: "w".repeat(500),
    clientIp: "x".repeat(500),
    destEmail: `${"a".repeat(400)}@${"b".repeat(400)}.com`,
    tier: "pro_plus",
  });

  for (const check of checks) {
    assert(
      check.key.length <= 300,
      `key too long (${check.key.length}): ${check.key.slice(0, 40)}`,
    );
  }
});

Deno.test("bucket keys strip characters outside a safe alphabet", () => {
  const checks = buildInviteRateLimitChecks({
    action: "worker_invite",
    workspaceId: "ws:1 with spaces\nand:colons",
    clientIp: "1.2.3.4",
    tier: "pro_plus",
  });

  const workspaceKey = checks.find((c) => c.key.endsWith(":worker:h"));
  assert(workspaceKey);
  // Only the three structural colons survive (ws | id | kind | window), so an
  // injected colon cannot forge an extra key segment.
  assertEquals(workspaceKey.key.split(":").length, 4);
  assertEquals(workspaceKey.key, "ws:ws_1_with_spaces_and_colons:worker:h");
  assertEquals(workspaceKey.key.includes(" "), false);
  assertEquals(workspaceKey.key.includes("\n"), false);
});

// ── Sign-in gate: FAIL OPEN ─────────────────────────────────────────────────
// verify-google-token is the only way to obtain a token. Every branch that
// cannot prove the caller is over budget must admit the request; locking the
// entire user base out of sign-in is strictly worse than the abuse prevented.

const IP = "203.0.113.9";

Deno.test("sign-in gate blocks only on an explicit denial", async () => {
  const fake = new FakeAdminClient().onRpc(() => ({
    data: [{ allowed: false, tokens_remaining: 0, retry_after_seconds: 120 }],
    error: null,
  }));

  const result = await authFailureGate(fake.asAdmin(), IP);
  assertEquals(result.allowed, false);
  assertEquals(result.retryAfterSeconds, 120);
  assertEquals(fake.rpcCalls[0].name, "peek_rate_limit");
});

Deno.test("sign-in gate admits a caller within budget", async () => {
  const fake = new FakeAdminClient().onRpc(() => ({
    data: [{ allowed: true, tokens_remaining: 19, retry_after_seconds: 0 }],
    error: null,
  }));

  assertEquals((await authFailureGate(fake.asAdmin(), IP)).allowed, true);
});

Deno.test("sign-in gate fails open when the limiter RPC errors", async () => {
  const fake = new FakeAdminClient().onRpc(() => ({
    data: null,
    error: { code: "57014", message: "canceling statement due to timeout" },
  }));

  assertEquals((await authFailureGate(fake.asAdmin(), IP)).allowed, true);
});

Deno.test("sign-in gate fails open when the limiter returns nothing", async () => {
  for (const empty of [null, [], undefined, "unexpected"]) {
    const fake = new FakeAdminClient().onRpc(() => ({
      data: empty,
      error: null,
    }));
    assertEquals(
      (await authFailureGate(fake.asAdmin(), IP)).allowed,
      true,
      `empty result ${JSON.stringify(empty)} must not lock sign-in`,
    );
  }
});

Deno.test("sign-in gate fails open when the limiter row is malformed", async () => {
  for (const row of [{}, { allowed: null }, { allowed: "false" }]) {
    const fake = new FakeAdminClient().onRpc(() => ({
      data: [row],
      error: null,
    }));
    assertEquals(
      (await authFailureGate(fake.asAdmin(), IP)).allowed,
      true,
      `malformed row ${JSON.stringify(row)} must not lock sign-in`,
    );
  }
});

Deno.test("sign-in gate fails open when the client throws", async () => {
  const fake = new FakeAdminClient().onRpc(() => {
    throw new Error("connection refused");
  });

  assertEquals((await authFailureGate(fake.asAdmin(), IP)).allowed, true);
});

Deno.test("sign-in gate peeks rather than consuming", async () => {
  // A consume here would let an attacker's own blocked retries keep the bucket
  // pinned at zero, and would charge callers that never failed verification.
  const fake = new FakeAdminClient().onRpc(() => ({
    data: [{ allowed: true, tokens_remaining: 20, retry_after_seconds: 0 }],
    error: null,
  }));

  await authFailureGate(fake.asAdmin(), IP);
  assertEquals(fake.rpcCalls.length, 1);
  assertEquals(fake.rpcCalls[0].name, "peek_rate_limit");
  assertEquals(fake.rpcCalls[0].args?.p_capacity, AUTH_FAILURE_CAPACITY);
});

Deno.test("recording a failure charges exactly one token", async () => {
  const fake = new FakeAdminClient().onRpc(() => ({
    data: [{ allowed: true, retry_after_seconds: 0 }],
    error: null,
  }));

  await recordAuthFailure(fake.asAdmin(), IP);
  assertEquals(fake.rpcCalls.length, 1);
  assertEquals(fake.rpcCalls[0].name, "consume_rate_limit");
  assertEquals(fake.rpcCalls[0].args?.p_cost, 1);
  assertEquals(fake.rpcCalls[0].args?.p_bucket_key, authFailureBucketKey(IP));
});

Deno.test("recording a failure never throws into the request path", async () => {
  const erroring = new FakeAdminClient().onRpc(() => ({
    data: null,
    error: { code: "42501", message: "permission denied" },
  }));
  await recordAuthFailure(erroring.asAdmin(), IP);

  const throwing = new FakeAdminClient().onRpc(() => {
    throw new Error("socket hang up");
  });
  await recordAuthFailure(throwing.asAdmin(), IP);
});

Deno.test("sign-in bucket keys bound a spoofed forwarded-for header", () => {
  const key = authFailureBucketKey(`${"9".repeat(500)} :injected`);
  assert(key.startsWith("authfail:"));
  assertEquals(key.endsWith(":h"), true);
  // Only the two structural colons survive.
  assertEquals(key.split(":").length, 3);
  assert(key.length < 80);
});
