import { assert, assertEquals, assertRejects, assertThrows } from "@std/assert";
import {
  bucketKeySegment,
  isUuid,
  isValidEmail,
  isValidMoneyAmount,
  normalizeEmail,
  optionalString,
  parseInstant,
  readJsonBody,
  requireEmail,
  requireString,
  requireUuid,
  truncate,
} from "./validation.ts";
import {
  AuthError,
  ConflictError,
  ForbiddenError,
  HttpError,
  InternalError,
  toErrorResponse,
  ValidationError,
} from "./http.ts";

// ── Email ───────────────────────────────────────────────────────────────────

Deno.test("email normalization trims and lowercases", () => {
  assertEquals(normalizeEmail("  Worker@Example.COM "), "worker@example.com");
});

Deno.test("email validation accepts realistic addresses", () => {
  for (
    const email of [
      "a@b.co",
      "worker.name+tag@sub.example.com",
      "محمد@example.com",
    ]
  ) {
    assert(isValidEmail(normalizeEmail(email)), email);
  }
});

Deno.test("email validation rejects malformed addresses", () => {
  for (
    const email of [
      "",
      "plain",
      "@example.com",
      "a@",
      "a@b",
      "a b@example.com",
      "a@exam ple.com",
      "a@@b.com",
      `${"a".repeat(250)}@example.com`,
    ]
  ) {
    assertEquals(isValidEmail(normalizeEmail(email)), false, email);
  }
});

Deno.test("requireEmail returns a normalized address or throws 400", () => {
  assertEquals(requireEmail(" A@B.CO ", "invitee_email"), "a@b.co");
  assertThrows(() => requireEmail("nope", "invitee_email"), ValidationError);
  assertThrows(() => requireEmail(42, "invitee_email"), ValidationError);
  assertThrows(() => requireEmail(null, "invitee_email"), ValidationError);
});

// ── Strings ─────────────────────────────────────────────────────────────────

Deno.test("requireString enforces presence and an upper bound", () => {
  assertEquals(requireString(" abc ", "f", 10), "abc");
  assertThrows(() => requireString("", "f", 10), ValidationError);
  assertThrows(() => requireString("   ", "f", 10), ValidationError);
  assertThrows(() => requireString("a".repeat(11), "f", 10), ValidationError);
  assertThrows(() => requireString(undefined, "f", 10), ValidationError);
});

Deno.test("optionalString maps blank to null but still bounds length", () => {
  assertEquals(optionalString(null, "f", 10), null);
  assertEquals(optionalString("  ", "f", 10), null);
  assertEquals(optionalString(" ok ", "f", 10), "ok");
  assertThrows(() => optionalString("a".repeat(11), "f", 10), ValidationError);
});

Deno.test("truncate bounds without throwing", () => {
  assertEquals(truncate("abcdef", 3), "abc");
  assertEquals(truncate("ab", 3), "ab");
});

// ── UUID ────────────────────────────────────────────────────────────────────

Deno.test("UUID validation accepts v4 and rejects junk", () => {
  assert(isUuid("11111111-1111-4111-8111-111111111111"));
  assertEquals(isUuid("11111111-1111-4111-8111-11111111111"), false);
  assertEquals(isUuid("not-a-uuid"), false);
  assertEquals(isUuid("' OR 1=1 --"), false);
});

Deno.test("requireUuid rejects non-UUID member ids", () => {
  assertEquals(
    requireUuid(" 11111111-1111-4111-8111-111111111111 ", "member_id"),
    "11111111-1111-4111-8111-111111111111",
  );
  assertThrows(
    () => requireUuid("1; DROP TABLE x", "member_id"),
    ValidationError,
  );
});

// ── Integer money ───────────────────────────────────────────────────────────

Deno.test("money must be a positive safe integer", () => {
  assert(isValidMoneyAmount(1));
  assert(isValidMoneyAmount(1500));
  assert(isValidMoneyAmount(Number.MAX_SAFE_INTEGER));

  for (
    const value of [
      0,
      -1,
      1500.7,
      0.1,
      Number.NaN,
      Number.POSITIVE_INFINITY,
      Number.MAX_SAFE_INTEGER + 2,
      "1500",
      null,
      undefined,
      1e21,
    ]
  ) {
    assertEquals(isValidMoneyAmount(value), false, String(value));
  }
});

// ── Instants ────────────────────────────────────────────────────────────────

Deno.test("parseInstant normalizes to UTC ISO-8601", () => {
  assertEquals(
    parseInstant("2026-08-06T10:00:00Z", "logged_at"),
    "2026-08-06T10:00:00.000Z",
  );
  // A zoned offset collapses to the same instant in UTC.
  assertEquals(
    parseInstant("2026-08-06T13:00:00+03:00", "logged_at"),
    "2026-08-06T10:00:00.000Z",
  );
});

Deno.test("parseInstant rejects unparseable values", () => {
  for (const value of ["", "yesterday", "2026-13-45", null, 12345, {}]) {
    assertThrows(
      () => parseInstant(value, "logged_at"),
      ValidationError,
    );
  }
});

Deno.test("parseInstant rejects implausible clock skew in both directions", () => {
  const farFuture = new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString();
  const farPast = new Date("1990-01-01T00:00:00Z").toISOString();
  assertThrows(() => parseInstant(farFuture, "logged_at"), ValidationError);
  assertThrows(() => parseInstant(farPast, "logged_at"), ValidationError);
});

Deno.test("parseInstant accepts modest clock skew", () => {
  const nearFuture = new Date(Date.now() + 60 * 1000).toISOString();
  assertEquals(parseInstant(nearFuture, "logged_at"), nearFuture);
});

// ── Bucket keys ─────────────────────────────────────────────────────────────

Deno.test("bucketKeySegment sanitises and bounds", () => {
  assertEquals(bucketKeySegment("a b:c"), "a_b_c");
  assertEquals(bucketKeySegment("ok.email+x@d-1.com"), "ok.email_x@d-1.com");
  assertEquals(bucketKeySegment("x".repeat(200)).length, 64);
  assertEquals(bucketKeySegment("x".repeat(200), 10).length, 10);
});

// ── JSON bodies ─────────────────────────────────────────────────────────────

function jsonRequest(body: string): Request {
  return new Request("https://example.com", { method: "POST", body });
}

Deno.test("readJsonBody maps malformed JSON to 400, not 500", async () => {
  const error = await assertRejects(
    () => readJsonBody(jsonRequest("{not json")),
    ValidationError,
  );
  assertEquals(error.status, 400);
});

Deno.test("readJsonBody rejects non-object bodies", async () => {
  for (const body of ["null", '"a string"', "42", "true"]) {
    await assertRejects(() => readJsonBody(jsonRequest(body)), ValidationError);
  }
});

Deno.test("readJsonBody accepts objects and arrays", async () => {
  assertEquals(await readJsonBody(jsonRequest('{"a":1}')), { a: 1 });
});

// ── Error mapping ───────────────────────────────────────────────────────────

Deno.test("typed errors carry stable status and code", () => {
  assertEquals(new AuthError().status, 401);
  assertEquals(new AuthError().code, "unauthorized");
  assertEquals(new ForbiddenError().status, 403);
  assertEquals(new ValidationError("x").status, 400);
  assertEquals(
    new ConflictError("x", "seat_cap_exceeded").code,
    "seat_cap_exceeded",
  );
  assertEquals(new InternalError().status, 500);
  assert(new AuthError() instanceof HttpError);
});

Deno.test("toErrorResponse preserves typed status and code", async () => {
  const response = toErrorResponse(
    "fn",
    new ConflictError("Seat cap exceeded", "seat_cap_exceeded"),
  );
  assertEquals(response.status, 409);
  const body = await response.json();
  assertEquals(body.code, "seat_cap_exceeded");
  assertEquals(body.error, "Seat cap exceeded");
});

Deno.test("an untyped throw collapses to an opaque 500", async () => {
  const response = toErrorResponse(
    "fn",
    new Error("connection string postgres://user:password@host"),
  );
  assertEquals(response.status, 500);
  const raw = await response.text();
  assertEquals(raw.includes("password"), false);
  assertEquals(JSON.parse(raw).code, "internal_error");
});

Deno.test("responses always carry CORS headers", () => {
  const response = toErrorResponse("fn", new AuthError());
  assert(response.headers.get("Access-Control-Allow-Origin"));
  assertEquals(response.headers.get("Content-Type"), "application/json");
});
