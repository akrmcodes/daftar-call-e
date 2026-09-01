import { assert, assertEquals, assertRejects, assertThrows } from "@std/assert";
import {
  applyEntityOp,
  currentUsageMonth,
  isSyncableEntityType,
  isSyncOpAction,
  normalizePushAction,
  parseFieldDeltas,
  SYNC_OP_ACTIONS,
  validateEntityDeltas,
} from "./sync_ops.ts";
import { InternalError, ValidationError } from "./http.ts";
import { FakeAdminClient, type QueryOutcome } from "./test_support.ts";

const WORKSPACE = "11111111-1111-4111-8111-111111111111";
const SERVER_TIME = "2026-08-06T10:00:00.000Z";

// ── Action vocabulary ───────────────────────────────────────────────────────
// Regression guard for the constraint mismatch that deadlocked push-sync-ops:
// audit_logs.action accepted only CREATE/UPDATE/DELETE while the client emits
// five more verbs.

Deno.test("action allow-list covers every verb the client emits", () => {
  for (
    const action of [
      "CREATE",
      "UPDATE",
      "DELETE",
      "RESTORE",
      "ACTIVATE_ARCHIVED",
      "USER_ARCHIVE",
      "USER_UNARCHIVE",
      "CARRY_FORWARD",
    ]
  ) {
    assert(isSyncOpAction(action), `${action} must be accepted`);
  }
  assertEquals(SYNC_OP_ACTIONS.length, 8);
});

Deno.test("action allow-list rejects unknown verbs", () => {
  assertEquals(isSyncOpAction("DROP"), false);
  assertEquals(isSyncOpAction("create"), false);
  assertEquals(isSyncOpAction(""), false);
});

Deno.test("only ledger, contact and transaction are syncable", () => {
  assertEquals(isSyncableEntityType("ledger"), true);
  assertEquals(isSyncableEntityType("contact"), true);
  assertEquals(isSyncableEntityType("transaction"), true);
  assertEquals(isSyncableEntityType("workspace_member"), false);
  assertEquals(isSyncableEntityType("settings"), false);
});

// ── Projection normalization ────────────────────────────────────────────────

Deno.test("archive verbs project onto UPDATE with the flag delta", () => {
  assertEquals(normalizePushAction("USER_ARCHIVE", null), {
    action: "UPDATE",
    deltas: { isUserArchived: true },
  });
  assertEquals(normalizePushAction("USER_UNARCHIVE", { id: "l1" }), {
    action: "UPDATE",
    deltas: { id: "l1", isUserArchived: false },
  });
  assertEquals(normalizePushAction("RESTORE", null), {
    action: "UPDATE",
    deltas: { isDeleted: false },
  });
  assertEquals(normalizePushAction("ACTIVATE_ARCHIVED", null), {
    action: "UPDATE",
    deltas: { isArchived: false },
  });
});

Deno.test("normalizePushAction leaves CRUD and CARRY_FORWARD untouched", () => {
  assertEquals(normalizePushAction("CREATE", { a: 1 }), {
    action: "CREATE",
    deltas: { a: 1 },
  });
  assertEquals(normalizePushAction("CARRY_FORWARD", null), {
    action: "CARRY_FORWARD",
    deltas: null,
  });
});

Deno.test("parseFieldDeltas accepts objects, JSON strings and null", () => {
  assertEquals(parseFieldDeltas({ a: 1 }), { a: 1 });
  assertEquals(parseFieldDeltas('{"a":1}'), { a: 1 });
  assertEquals(parseFieldDeltas(null), null);
  assertEquals(parseFieldDeltas(undefined), null);
  assertEquals(parseFieldDeltas("not json"), null);
  assertEquals(parseFieldDeltas("[1,2]"), [1, 2] as unknown);
});

Deno.test("usage month is UTC, not local time", () => {
  // 00:30 UTC on the 1st is still the previous month in UTC-3.
  assertEquals(
    currentUsageMonth(new Date("2026-09-01T00:30:00.000Z")),
    "2026-09",
  );
  assertEquals(
    currentUsageMonth(new Date("2026-12-31T23:59:59.000Z")),
    "2026-12",
  );
  assertEquals(
    currentUsageMonth(new Date("2027-01-01T00:00:00.000Z")),
    "2027-01",
  );
});

// ── Integer money ───────────────────────────────────────────────────────────

function moneyClient(): FakeAdminClient {
  return new FakeAdminClient(() => ({ data: [{ id: "t1" }], error: null }));
}

Deno.test("transaction CREATE rejects fractional amounts", async () => {
  const fake = moneyClient();
  await assertRejects(
    () =>
      applyEntityOp(
        fake.asAdmin(),
        WORKSPACE,
        "transaction",
        "t1",
        "CREATE",
        { contactId: "c1", amount: 1500.7 },
        SERVER_TIME,
        10,
      ),
    ValidationError,
    "Invalid amount",
  );
  assertEquals(
    fake.calls.length,
    0,
    "must reject before touching the database",
  );
});

Deno.test("transaction CREATE rejects zero, negative and non-numeric amounts", async () => {
  for (const amount of [0, -1, "1500", null, undefined, Number.NaN, 1e21]) {
    const fake = moneyClient();
    await assertRejects(
      () =>
        applyEntityOp(
          fake.asAdmin(),
          WORKSPACE,
          "transaction",
          "t1",
          "CREATE",
          { contactId: "c1", amount },
          SERVER_TIME,
          10,
        ),
      ValidationError,
    );
  }
});

Deno.test("transaction CREATE accepts integer minor units", async () => {
  const fake = moneyClient();
  const outcome = await applyEntityOp(
    fake.asAdmin(),
    WORKSPACE,
    "transaction",
    "t1",
    "CREATE",
    { contactId: "c1", amount: 1500, currency: "YER" },
    SERVER_TIME,
    10,
  );

  assertEquals(outcome, "applied");
  const upsert = fake.callsFor("transactions", "upsert")[0];
  const payload = upsert.payload as Record<string, unknown>;
  assertEquals(payload.amount, 1500);
  assertEquals(payload.op_seq, 10);
  assertEquals(payload.workspace_id, WORKSPACE);
});

Deno.test("contact UPDATE rejects a fractional credit limit", async () => {
  const fake = moneyClient();
  await assertRejects(
    () =>
      applyEntityOp(
        fake.asAdmin(),
        WORKSPACE,
        "contact",
        "c1",
        "UPDATE",
        { creditLimit: 99.99 },
        SERVER_TIME,
        11,
      ),
    ValidationError,
  );
});

// ── Timestamp validation ────────────────────────────────────────────────────

Deno.test("transaction CREATE rejects an unparseable transactionDate", async () => {
  const fake = moneyClient();
  await assertRejects(
    () =>
      applyEntityOp(
        fake.asAdmin(),
        WORKSPACE,
        "transaction",
        "t1",
        "CREATE",
        { contactId: "c1", amount: 100, transactionDate: "yesterday" },
        SERVER_TIME,
        12,
      ),
    ValidationError,
    "Invalid transactionDate",
  );
});

// ── Database errors must propagate ──────────────────────────────────────────
// Previously every write ignored `{ error }`: the audit row was still written
// and the client was told "applied" while the server's mirror silently lost
// the change.

Deno.test("a failed projection write raises instead of being swallowed", async () => {
  const fake = new FakeAdminClient(() => ({
    data: null,
    error: { code: "23503", message: "insert violates foreign key" },
  }));

  await assertRejects(
    () =>
      applyEntityOp(
        fake.asAdmin(),
        WORKSPACE,
        "contact",
        "c1",
        "CREATE",
        { ledgerId: "l1", name: "Ali" },
        SERVER_TIME,
        13,
      ),
    InternalError,
  );
});

Deno.test("projection errors never leak driver text to the caller", async () => {
  const fake = new FakeAdminClient(() => ({
    data: null,
    error: { code: "23503", message: 'relation "contacts" secret detail' },
  }));

  const error = await assertRejects(
    () =>
      applyEntityOp(
        fake.asAdmin(),
        WORKSPACE,
        "contact",
        "c1",
        "CREATE",
        { ledgerId: "l1", name: "Ali" },
        SERVER_TIME,
        14,
      ),
    InternalError,
  );
  assertEquals(error.message.includes("secret detail"), false);
});

// ── Monotonic op_seq guard ──────────────────────────────────────────────────
// Concurrent pushes are numbered by the server but complete out of order, so a
// lower-numbered op arriving late must not overwrite newer state.

Deno.test("UPDATE carries an op_seq guard so a stale op cannot overwrite", async () => {
  const fake = new FakeAdminClient((call) =>
    call.verb === "update"
      ? { data: [{ id: "l1" }], error: null } satisfies QueryOutcome
      : { data: null, error: null }
  );

  const outcome = await applyEntityOp(
    fake.asAdmin(),
    WORKSPACE,
    "ledger",
    "l1",
    "UPDATE",
    { name: "Renamed" },
    SERVER_TIME,
    42,
  );

  assertEquals(outcome, "applied");
  const update = fake.callsFor("ledgers", "update")[0];
  assertEquals(update.orFilter, "op_seq.is.null,op_seq.lt.42");
  assertEquals(update.filters, [["id", "l1"], ["workspace_id", WORKSPACE]]);
});

Deno.test("an op losing the guard reports skipped_stale, not applied", async () => {
  // Update matches nothing, but the row exists — a newer op already won.
  const fake = new FakeAdminClient((call) =>
    call.verb === "update"
      ? { data: [], error: null }
      : { data: { id: "l1" }, error: null }
  );

  const outcome = await applyEntityOp(
    fake.asAdmin(),
    WORKSPACE,
    "ledger",
    "l1",
    "UPDATE",
    { name: "Stale" },
    SERVER_TIME,
    7,
  );

  assertEquals(outcome, "skipped_stale");
});

Deno.test("an update against a missing row reports skipped_missing", async () => {
  // `maybeSingle()` yields null when nothing matches.
  const fake = new FakeAdminClient((call) =>
    call.verb === "update" ? { data: [], error: null } : {
      data: null,
      error: null,
    }
  );

  const outcome = await applyEntityOp(
    fake.asAdmin(),
    WORKSPACE,
    "ledger",
    "ghost",
    "UPDATE",
    { name: "Nope" },
    SERVER_TIME,
    7,
  );

  assertEquals(outcome, "skipped_missing");
});

Deno.test("DELETE is a soft delete carrying the same guard", async () => {
  const fake = new FakeAdminClient(() => ({
    data: [{ id: "t1" }],
    error: null,
  }));

  const outcome = await applyEntityOp(
    fake.asAdmin(),
    WORKSPACE,
    "transaction",
    "t1",
    "DELETE",
    null,
    SERVER_TIME,
    99,
  );

  assertEquals(outcome, "applied");
  const update = fake.callsFor("transactions", "update")[0];
  const patch = update.payload as Record<string, unknown>;
  assertEquals(patch.is_deleted, true);
  assertEquals(patch.deleted_at, SERVER_TIME);
  assertEquals(update.orFilter, "op_seq.is.null,op_seq.lt.99");
  assertEquals(
    fake.calls.some((c) => c.verb === "delete"),
    false,
    "must never issue a hard delete",
  );
});

Deno.test("re-applying the same op is idempotent at the projection layer", async () => {
  const fake = new FakeAdminClient(() => ({
    data: [{ id: "l1" }],
    error: null,
  }));

  const args = [
    fake.asAdmin(),
    WORKSPACE,
    "ledger",
    "l1",
    "CREATE",
    { name: "Shop", type: "customers" },
    SERVER_TIME,
    5,
  ] as const;

  await applyEntityOp(...args);
  await applyEntityOp(...args);

  const upserts = fake.callsFor("ledgers", "upsert");
  assertEquals(upserts.length, 2);
  // Both writes carry identical state, so replay converges rather than drifting.
  assertEquals(
    JSON.stringify(upserts[0].payload),
    JSON.stringify(upserts[1].payload),
  );
});

Deno.test("non-syncable entity types are skipped, not written", async () => {
  const fake = new FakeAdminClient(() => ({ data: [], error: null }));
  const outcome = await applyEntityOp(
    fake.asAdmin(),
    WORKSPACE,
    "workspace_member",
    "m1",
    "CREATE",
    { name: "x" },
    SERVER_TIME,
    1,
  );
  assertEquals(outcome, "skipped_missing");
  assertEquals(fake.calls.length, 0);
});

// ── Pre-flight delta validation ─────────────────────────────────────────────
// push-sync-ops now appends the op-log row before projecting, so anything the
// projection would reject has to be caught beforehand. If these two ever
// disagree the op-log gains a row that can never be projected.

Deno.test("pre-flight accepts the deltas the projection accepts", () => {
  validateEntityDeltas("transaction", "CREATE", {
    contactId: "c1",
    amount: 1500,
    transactionDate: SERVER_TIME,
  });
  validateEntityDeltas("contact", "CREATE", {
    ledgerId: "l1",
    creditLimit: 250,
  });
  validateEntityDeltas("contact", "CREATE", { ledgerId: "l1" });
  validateEntityDeltas("ledger", "CREATE", { name: "Shop" });
  validateEntityDeltas("transaction", "UPDATE", { amount: 20 });
  validateEntityDeltas("transaction", "UPDATE", { description: "note" });
});

Deno.test("pre-flight rejects fractional money before the op-log write", () => {
  assertThrows(
    () =>
      validateEntityDeltas("transaction", "CREATE", {
        contactId: "c1",
        amount: 15.5,
      }),
    ValidationError,
  );
  assertThrows(
    () => validateEntityDeltas("transaction", "UPDATE", { amount: 0.1 }),
    ValidationError,
  );
  assertThrows(
    () => validateEntityDeltas("contact", "UPDATE", { creditLimit: 9.99 }),
    ValidationError,
  );
});

Deno.test("pre-flight rejects missing parent references", () => {
  assertThrows(
    () => validateEntityDeltas("transaction", "CREATE", { amount: 10 }),
    ValidationError,
  );
  assertThrows(
    () => validateEntityDeltas("contact", "CREATE", { name: "x" }),
    ValidationError,
  );
});

Deno.test("pre-flight rejects an unparseable transaction date", () => {
  assertThrows(
    () =>
      validateEntityDeltas("transaction", "UPDATE", {
        transactionDate: "not-a-date",
      }),
    ValidationError,
  );
});

Deno.test("pre-flight ignores entity types the projection never writes", () => {
  validateEntityDeltas("workspace_member", "CREATE", { amount: 1.5 });
  validateEntityDeltas("transaction", "CREATE", null);
});

Deno.test("pre-flight agrees with the projection on every archive verb", () => {
  // normalizePushAction rewrites these to UPDATE, and the pre-flight must see
  // the rewritten pair — not the raw verb — or it validates the wrong shape.
  for (
    const verb of [
      "USER_ARCHIVE",
      "USER_UNARCHIVE",
      "RESTORE",
      "ACTIVATE_ARCHIVED",
    ]
  ) {
    const projected = normalizePushAction(verb, { amount: 12.5 });
    assertEquals(projected.action, "UPDATE");
    assertThrows(
      () =>
        validateEntityDeltas("transaction", projected.action, projected.deltas),
      ValidationError,
      undefined,
      `${verb} bypassed money validation`,
    );
  }
});
