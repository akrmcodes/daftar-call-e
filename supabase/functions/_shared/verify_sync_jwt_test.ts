import { assert, assertEquals, assertRejects } from "@std/assert";
import {
  extractBearerToken,
  isWritableRole,
  tryRequireSyncJwt,
  verifySyncJwt,
} from "./verify_sync_jwt.ts";
import { AuthError } from "./http.ts";
import {
  signTestJwt,
  syncJwtPayload,
  TEST_JWT_SECRET,
} from "./test_support.ts";

function bearerRequest(token: string): Request {
  return new Request("https://example.com", {
    headers: { Authorization: `Bearer ${token}` },
  });
}

Deno.test("a well-formed token yields its claims", async () => {
  const token = await signTestJwt(syncJwtPayload(), TEST_JWT_SECRET);
  const claims = await verifySyncJwt(token, TEST_JWT_SECRET);
  assertEquals(claims.workspace_role, "owner");
  assertEquals(claims.workspace_id, "11111111-1111-4111-8111-111111111111");
  assertEquals(claims.identity_hash, "identity-hash-1");
});

Deno.test("a token signed with a different secret is rejected", async () => {
  const token = await signTestJwt(
    syncJwtPayload(),
    "another-secret-with-sufficient-entropy-000",
  );
  await assertRejects(
    () => verifySyncJwt(token, TEST_JWT_SECRET),
    AuthError,
    "Invalid signature",
  );
});

Deno.test("a tampered payload is rejected even with a valid-looking shape", async () => {
  const token = await signTestJwt(syncJwtPayload(), TEST_JWT_SECRET);
  const [header, _payload, signature] = token.split(".");
  const forged = btoa(
    JSON.stringify(
      syncJwtPayload({ workspace_role: "owner", workspace_id: "victim" }),
    ),
  ).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  await assertRejects(
    () => verifySyncJwt(`${header}.${forged}.${signature}`, TEST_JWT_SECRET),
    AuthError,
    "Invalid signature",
  );
});

// ── Algorithm pinning ───────────────────────────────────────────────────────

Deno.test("alg: none is rejected before any claim is read", async () => {
  const payload = syncJwtPayload();
  const encode = (value: unknown) =>
    btoa(JSON.stringify(value)).replace(/\+/g, "-").replace(/\//g, "_")
      .replace(/=+$/, "");
  const token = `${encode({ alg: "none", typ: "JWT" })}.${encode(payload)}.`;

  await assertRejects(
    () => verifySyncJwt(token, TEST_JWT_SECRET),
    AuthError,
    "Unsupported algorithm",
  );
});

Deno.test("a non-HS256 algorithm is rejected", async () => {
  const token = await signTestJwt(syncJwtPayload(), TEST_JWT_SECRET, {
    alg: "HS512",
    typ: "JWT",
  });
  await assertRejects(
    () => verifySyncJwt(token, TEST_JWT_SECRET),
    AuthError,
    "Unsupported algorithm",
  );
});

Deno.test("a non-JWT typ is rejected", async () => {
  const token = await signTestJwt(syncJwtPayload(), TEST_JWT_SECRET, {
    alg: "HS256",
    typ: "JWE",
  });
  await assertRejects(
    () => verifySyncJwt(token, TEST_JWT_SECRET),
    AuthError,
    "Invalid token type",
  );
});

Deno.test("a malformed token is rejected structurally", async () => {
  for (const token of ["", "a", "a.b", "a.b.c.d"]) {
    await assertRejects(
      () => verifySyncJwt(token, TEST_JWT_SECRET),
      AuthError,
    );
  }
});

// ── Temporal claims ─────────────────────────────────────────────────────────

Deno.test("an expired token is rejected beyond the skew window", async () => {
  const now = Math.floor(Date.now() / 1000);
  const token = await signTestJwt(
    syncJwtPayload({ iat: now - 7200, exp: now - 31 }),
    TEST_JWT_SECRET,
  );
  await assertRejects(
    () => verifySyncJwt(token, TEST_JWT_SECRET),
    AuthError,
    "Token expired",
  );
});

Deno.test("a token expiring inside the skew window is still accepted", async () => {
  const now = Math.floor(Date.now() / 1000);
  const token = await signTestJwt(
    syncJwtPayload({ iat: now - 3600, exp: now - 5 }),
    TEST_JWT_SECRET,
  );
  const claims = await verifySyncJwt(token, TEST_JWT_SECRET);
  assertEquals(claims.workspace_role, "owner");
});

Deno.test("a token issued in the future is rejected", async () => {
  const now = Math.floor(Date.now() / 1000);
  const token = await signTestJwt(
    syncJwtPayload({ iat: now + 600, exp: now + 4200 }),
    TEST_JWT_SECRET,
  );
  await assertRejects(
    () => verifySyncJwt(token, TEST_JWT_SECRET),
    AuthError,
    "Token issued in the future",
  );
});

Deno.test("a not-yet-valid nbf is rejected", async () => {
  const now = Math.floor(Date.now() / 1000);
  const token = await signTestJwt(
    syncJwtPayload({ nbf: now + 600 }),
    TEST_JWT_SECRET,
  );
  await assertRejects(
    () => verifySyncJwt(token, TEST_JWT_SECRET),
    AuthError,
    "Token not yet valid",
  );
});

Deno.test("non-numeric temporal claims are rejected", async () => {
  for (const overrides of [{ exp: "soon" }, { iat: null }, { nbf: "x" }]) {
    const token = await signTestJwt(
      syncJwtPayload(overrides),
      TEST_JWT_SECRET,
    );
    await assertRejects(
      () => verifySyncJwt(token, TEST_JWT_SECRET),
      AuthError,
    );
  }
});

// ── Identity claims ─────────────────────────────────────────────────────────

Deno.test("issuer, audience and PostgREST role are all pinned", async () => {
  const cases: Array<[Record<string, unknown>, string]> = [
    [{ iss: "evil" }, "Invalid issuer"],
    [{ aud: "anon" }, "Invalid audience"],
    [{ role: "service_role" }, "Invalid PostgREST role"],
  ];
  for (const [overrides, message] of cases) {
    const token = await signTestJwt(
      syncJwtPayload(overrides),
      TEST_JWT_SECRET,
    );
    await assertRejects(
      () => verifySyncJwt(token, TEST_JWT_SECRET),
      AuthError,
      message,
    );
  }
});

Deno.test("an unknown workspace_role is rejected", async () => {
  const token = await signTestJwt(
    syncJwtPayload({ workspace_role: "superuser" }),
    TEST_JWT_SECRET,
  );
  await assertRejects(
    () => verifySyncJwt(token, TEST_JWT_SECRET),
    AuthError,
    "Invalid workspace role",
  );
});

Deno.test("a missing workspace_id is rejected", async () => {
  const token = await signTestJwt(
    syncJwtPayload({ workspace_id: "" }),
    TEST_JWT_SECRET,
  );
  await assertRejects(
    () => verifySyncJwt(token, TEST_JWT_SECRET),
    AuthError,
    "Missing claims",
  );
});

Deno.test("identity_hash falls back to sub when absent", async () => {
  const token = await signTestJwt(
    syncJwtPayload({ identity_hash: undefined, sub: "fallback-hash" }),
    TEST_JWT_SECRET,
  );
  const claims = await verifySyncJwt(token, TEST_JWT_SECRET);
  assertEquals(claims.identity_hash, "fallback-hash");
});

// ── Bearer extraction and role helper ───────────────────────────────────────

Deno.test("bearer extraction requires the Bearer scheme", () => {
  assertEquals(extractBearerToken(bearerRequest("abc")), "abc");
  assertEquals(
    extractBearerToken(
      new Request("https://e.com", { headers: { Authorization: "Basic abc" } }),
    ),
    null,
  );
  assertEquals(
    extractBearerToken(
      new Request("https://e.com", { headers: { Authorization: "Bearer  " } }),
    ),
    null,
  );
  assertEquals(extractBearerToken(new Request("https://e.com")), null);
});

Deno.test("only owner and editor may write", () => {
  assert(isWritableRole("owner"));
  assert(isWritableRole("editor"));
  assertEquals(isWritableRole("viewer"), false);
  assertEquals(isWritableRole(""), false);
});

// ── Secret strength ─────────────────────────────────────────────────────────

Deno.test("a short signing secret is treated as unconfigured", async () => {
  const previous = Deno.env.get("SUPABASE_JWT_SECRET");
  try {
    Deno.env.set("SUPABASE_JWT_SECRET", "short");
    const token = await signTestJwt(syncJwtPayload(), "short");
    // tryRequireSyncJwt returns null rather than trusting a weak key.
    assertEquals(await tryRequireSyncJwt(bearerRequest(token)), null);
  } finally {
    if (previous === undefined) Deno.env.delete("SUPABASE_JWT_SECRET");
    else Deno.env.set("SUPABASE_JWT_SECRET", previous);
  }
});

Deno.test("tryRequireSyncJwt returns null instead of throwing", async () => {
  const previous = Deno.env.get("SUPABASE_JWT_SECRET");
  try {
    Deno.env.set("SUPABASE_JWT_SECRET", TEST_JWT_SECRET);
    assertEquals(await tryRequireSyncJwt(bearerRequest("garbage")), null);
    assertEquals(await tryRequireSyncJwt(new Request("https://e.com")), null);

    const token = await signTestJwt(syncJwtPayload(), TEST_JWT_SECRET);
    const claims = await tryRequireSyncJwt(bearerRequest(token));
    assertEquals(claims?.workspace_role, "owner");
  } finally {
    if (previous === undefined) Deno.env.delete("SUPABASE_JWT_SECRET");
    else Deno.env.set("SUPABASE_JWT_SECRET", previous);
  }
});
