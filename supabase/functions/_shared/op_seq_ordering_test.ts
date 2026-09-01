// ============================================================================
// op_seq visibility / commit-ordering tests
// ============================================================================
// These run real concurrent Postgres connections with deliberately interleaved
// commits. Nothing here is simulated in TypeScript: the interleaving is produced
// by holding open transactions on separate sockets.
//
// Two write patterns are exercised through one harness:
//
//   "legacy"  — the pre-fix Edge Function: `SELECT next_global_op_seq()` in one
//               transaction, `INSERT INTO audit_logs` in another, with a delay
//               between them standing in for the PostgREST round trip.
//   "locked"  — append_sync_audit_op(): draw and insert in one transaction under
//               a per-workspace advisory lock held to COMMIT.
//
// The legacy tests assert that ops ARE lost. That is deliberate — it proves the
// harness is capable of catching the defect, so the passing result on the new
// path is evidence rather than decoration.
//
// REQUIRES A RUNNING LOCAL STACK (`supabase start` / `supabase db start`).
// Skipped wholesale when Postgres is unreachable so CI without Docker stays
// green.
// ============================================================================

import { assert, assertEquals, assertGreater } from "@std/assert";
import { Client } from "@db/postgres";

const DB_URL = Deno.env.get("SUPABASE_DB_URL") ??
  "postgresql://postgres:postgres@127.0.0.1:54322/postgres";

/** Postgres SQLSTATE raised when `lock_timeout` expires. */
const LOCK_NOT_AVAILABLE = "55P03";

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
    `[op_seq_ordering_test] SKIPPED — no Postgres at ${DB_URL}. ` +
      "Start the local stack with `supabase db start` to run these tests.",
  );
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function openClient(): Promise<Client> {
  const client = new Client(DB_URL);
  await client.connect();
  return client;
}

async function closeAll(clients: Client[]): Promise<void> {
  for (const client of clients) {
    try {
      await client.end();
    } catch {
      // Already closed.
    }
  }
}

/**
 * Each test owns a fresh workspace id, so a shared global sequence and any
 * leftover rows from other suites cannot influence the result.
 */
function newWorkspaceId(): string {
  return crypto.randomUUID();
}

async function purge(client: Client, workspaceId: string): Promise<void> {
  await client.queryArray(
    "DELETE FROM public.audit_logs WHERE workspace_id = $1",
    [workspaceId],
  );
}

// ---------------------------------------------------------------------------
// Write patterns
// ---------------------------------------------------------------------------

/** The pre-fix pattern: draw in one statement, insert in a later one. */
async function appendLegacy(
  client: Client,
  workspaceId: string,
  opId: string,
  gapMs: number,
): Promise<number> {
  const drawn = await client.queryObject<{ seq: string }>(
    "SELECT public.next_global_op_seq()::text AS seq",
  );
  const opSeq = Number(drawn.rows[0].seq);

  // Stands in for the network round trip that separated the two statements.
  if (gapMs > 0) await sleep(gapMs);

  await client.queryArray(
    `INSERT INTO public.audit_logs
       (id, workspace_id, entity_type, entity_id, action,
        logged_at, device_id, server_updated_at, op_seq)
     VALUES ($1, $2, 'transaction', $1, 'CREATE',
             now(), 'device-test', clock_timestamp(), $3)`,
    [opId, workspaceId, opSeq],
  );
  return opSeq;
}

/** The fixed pattern: one transaction, one advisory lock, one visible unit. */
async function appendLocked(
  client: Client,
  workspaceId: string,
  opId: string,
): Promise<{ opSeq: number; status: string }> {
  const result = await client.queryObject<{ seq: string; status: string }>(
    `SELECT op_seq::text AS seq, status
       FROM public.append_sync_audit_op(
         $1, $2, 'transaction', $2, 'CREATE', NULL, now(), 'device-test')`,
    [workspaceId, opId],
  );
  return {
    opSeq: Number(result.rows[0].seq),
    status: result.rows[0].status,
  };
}

/** Exactly what pull-sync-ops does: ordered scan above a watermark. */
async function pullSince(
  client: Client,
  workspaceId: string,
  sinceOpSeq: number,
): Promise<Array<{ id: string; opSeq: number }>> {
  const result = await client.queryObject<{ id: string; seq: string }>(
    `SELECT id, op_seq::text AS seq
       FROM public.audit_logs
      WHERE workspace_id = $1
        AND op_seq IS NOT NULL
        AND op_seq > $2
      ORDER BY op_seq
      LIMIT 500`,
    [workspaceId, sinceOpSeq],
  );
  return result.rows.map((row) => ({ id: row.id, opSeq: Number(row.seq) }));
}

function dbTest(name: string, fn: () => Promise<void>): void {
  Deno.test({ name, ignore: !dbAvailable, fn });
}

// ===========================================================================
// 1. Deterministic interleaving — the exact scenario from the defect report
// ===========================================================================

dbTest(
  "legacy assignment: a puller permanently skips an op committed out of order",
  async () => {
    const workspaceId = newWorkspaceId();
    const writerA = await openClient();
    const writerB = await openClient();
    const reader = await openClient();

    try {
      // A draws first but has not written its row yet.
      const drawn = await writerA.queryObject<{ seq: string }>(
        "SELECT public.next_global_op_seq()::text AS seq",
      );
      const seqA = Number(drawn.rows[0].seq);

      // B draws second, writes and commits first.
      const seqB = await appendLegacy(writerB, workspaceId, "op-b", 0);
      assertGreater(seqB, seqA, "B must hold the higher sequence number");

      // The puller reads in the window between B's commit and A's, and moves
      // its watermark to the highest op_seq it saw — which is what the client
      // does, and the only thing it can do.
      const firstPage = await pullSince(reader, workspaceId, 0);
      assertEquals(firstPage.map((row) => row.id), ["op-b"]);
      const watermark = firstPage[firstPage.length - 1].opSeq;

      // A now commits, below the watermark.
      await writerA.queryArray(
        `INSERT INTO public.audit_logs
           (id, workspace_id, entity_type, entity_id, action,
            logged_at, device_id, server_updated_at, op_seq)
         VALUES ('op-a', $1, 'transaction', 'op-a', 'CREATE',
                 now(), 'device-test', clock_timestamp(), $2)`,
        [workspaceId, seqA],
      );

      // op-a is durably stored...
      const stored = await reader.queryObject<{ count: string }>(
        "SELECT count(*)::text AS count FROM public.audit_logs WHERE workspace_id = $1",
        [workspaceId],
      );
      assertEquals(stored.rows[0].count, "2");

      // ...and permanently undeliverable. This is the data loss.
      const secondPage = await pullSince(reader, workspaceId, watermark);
      assertEquals(
        secondPage,
        [],
        "the pre-fix pattern loses op-a — if this ever returns a row the " +
          "harness has stopped reproducing the defect and the fixed-path " +
          "assertions below are worthless",
      );
    } finally {
      await purge(reader, workspaceId);
      await closeAll([writerA, writerB, reader]);
    }
  },
);

dbTest(
  "commit-ordered assignment: the same interleaving cannot occur",
  async () => {
    const workspaceId = newWorkspaceId();
    const writerA = await openClient();
    const writerB = await openClient();
    const reader = await openClient();

    try {
      // A takes a number and holds its transaction open — the same starting
      // position that lost op-a above.
      await writerA.queryArray("BEGIN");
      const first = await appendLocked(writerA, workspaceId, "op-a");

      // B cannot draw a number while A's transaction is open. Proven by an
      // explicit lock timeout rather than by a race that might not fire.
      await writerB.queryArray("BEGIN");
      await writerB.queryArray("SET LOCAL lock_timeout = '400ms'");
      let blocked = false;
      try {
        await appendLocked(writerB, workspaceId, "op-b");
      } catch (error) {
        const code = (error as { fields?: { code?: string } })?.fields?.code;
        assertEquals(
          code,
          LOCK_NOT_AVAILABLE,
          `expected a lock timeout, got ${JSON.stringify(error)}`,
        );
        blocked = true;
      }
      assert(blocked, "B drew an op_seq while A's transaction was still open");
      await writerB.queryArray("ROLLBACK");

      // Nothing is visible yet, so no watermark can advance past op-a.
      assertEquals(await pullSince(reader, workspaceId, 0), []);

      await writerA.queryArray("COMMIT");

      // B now proceeds and necessarily lands above A.
      const second = await appendLocked(writerB, workspaceId, "op-b");
      assertGreater(second.opSeq, first.opSeq);

      const page = await pullSince(reader, workspaceId, 0);
      assertEquals(page.map((row) => row.id), ["op-a", "op-b"]);
    } finally {
      await purge(reader, workspaceId);
      await closeAll([writerA, writerB, reader]);
    }
  },
);

// ===========================================================================
// 2. Concurrent stress — many writers, a polling reader with a real watermark
// ===========================================================================

interface StressOutcome {
  written: string[];
  delivered: string[];
  lost: string[];
  outOfOrder: number;
}

/**
 * Runs `writers` connections appending concurrently to one workspace while a
 * separate connection polls with a monotonically advancing watermark — the
 * client's actual pull loop. Any op the poller never sees is lost forever.
 */
async function runStress(
  mode: "legacy" | "locked",
  writers: number,
  opsPerWriter: number,
): Promise<StressOutcome> {
  const workspaceId = newWorkspaceId();
  const writerClients: Client[] = [];
  for (let i = 0; i < writers; i++) {
    writerClients.push(await openClient());
  }
  const reader = await openClient();

  const written: string[] = [];
  const delivered: string[] = [];
  const seen = new Set<string>();
  let watermark = 0;
  let outOfOrder = 0;
  let lastOpSeq = 0;
  let stop = false;

  const poll = async () => {
    const rows = await pullSince(reader, workspaceId, watermark);
    for (const row of rows) {
      if (row.opSeq < lastOpSeq) outOfOrder++;
      lastOpSeq = row.opSeq;
      if (!seen.has(row.id)) {
        seen.add(row.id);
        delivered.push(row.id);
      }
      // The watermark only ever moves forward, exactly like the client.
      if (row.opSeq > watermark) watermark = row.opSeq;
    }
  };

  const poller = (async () => {
    while (!stop) {
      await poll();
      await sleep(2);
    }
    // Final drain after every writer has committed.
    await poll();
  })();

  try {
    await Promise.all(writerClients.map(async (client, writerIndex) => {
      for (let opIndex = 0; opIndex < opsPerWriter; opIndex++) {
        const opId = `op-${writerIndex}-${opIndex}`;
        if (mode === "legacy") {
          // Autocommit, two statements — the pre-fix Edge Function verbatim.
          await appendLegacy(client, workspaceId, opId, 4 + Math.random() * 16);
        } else {
          await appendLocked(client, workspaceId, opId);
        }
        written.push(opId);
      }
    }));
  } finally {
    stop = true;
    await poller;
    await purge(reader, workspaceId);
    await closeAll([...writerClients, reader]);
  }

  return {
    written,
    delivered,
    lost: written.filter((id) => !seen.has(id)),
    outOfOrder,
  };
}

dbTest(
  "legacy assignment: concurrent writers lose ops under a polling reader",
  async () => {
    const outcome = await runStress("legacy", 6, 8);
    assertEquals(outcome.written.length, 48);
    assertGreater(
      outcome.lost.length,
      0,
      "the pre-fix pattern did not lose an op in this run — the stress " +
        "harness is no longer reproducing the defect",
    );
  },
);

dbTest(
  "commit-ordered assignment: concurrent writers lose nothing",
  async () => {
    const outcome = await runStress("locked", 6, 8);
    assertEquals(outcome.written.length, 48);
    assertEquals(
      outcome.lost,
      [],
      "an op committed but was never delivered to the polling reader",
    );
    assertEquals(outcome.delivered.length, 48);
    assertEquals(
      outcome.outOfOrder,
      0,
      "a page delivered a lower op_seq after a higher one",
    );
  },
);

// ===========================================================================
// 3. Idle case — the regression risk of any holdback design
// ===========================================================================

dbTest(
  "idle: a lone op is deliverable immediately, with no later op to unblock it",
  async () => {
    const workspaceId = newWorkspaceId();
    const writer = await openClient();
    const reader = await openClient();

    try {
      const appended = await appendLocked(writer, workspaceId, "op-solo");

      // No settle window, no high-water mark: the op is visible the instant it
      // commits. A stability-lag design would return [] here until either a
      // timer expired or a later op arrived.
      const immediate = await pullSince(reader, workspaceId, 0);
      assertEquals(immediate.map((row) => row.id), ["op-solo"]);
      assertEquals(immediate[0].opSeq, appended.opSeq);

      // And it stays deliverable while the system is completely quiet — it is
      // not withheld pending traffic that may never come.
      await sleep(1200);
      const afterIdle = await pullSince(reader, workspaceId, 0);
      assertEquals(afterIdle.map((row) => row.id), ["op-solo"]);

      // A caught-up puller sees nothing new and does not spin backwards.
      assertEquals(
        await pullSince(reader, workspaceId, appended.opSeq),
        [],
      );
    } finally {
      await purge(reader, workspaceId);
      await closeAll([writer, reader]);
    }
  },
);

dbTest(
  "idle: an op behind an unrelated workspace's open transaction still ships",
  async () => {
    // A global high-water mark keyed on the oldest in-flight transaction — one
    // of the designs considered — would stall every tenant behind any single
    // long-running transaction anywhere in the database. The per-workspace lock
    // does not.
    const busyWorkspace = newWorkspaceId();
    const quietWorkspace = newWorkspaceId();
    const blocker = await openClient();
    const writer = await openClient();
    const reader = await openClient();

    try {
      await blocker.queryArray("BEGIN");
      await appendLocked(blocker, busyWorkspace, "op-blocking");

      // Different workspace, different lock: this must not wait.
      const appended = await appendLocked(writer, quietWorkspace, "op-quiet");
      const page = await pullSince(reader, quietWorkspace, 0);
      assertEquals(page.map((row) => row.id), ["op-quiet"]);
      assertEquals(page[0].opSeq, appended.opSeq);

      await blocker.queryArray("ROLLBACK");
    } finally {
      await purge(reader, busyWorkspace);
      await purge(reader, quietWorkspace);
      await closeAll([blocker, writer, reader]);
    }
  },
);

// ===========================================================================
// 4. Idempotency under the lock
// ===========================================================================

dbTest(
  "append_sync_audit_op reports a replayed op_id as duplicate, not a new op",
  async () => {
    const workspaceId = newWorkspaceId();
    const writer = await openClient();
    const reader = await openClient();

    try {
      const first = await appendLocked(writer, workspaceId, "op-replay");
      assertEquals(first.status, "applied");

      const replay = await appendLocked(writer, workspaceId, "op-replay");
      assertEquals(replay.status, "duplicate");
      assertEquals(replay.opSeq, first.opSeq);

      const page = await pullSince(reader, workspaceId, 0);
      assertEquals(page.length, 1, "a replay must not append a second row");
    } finally {
      await purge(reader, workspaceId);
      await closeAll([writer, reader]);
    }
  },
);

dbTest(
  "concurrent identical pushes resolve to one row without a unique violation",
  async () => {
    const workspaceId = newWorkspaceId();
    const clientA = await openClient();
    const clientB = await openClient();
    const reader = await openClient();

    try {
      const [resultA, resultB] = await Promise.all([
        appendLocked(clientA, workspaceId, "op-raced"),
        appendLocked(clientB, workspaceId, "op-raced"),
      ]);

      const statuses = [resultA.status, resultB.status].sort();
      assertEquals(statuses, ["applied", "duplicate"]);
      assertEquals(resultA.opSeq, resultB.opSeq);

      const page = await pullSince(reader, workspaceId, 0);
      assertEquals(page.length, 1);
    } finally {
      await purge(reader, workspaceId);
      await closeAll([clientA, clientB, reader]);
    }
  },
);

dbTest(
  "op_seq stays strictly increasing with commit order across many appends",
  async () => {
    const workspaceId = newWorkspaceId();
    const writers: Client[] = [];
    for (let i = 0; i < 4; i++) writers.push(await openClient());
    const reader = await openClient();

    try {
      await Promise.all(writers.map(async (client, writerIndex) => {
        for (let opIndex = 0; opIndex < 10; opIndex++) {
          await appendLocked(
            client,
            workspaceId,
            `op-${writerIndex}-${opIndex}`,
          );
        }
      }));

      const page = await pullSince(reader, workspaceId, 0);
      assertEquals(page.length, 40);

      const sequences = page.map((row) => row.opSeq);
      for (let i = 1; i < sequences.length; i++) {
        assertGreater(sequences[i], sequences[i - 1]);
      }
    } finally {
      await purge(reader, workspaceId);
      await closeAll([...writers, reader]);
    }
  },
);
