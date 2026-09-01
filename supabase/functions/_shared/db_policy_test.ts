// ============================================================================
// D3 — Postgres-level policy tests
// ============================================================================
// The "defense in depth" claim (application layer AND RLS) was previously
// proven on one layer only: nothing in the repository exercised a policy.
//
// These tests connect as the non-privileged `authenticated` role with a crafted
// `request.jwt.claims` GUC — exactly how PostgREST presents a sync JWT — and
// assert the invariants the Edge Functions rely on. They also cover the
// Stage 8.8 privilege lockdown and the atomic seat/usage RPCs.
//
// Every test runs inside a transaction that is rolled back, so the suite leaves
// no rows behind and is safe to re-run.
//
// REQUIRES A RUNNING LOCAL STACK (`supabase start` / `supabase db start`).
// When the database is unreachable the whole file is skipped rather than
// failing, so CI without Docker stays green — see the console notice.
// ============================================================================

import { assert, assertEquals } from "@std/assert";
import { Client } from "@db/postgres";

const DB_URL = Deno.env.get("SUPABASE_DB_URL") ??
  "postgresql://postgres:postgres@127.0.0.1:54322/postgres";

/** Postgres SQLSTATE for "new row violates row-level security policy". */
const INSUFFICIENT_PRIVILEGE = "42501";

const WORKSPACE_A = "aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa";
const WORKSPACE_B = "bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb";
const OWNER_A = "identity-owner-a";
const EDITOR_A = "identity-editor-a";
const VIEWER_A = "identity-viewer-a";
const OWNER_B = "identity-owner-b";

async function probeDatabase(): Promise<boolean> {
  const client = new Client(DB_URL);
  try {
    await client.connect();
    await client.queryArray("select 1");
    return true;
  } catch {
    return false;
  } finally {
    try {
      await client.end();
    } catch {
      // Already closed.
    }
  }
}

const dbAvailable = await probeDatabase();
if (!dbAvailable) {
  console.warn(
    `[db_policy_test] SKIPPED — no Postgres at ${DB_URL}. ` +
      "Start the local stack with `supabase db start` to run these tests.",
  );
}

/** Runs `fn` inside a rolled-back transaction against a fresh connection. */
async function withRollback(
  fn: (client: Client) => Promise<void>,
): Promise<void> {
  const client = new Client(DB_URL);
  await client.connect();
  try {
    await client.queryArray("BEGIN");
    await fn(client);
  } finally {
    try {
      await client.queryArray("ROLLBACK");
    } finally {
      await client.end();
    }
  }
}

function dbTest(name: string, fn: (client: Client) => Promise<void>): void {
  Deno.test({
    name,
    ignore: !dbAvailable,
    fn: () => withRollback(fn),
  });
}

/** Seeds two isolated workspaces with a full member/ledger/contact graph. */
async function seedTenants(client: Client): Promise<void> {
  await client.queryArray(`
    INSERT INTO public.workspaces (id, owner_identity, status, tier)
    VALUES
      ('${WORKSPACE_A}', '${OWNER_A}', 'active', 'pro_plus'),
      ('${WORKSPACE_B}', '${OWNER_B}', 'active', 'pro');

    INSERT INTO public.workspace_members
      (workspace_id, invited_email, identity_hash, role, status, seat_index)
    VALUES
      ('${WORKSPACE_A}', 'owner-a@test.dev',  '${OWNER_A}',  'owner',  'active', 0),
      ('${WORKSPACE_A}', 'editor-a@test.dev', '${EDITOR_A}', 'editor', 'active', 1),
      ('${WORKSPACE_A}', 'viewer-a@test.dev', '${VIEWER_A}', 'viewer', 'active', 2),
      ('${WORKSPACE_B}', 'owner-b@test.dev',  '${OWNER_B}',  'owner',  'active', 0);

    INSERT INTO public.ledgers
      (id, workspace_id, name, type, icon, color, sort_order, is_user_archived)
    VALUES
      ('ledger-a-live',     '${WORKSPACE_A}', 'A Live',     'customers', 'store', '#111111', 0, false),
      ('ledger-a-archived', '${WORKSPACE_A}', 'A Archived', 'customers', 'store', '#111111', 1, true),
      ('ledger-b-live',     '${WORKSPACE_B}', 'B Live',     'customers', 'store', '#222222', 0, false);

    INSERT INTO public.contacts
      (id, workspace_id, ledger_id, name, avatar_color)
    VALUES
      ('contact-a-live',     '${WORKSPACE_A}', 'ledger-a-live',     'A Live',     '#111111'),
      ('contact-a-archived', '${WORKSPACE_A}', 'ledger-a-archived', 'A Archived', '#111111'),
      ('contact-b-live',     '${WORKSPACE_B}', 'ledger-b-live',     'B Live',     '#222222');
  `);
}

/** Switches the session to `authenticated` carrying the given sync JWT claims. */
async function actAs(
  client: Client,
  workspaceId: string,
  workspaceRole: string,
  identityHash: string,
): Promise<void> {
  await client.queryArray("SET LOCAL ROLE authenticated");
  await client.queryArray(
    "SELECT set_config('request.jwt.claims', $1, true)",
    [
      JSON.stringify({
        role: "authenticated",
        workspace_id: workspaceId,
        workspace_role: workspaceRole,
        identity_hash: identityHash,
      }),
    ],
  );
}

async function actAsPostgres(client: Client): Promise<void> {
  await client.queryArray("RESET ROLE");
  await client.queryArray("SELECT set_config('request.jwt.claims', '', true)");
}

/**
 * Runs a statement and returns its SQLSTATE, or null when it succeeded.
 * Wrapped in a savepoint so an expected failure does not abort the enclosing
 * transaction and turn every later probe into 25P02.
 */
async function sqlStateOf(
  client: Client,
  sql: string,
): Promise<string | null> {
  await client.queryArray("SAVEPOINT probe");
  try {
    await client.queryArray(sql);
    await client.queryArray("RELEASE SAVEPOINT probe");
    return null;
  } catch (error) {
    await client.queryArray("ROLLBACK TO SAVEPOINT probe");
    const code = (error as { fields?: { code?: string } }).fields?.code;
    return code ?? "unknown";
  }
}

async function countRows(client: Client, sql: string): Promise<number> {
  const result = await client.queryArray<[bigint]>(sql);
  return Number(result.rows[0][0]);
}

// ── A viewer cannot write ───────────────────────────────────────────────────

dbTest("a viewer cannot insert a contact", async (client) => {
  await seedTenants(client);
  await actAs(client, WORKSPACE_A, "viewer", VIEWER_A);

  const state = await sqlStateOf(
    client,
    `INSERT INTO public.contacts (id, workspace_id, ledger_id, name, avatar_color)
     VALUES ('viewer-insert', '${WORKSPACE_A}', 'ledger-a-live', 'Nope', '#000000')`,
  );
  assertEquals(state, INSUFFICIENT_PRIVILEGE);
});

dbTest("a viewer cannot insert a transaction", async (client) => {
  await seedTenants(client);
  await actAs(client, WORKSPACE_A, "viewer", VIEWER_A);

  const state = await sqlStateOf(
    client,
    `INSERT INTO public.transactions
       (id, workspace_id, contact_id, type, amount, currency, transaction_date)
     VALUES ('viewer-txn', '${WORKSPACE_A}', 'contact-a-live', 'debt', 1500, 'YER', now())`,
  );
  assertEquals(state, INSUFFICIENT_PRIVILEGE);
});

dbTest("a viewer's update matches no rows", async (client) => {
  await seedTenants(client);
  await actAs(client, WORKSPACE_A, "viewer", VIEWER_A);

  // A non-matching USING clause filters the row out rather than raising.
  const result = await client.queryArray(
    `UPDATE public.contacts SET name = 'Hacked' WHERE id = 'contact-a-live'`,
  );
  assertEquals(result.rowCount ?? 0, 0);

  await actAsPostgres(client);
  const unchanged = await countRows(
    client,
    `SELECT count(*) FROM public.contacts
      WHERE id = 'contact-a-live' AND name = 'A Live'`,
  );
  assertEquals(unchanged, 1);
});

dbTest("a viewer cannot delete", async (client) => {
  await seedTenants(client);
  await actAs(client, WORKSPACE_A, "viewer", VIEWER_A);

  // Either outcome is acceptable — `authenticated` holds no DELETE grant on
  // contacts, so this is refused at the privilege layer before RLS is reached.
  // What matters is that the row survives.
  await sqlStateOf(
    client,
    `DELETE FROM public.contacts WHERE id = 'contact-a-live'`,
  );

  await actAsPostgres(client);
  assertEquals(
    await countRows(
      client,
      `SELECT count(*) FROM public.contacts WHERE id = 'contact-a-live'`,
    ),
    1,
  );
});

dbTest("a viewer can still read their own workspace", async (client) => {
  await seedTenants(client);
  await actAs(client, WORKSPACE_A, "viewer", VIEWER_A);

  const visible = await countRows(
    client,
    "SELECT count(*) FROM public.contacts",
  );
  assertEquals(visible, 2, "both A contacts, and only A's");
});

// ── Cross-tenant isolation ──────────────────────────────────────────────────

dbTest("workspace A cannot read workspace B rows", async (client) => {
  await seedTenants(client);
  await actAs(client, WORKSPACE_A, "owner", OWNER_A);

  assertEquals(
    await countRows(
      client,
      `SELECT count(*) FROM public.ledgers WHERE workspace_id = '${WORKSPACE_B}'`,
    ),
    0,
  );
  assertEquals(
    await countRows(
      client,
      `SELECT count(*) FROM public.contacts WHERE id = 'contact-b-live'`,
    ),
    0,
  );
  assertEquals(
    await countRows(
      client,
      `SELECT count(*) FROM public.workspaces WHERE id = '${WORKSPACE_B}'`,
    ),
    0,
  );
  assertEquals(
    await countRows(
      client,
      `SELECT count(*) FROM public.workspace_members
        WHERE workspace_id = '${WORKSPACE_B}'`,
    ),
    0,
  );
});

dbTest("workspace A cannot update workspace B rows", async (client) => {
  await seedTenants(client);
  await actAs(client, WORKSPACE_A, "owner", OWNER_A);

  const updated = await client.queryArray(
    `UPDATE public.contacts SET name = 'Stolen' WHERE id = 'contact-b-live'`,
  );
  assertEquals(updated.rowCount ?? 0, 0);

  await actAsPostgres(client);
  assertEquals(
    await countRows(
      client,
      `SELECT count(*) FROM public.contacts
        WHERE id = 'contact-b-live' AND name = 'B Live'`,
    ),
    1,
  );
});

dbTest("workspace A cannot insert into workspace B", async (client) => {
  await seedTenants(client);
  await actAs(client, WORKSPACE_A, "owner", OWNER_A);

  const state = await sqlStateOf(
    client,
    `INSERT INTO public.ledgers
       (id, workspace_id, name, type, icon, color, sort_order)
     VALUES ('cross-tenant', '${WORKSPACE_B}', 'X', 'customers', 'store', '#000000', 9)`,
  );
  assertEquals(state, INSUFFICIENT_PRIVILEGE);
});

dbTest(
  "a forged JWT without an active membership sees nothing",
  async (client) => {
    await seedTenants(client);
    // Correct workspace_id and an owner claim, but no membership row backs it.
    await actAs(client, WORKSPACE_A, "owner", "identity-does-not-exist");

    assertEquals(
      await countRows(client, "SELECT count(*) FROM public.contacts"),
      0,
      "jwt_is_member() must resolve against the database, not the claim",
    );

    const state = await sqlStateOf(
      client,
      `INSERT INTO public.contacts (id, workspace_id, ledger_id, name, avatar_color)
     VALUES ('forged', '${WORKSPACE_A}', 'ledger-a-live', 'X', '#000000')`,
    );
    assertEquals(state, INSUFFICIENT_PRIVILEGE);
  },
);

dbTest("an absent JWT fails closed", async (client) => {
  await seedTenants(client);
  await client.queryArray("SET LOCAL ROLE authenticated");

  assertEquals(
    await countRows(client, "SELECT count(*) FROM public.contacts"),
    0,
  );
});

// ── Archived-ledger write lock ──────────────────────────────────────────────

dbTest(
  "an editor cannot insert under a user-archived ledger",
  async (client) => {
    await seedTenants(client);
    await actAs(client, WORKSPACE_A, "editor", EDITOR_A);

    const state = await sqlStateOf(
      client,
      `INSERT INTO public.contacts (id, workspace_id, ledger_id, name, avatar_color)
     VALUES ('archived-insert', '${WORKSPACE_A}', 'ledger-a-archived', 'X', '#000000')`,
    );
    assertEquals(state, INSUFFICIENT_PRIVILEGE);
  },
);

dbTest(
  "an editor cannot update a contact under a user-archived ledger",
  async (client) => {
    await seedTenants(client);
    await actAs(client, WORKSPACE_A, "editor", EDITOR_A);

    const result = await client.queryArray(
      `UPDATE public.contacts SET name = 'Changed'
      WHERE id = 'contact-a-archived'`,
    );
    assertEquals(result.rowCount ?? 0, 0);
  },
);

dbTest(
  "an OWNER is also blocked under a user-archived ledger",
  async (client) => {
    await seedTenants(client);
    await actAs(client, WORKSPACE_A, "owner", OWNER_A);

    const state = await sqlStateOf(
      client,
      `INSERT INTO public.contacts (id, workspace_id, ledger_id, name, avatar_color)
     VALUES ('archived-owner', '${WORKSPACE_A}', 'ledger-a-archived', 'X', '#000000')`,
    );
    assertEquals(
      state,
      INSUFFICIENT_PRIVILEGE,
      "the archival lock has no owner bypass",
    );
  },
);

dbTest(
  "transactions under a user-archived ledger are locked too",
  async (client) => {
    await seedTenants(client);
    await actAs(client, WORKSPACE_A, "editor", EDITOR_A);

    const state = await sqlStateOf(
      client,
      `INSERT INTO public.transactions
       (id, workspace_id, contact_id, type, amount, currency, transaction_date)
     VALUES ('archived-txn', '${WORKSPACE_A}', 'contact-a-archived', 'debt', 500, 'YER', now())`,
    );
    assertEquals(state, INSUFFICIENT_PRIVILEGE);
  },
);

dbTest("an editor CAN write under a live ledger", async (client) => {
  await seedTenants(client);
  await actAs(client, WORKSPACE_A, "editor", EDITOR_A);

  const state = await sqlStateOf(
    client,
    `INSERT INTO public.transactions
       (id, workspace_id, contact_id, type, amount, currency, transaction_date)
     VALUES ('live-txn', '${WORKSPACE_A}', 'contact-a-live', 'debt', 1500, 'YER', now())`,
  );
  assertEquals(state, null, "the lock must not over-block the happy path");
});

dbTest("a non-owner cannot toggle is_user_archived", async (client) => {
  await seedTenants(client);
  await actAs(client, WORKSPACE_A, "editor", EDITOR_A);

  const state = await sqlStateOf(
    client,
    `UPDATE public.ledgers SET is_user_archived = true WHERE id = 'ledger-a-live'`,
  );
  assert(state !== null, "the archive-toggle trigger must reject an editor");
});

// ── Stage 8.8 privilege lockdown ────────────────────────────────────────────

dbTest("client roles cannot TRUNCATE business tables", async (client) => {
  await client.queryArray("SET LOCAL ROLE authenticated");

  // TRUNCATE is not filtered by RLS, so the grant itself had to go.
  for (
    const table of [
      "transactions",
      "contacts",
      "ledgers",
      "audit_logs",
      "workspace_members",
      "workspaces",
      "contact_balances",
    ]
  ) {
    assertEquals(
      await sqlStateOf(client, `TRUNCATE public.${table} CASCADE`),
      INSUFFICIENT_PRIVILEGE,
      `authenticated must not TRUNCATE ${table}`,
    );
  }
});

dbTest(
  "anon cannot TRUNCATE the device registry or audit partitions",
  async (client) => {
    await client.queryArray("SET LOCAL ROLE anon");

    for (
      const table of [
        "workspace_devices",
        "sync_usage_counters",
        "audit_logs_default",
      ]
    ) {
      assertEquals(
        await sqlStateOf(client, `TRUNCATE public.${table}`),
        INSUFFICIENT_PRIVILEGE,
        `anon must not TRUNCATE ${table}`,
      );
    }
  },
);

dbTest(
  "client roles cannot advance or reset the global op sequence",
  async (client) => {
    for (const role of ["authenticated", "anon"]) {
      await client.queryArray(`SET LOCAL ROLE ${role}`);
      assertEquals(
        await sqlStateOf(client, "SELECT nextval('public.global_op_seq')"),
        INSUFFICIENT_PRIVILEGE,
        `${role} must not advance the ordering authority`,
      );
      assertEquals(
        await sqlStateOf(client, "SELECT setval('public.global_op_seq', 1)"),
        INSUFFICIENT_PRIVILEGE,
        `${role} must not reset the ordering authority`,
      );
      await actAsPostgres(client);
    }
  },
);

dbTest("client roles cannot call the privileged RPCs", async (client) => {
  await client.queryArray("SET LOCAL ROLE authenticated");

  for (
    const call of [
      "SELECT public.next_global_op_seq()",
      "SELECT * FROM public.append_sync_audit_op(" +
      "NULL, 'op', 'transaction', 'e', 'CREATE', NULL, now(), 'dev')",
      "SELECT * FROM public.provision_workspace('h', 'e@test.dev')",
      "SELECT * FROM public.claim_worker_seat(NULL, 'e@test.dev', 'editor')",
      "SELECT * FROM public.consume_sync_usage(NULL, '2026-08', 1, 10)",
      "SELECT * FROM public.consume_rate_limits('[]'::jsonb)",
      "SELECT public.ensure_audit_log_partitions(1)",
    ]
  ) {
    assertEquals(
      await sqlStateOf(client, call),
      INSUFFICIENT_PRIVILEGE,
      `authenticated must not execute: ${call}`,
    );
  }
});

dbTest("RLS is enabled on every public table", async (client) => {
  const result = await client.queryObject<{ relname: string }>(`
    SELECT c.relname
    FROM pg_class c
    WHERE c.relnamespace = 'public'::regnamespace
      AND c.relkind IN ('r', 'p')
      AND c.relispartition = false
      AND NOT c.relrowsecurity
  `);
  assertEquals(
    result.rows.map((r) => r.relname),
    [],
    "every base table must have RLS enabled",
  );
});

// ── audit_logs: action vocabulary and partitioning ──────────────────────────

dbTest("audit_logs accepts every action the client emits", async (client) => {
  await seedTenants(client);

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
    const state = await sqlStateOf(
      client,
      `INSERT INTO public.audit_logs
         (id, workspace_id, entity_type, entity_id, action, logged_at, device_id)
       VALUES ('op-${action}', '${WORKSPACE_A}', 'ledger', 'ledger-a-live',
               '${action}', now(), 'device-1')`,
    );
    assertEquals(state, null, `${action} must be storable`);
  }
});

dbTest("audit_logs still rejects an unknown action", async (client) => {
  await seedTenants(client);
  const state = await sqlStateOf(
    client,
    `INSERT INTO public.audit_logs
       (id, workspace_id, entity_type, entity_id, action, logged_at, device_id)
     VALUES ('op-bad', '${WORKSPACE_A}', 'ledger', 'l', 'DROP', now(), 'd')`,
  );
  assertEquals(state, "23514", "the allow-list must stay closed");
});

dbTest(
  "a DEFAULT partition exists so an insert can never miss a range",
  async (client) => {
    const hasDefault = await countRows(
      client,
      `SELECT count(*) FROM pg_class c
      WHERE c.relnamespace = 'public'::regnamespace
        AND c.relname = 'audit_logs_default'`,
    );
    assertEquals(hasDefault, 1);

    // An out-of-range instant must land somewhere rather than fail.
    await seedTenants(client);
    const state = await sqlStateOf(
      client,
      `INSERT INTO public.audit_logs
       (id, workspace_id, entity_type, entity_id, action, logged_at, device_id)
     VALUES ('op-far', '${WORKSPACE_A}', 'ledger', 'l', 'CREATE',
             '2099-01-01T00:00:00Z', 'd')`,
    );
    assertEquals(state, null);
  },
);

dbTest("monthly partitions run at least 12 months ahead", async (client) => {
  const ahead = await countRows(
    client,
    `SELECT count(*) FROM pg_class c
      WHERE c.relnamespace = 'public'::regnamespace
        AND c.relname ~ '^audit_logs_y[0-9]{4}m[0-9]{2}$'
        AND c.relname >= 'audit_logs_y' || to_char(now(), 'YYYY') || 'm' || to_char(now(), 'MM')`,
  );
  assert(ahead >= 12, `only ${ahead} future monthly partitions provisioned`);
});

dbTest("ensure_audit_log_partitions is idempotent", async (client) => {
  const first = await client.queryArray<[number]>(
    "SELECT public.ensure_audit_log_partitions(6)",
  );
  assertEquals(first.rows[0][0], 0, "existing months must not be recreated");
});

// ── D1: seat cap rejects, editor cap downgrades ─────────────────────────────

interface SeatClaimRow {
  member_id: string | null;
  effective_role: string | null;
  seat_index: number | null;
  outcome: string;
}

async function claimSeat(
  client: Client,
  workspaceId: string,
  email: string,
  role: string,
): Promise<SeatClaimRow> {
  const result = await client.queryObject<SeatClaimRow>(
    "SELECT * FROM public.claim_worker_seat($1, $2, $3)",
    [workspaceId, email, role],
  );
  return result.rows[0];
}

/** Workspace with only an Owner seat — one Editor slot remains. */
async function seedSoloOwner(client: Client): Promise<void> {
  await client.queryArray(`
    INSERT INTO public.workspaces (id, owner_identity, status, tier)
    VALUES ('${WORKSPACE_A}', '${OWNER_A}', 'active', 'pro_plus');
    INSERT INTO public.workspace_members
      (workspace_id, invited_email, identity_hash, role, status, seat_index)
    VALUES ('${WORKSPACE_A}', 'owner-a@test.dev', '${OWNER_A}', 'owner', 'active', 0);
  `);
}

dbTest(
  "D1: an Editor invite into Owner + 1 Editor downgrades to viewer",
  async (client) => {
    await seedSoloOwner(client);

    // Owner occupies one of the two Editor slots, so the first worker may be an
    // Editor and the second may not.
    const first = await claimSeat(client, WORKSPACE_A, "w1@test.dev", "editor");
    assertEquals(first.outcome, "created");
    assertEquals(first.effective_role, "editor");
    assertEquals(first.seat_index, 1);

    const second = await claimSeat(
      client,
      WORKSPACE_A,
      "w2@test.dev",
      "editor",
    );
    assertEquals(second.outcome, "created");
    assertEquals(
      second.effective_role,
      "viewer",
      "the Owner counts toward the 2-editor cap, so the 2nd worker cannot be an Editor",
    );
    assertEquals(second.seat_index, 2);
  },
);

dbTest(
  "D1: at most one worker Editor exists after the downgrade",
  async (client) => {
    await seedSoloOwner(client);
    await claimSeat(client, WORKSPACE_A, "w1@test.dev", "editor");
    await claimSeat(client, WORKSPACE_A, "w2@test.dev", "editor");

    const editorCapable = await countRows(
      client,
      `SELECT count(*) FROM public.workspace_members
      WHERE workspace_id = '${WORKSPACE_A}'
        AND status IN ('pending','active')
        AND role IN ('owner','editor')`,
    );
    assertEquals(editorCapable, 2, "Owner + exactly one Editor");
  },
);

dbTest("D1: a viewer request is never upgraded", async (client) => {
  await seedSoloOwner(client);
  const claim = await claimSeat(client, WORKSPACE_A, "w1@test.dev", "viewer");
  assertEquals(claim.effective_role, "viewer");
});

dbTest("D1: the seat cap REJECTS rather than downgrading", async (client) => {
  await seedSoloOwner(client);
  await claimSeat(client, WORKSPACE_A, "w1@test.dev", "viewer");
  await claimSeat(client, WORKSPACE_A, "w2@test.dev", "viewer");

  const third = await claimSeat(client, WORKSPACE_A, "w3@test.dev", "viewer");
  assertEquals(third.outcome, "seat_cap_exceeded");
  assertEquals(third.member_id, null);
});

dbTest(
  "D1: re-inviting a pending Editor reuses the seat without downgrading",
  async (client) => {
    await seedSoloOwner(client);
    const first = await claimSeat(client, WORKSPACE_A, "w1@test.dev", "editor");
    assertEquals(first.effective_role, "editor");

    // Excluding the reused member from the tally keeps this idempotent.
    const again = await claimSeat(
      client,
      WORKSPACE_A,
      " W1@Test.dev ",
      "editor",
    );
    assertEquals(again.outcome, "reused");
    assertEquals(again.member_id, first.member_id);
    assertEquals(again.effective_role, "editor");

    assertEquals(
      await countRows(
        client,
        `SELECT count(*) FROM public.workspace_members
        WHERE workspace_id = '${WORKSPACE_A}' AND seat_index > 0`,
      ),
      1,
      "a re-invite must not consume a second seat",
    );
  },
);

dbTest("D1: an unknown workspace is reported, not created", async (client) => {
  const claim = await claimSeat(
    client,
    "cccccccc-3333-4333-8333-cccccccccccc",
    "w@test.dev",
    "editor",
  );
  assertEquals(claim.outcome, "workspace_not_found");
});

dbTest("D1: claim_worker_seat validates its inputs", async (client) => {
  await seedSoloOwner(client);
  assert(
    await sqlStateOf(
      client,
      `SELECT * FROM public.claim_worker_seat('${WORKSPACE_A}', '', 'editor')`,
    ) !== null,
  );
  assert(
    await sqlStateOf(
      client,
      `SELECT * FROM public.claim_worker_seat('${WORKSPACE_A}', 'a@b.co', 'owner')`,
    ) !== null,
    "a worker may never be seated as owner",
  );
});

// ── Atomic sync usage accounting ────────────────────────────────────────────

async function consumeUsage(
  client: Client,
  events: number,
  cap: number,
): Promise<{ allowed: boolean; event_count: number }> {
  const result = await client.queryObject<
    { allowed: boolean; event_count: number }
  >(
    "SELECT * FROM public.consume_sync_usage($1, $2, $3, $4)",
    [WORKSPACE_A, "2026-08", events, cap],
  );
  return result.rows[0];
}

dbTest("sync usage increments and enforces the cap", async (client) => {
  await seedSoloOwner(client);

  assertEquals(await consumeUsage(client, 4, 10), {
    allowed: true,
    event_count: 4,
  });
  assertEquals(await consumeUsage(client, 6, 10), {
    allowed: true,
    event_count: 10,
  });

  // At the cap: the next event is refused and the counter does not move.
  const refused = await consumeUsage(client, 1, 10);
  assertEquals(refused.allowed, false);
  assertEquals(refused.event_count, 10);
});

dbTest(
  "a batch larger than the remaining headroom is refused whole",
  async (client) => {
    await seedSoloOwner(client);
    await consumeUsage(client, 8, 10);

    const refused = await consumeUsage(client, 5, 10);
    assertEquals(refused.allowed, false);
    assertEquals(
      refused.event_count,
      8,
      "a refused batch must not partially apply",
    );
  },
);

dbTest("a negative reservation release is clamped at zero", async (client) => {
  await seedSoloOwner(client);
  await consumeUsage(client, 5, 10);

  assertEquals((await consumeUsage(client, -2, 10)).event_count, 3);
  assertEquals((await consumeUsage(client, -99, 10)).event_count, 0);
});

dbTest("sync usage rejects a malformed month", async (client) => {
  await seedSoloOwner(client);
  const state = await sqlStateOf(
    client,
    `SELECT * FROM public.consume_sync_usage('${WORKSPACE_A}', '2026-8', 1, 10)`,
  );
  assert(state !== null, "usage_month must be YYYY-MM");
});

// ── Tenant integrity ────────────────────────────────────────────────────────

dbTest(
  "a contact cannot point at another workspace's ledger",
  async (client) => {
    await seedTenants(client);

    const state = await sqlStateOf(
      client,
      `INSERT INTO public.contacts (id, workspace_id, ledger_id, name, avatar_color)
     VALUES ('mismatch', '${WORKSPACE_A}', 'ledger-b-live', 'X', '#000000')`,
    );
    assert(state !== null, "the tenant-integrity trigger must reject this");
  },
);

dbTest(
  "a transaction cannot point at another workspace's contact",
  async (client) => {
    await seedTenants(client);

    const state = await sqlStateOf(
      client,
      `INSERT INTO public.transactions
       (id, workspace_id, contact_id, type, amount, currency, transaction_date)
     VALUES ('mismatch-txn', '${WORKSPACE_A}', 'contact-b-live', 'debt', 100, 'YER', now())`,
    );
    assert(state !== null);
  },
);

dbTest("money columns reject non-positive amounts", async (client) => {
  await seedTenants(client);

  for (const amount of ["0", "-1"]) {
    const state = await sqlStateOf(
      client,
      `INSERT INTO public.transactions
         (id, workspace_id, contact_id, type, amount, currency, transaction_date)
       VALUES ('amt-${amount}', '${WORKSPACE_A}', 'contact-a-live', 'debt',
               ${amount}, 'YER', now())`,
    );
    assertEquals(state, "23514", `amount ${amount} must violate the CHECK`);
  }
});

dbTest(
  "money columns are integer types, never floating point",
  async (client) => {
    const result = await client.queryObject<{ data_type: string }>(`
    SELECT data_type FROM information_schema.columns
     WHERE table_schema = 'public'
       AND (
         (table_name = 'transactions' AND column_name = 'amount')
         OR (table_name = 'contacts' AND column_name = 'credit_limit')
         OR (table_name = 'contact_balances'
             AND column_name IN ('total_debt','total_payment','net_balance'))
       )
  `);
    assert(result.rows.length >= 5);
    for (const row of result.rows) {
      assert(
        ["bigint", "integer"].includes(row.data_type),
        `money column typed ${row.data_type}`,
      );
    }
  },
);
