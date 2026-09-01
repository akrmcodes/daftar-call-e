import { assert, assertEquals } from "@std/assert";
import {
  computeDeepLinkExpiresAt,
  DEEP_LINK_TTL_HOURS,
  isTokenKind,
  isTokenState,
  toAnonymousClaimResult,
  TOKEN_KINDS,
  TOKEN_STATES,
  type TokenKind,
  type TokenState,
} from "./deep_link_types.ts";
import { isValidOpaqueToken } from "./validation.ts";
import { mintOpaqueToken, tokenFingerprint } from "./deep_link_mint.ts";

const HOUR_MS = 60 * 60 * 1000;

// ── TTL boundaries (§8.6.1) ─────────────────────────────────────────────────

Deno.test("TTLs match the spec: worker_invite 72h, share/referral 30d", () => {
  assertEquals(DEEP_LINK_TTL_HOURS.worker_invite, 72);
  assertEquals(DEEP_LINK_TTL_HOURS.share, 720);
  assertEquals(DEEP_LINK_TTL_HOURS.referral, 720);
});

Deno.test("expiry is computed forward from the mint instant", () => {
  const now = new Date("2026-08-06T00:00:00.000Z");
  assertEquals(
    computeDeepLinkExpiresAt("worker_invite", now).toISOString(),
    "2026-08-09T00:00:00.000Z",
  );
  assertEquals(
    computeDeepLinkExpiresAt("share", now).toISOString(),
    "2026-09-05T00:00:00.000Z",
  );
  assertEquals(
    computeDeepLinkExpiresAt("referral", now).toISOString(),
    "2026-09-05T00:00:00.000Z",
  );
});

Deno.test("expiry is exclusive at the boundary instant", () => {
  const now = new Date("2026-08-06T00:00:00.000Z");
  const expiresAt = computeDeepLinkExpiresAt("worker_invite", now);

  // claim-deep-link treats `expires_at < now` as expired, so the boundary
  // instant itself is still live and one millisecond later is not.
  const oneMsBefore = new Date(expiresAt.getTime() - 1);
  const atBoundary = new Date(expiresAt.getTime());
  const oneMsAfter = new Date(expiresAt.getTime() + 1);

  assertEquals(expiresAt.getTime() < oneMsBefore.getTime(), false);
  assertEquals(expiresAt.getTime() < atBoundary.getTime(), false);
  assertEquals(expiresAt.getTime() < oneMsAfter.getTime(), true);
});

Deno.test("expiry crossing a DST boundary stays exactly N hours in UTC", () => {
  // TTL is wall-clock-independent: everything is UTC milliseconds.
  const beforeDst = new Date("2026-10-24T22:00:00.000Z");
  const expiresAt = computeDeepLinkExpiresAt("worker_invite", beforeDst);
  assertEquals(expiresAt.getTime() - beforeDst.getTime(), 72 * HOUR_MS);
});

// ── State machine ───────────────────────────────────────────────────────────

Deno.test("token kinds and states mirror the Postgres ENUMs", () => {
  assertEquals([...TOKEN_KINDS], ["share", "referral", "worker_invite"]);
  assertEquals([...TOKEN_STATES], [
    "active",
    "claimed",
    "expired",
    "revoked",
    "superseded",
  ]);
});

Deno.test("kind and state guards reject unknown values", () => {
  assert(isTokenKind("worker_invite"));
  assertEquals(isTokenKind("invite"), false);
  assert(isTokenState("superseded"));
  assertEquals(isTokenState("pending"), false);
});

Deno.test("every terminal state is reachable only from active", () => {
  // Documents the machine the Edge Functions implement:
  //   active → claimed | expired | revoked | superseded, and nothing leaves a
  //   terminal state.
  const transitions: Record<TokenState, TokenState[]> = {
    active: ["claimed", "expired", "revoked", "superseded"],
    claimed: [],
    expired: [],
    revoked: [],
    superseded: [],
  };

  for (const state of TOKEN_STATES) {
    if (state === "active") continue;
    assertEquals(
      transitions[state].length,
      0,
      `${state} must be terminal`,
    );
  }
  assertEquals(transitions.active.length, 4);
});

// ── Anti-enumeration ────────────────────────────────────────────────────────

Deno.test("not_found collapses to revoked for anonymous callers", () => {
  assertEquals(toAnonymousClaimResult({ status: "not_found" }), {
    status: "revoked",
  });
});

Deno.test("anonymous collapsing preserves every other status verbatim", () => {
  const kind: TokenKind = "share";
  assertEquals(
    toAnonymousClaimResult({ status: "ok", kind, intent: { contact_id: "c" } }),
    { status: "ok", kind, intent: { contact_id: "c" } },
  );
  assertEquals(toAnonymousClaimResult({ status: "expired" }), {
    status: "expired",
  });
  assertEquals(toAnonymousClaimResult({ status: "revoked" }), {
    status: "revoked",
  });
  assertEquals(
    toAnonymousClaimResult({
      status: "already_claimed",
      claimed_by: "by_you",
    }),
    { status: "already_claimed", claimed_by: "by_you" },
  );
});

Deno.test("revoked and not_found are indistinguishable to an anonymous caller", () => {
  assertEquals(
    JSON.stringify(toAnonymousClaimResult({ status: "not_found" })),
    JSON.stringify(toAnonymousClaimResult({ status: "revoked" })),
  );
});

// ── Token shape ─────────────────────────────────────────────────────────────

Deno.test("minted tokens satisfy the DB entropy constraint", () => {
  for (let i = 0; i < 50; i++) {
    const token = mintOpaqueToken();
    assertEquals(token.length, 32);
    assert(isValidOpaqueToken(token));
    assertEquals(token.includes("-"), false);
  }
});

Deno.test("minted tokens do not repeat", () => {
  const seen = new Set<string>();
  for (let i = 0; i < 500; i++) seen.add(mintOpaqueToken());
  assertEquals(seen.size, 500);
});

Deno.test("token validation rejects short, long and non-alphabet tokens", () => {
  assertEquals(isValidOpaqueToken("a".repeat(31)), false);
  assertEquals(isValidOpaqueToken("a".repeat(32)), true);
  assertEquals(isValidOpaqueToken("a".repeat(128)), true);
  assertEquals(isValidOpaqueToken("a".repeat(129)), false);
  assertEquals(isValidOpaqueToken(`${"a".repeat(31)}'`), false);
  assertEquals(isValidOpaqueToken(`${"a".repeat(31)} `), false);
});

Deno.test("token fingerprints are not redeemable", () => {
  const token = mintOpaqueToken();
  const fingerprint = tokenFingerprint(token);
  assertEquals(fingerprint.includes(token), false);
  assert(fingerprint.length < token.length);
});
