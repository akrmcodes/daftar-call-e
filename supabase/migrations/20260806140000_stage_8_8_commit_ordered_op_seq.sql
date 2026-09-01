-- ============================================================================
-- Stage 8.8 — Commit-ordered op_seq assignment
-- ============================================================================
-- THE DEFECT
--
-- push-sync-ops drew its sequence number and wrote its audit row in two
-- separate transactions:
--
--     tx1:  SELECT next_global_op_seq()        -- draws 10
--     tx2:  INSERT INTO audit_logs (..., 10)   -- commits later
--
-- Sequence numbers are handed out in draw order but become *visible to a
-- reader* in commit order, and nothing tied the two together. Interleave two
-- pushes to the same workspace:
--
--     A draws 10 ............................ (still in flight)
--     B draws 11, inserts, COMMITs
--     puller reads: sees 11, advances watermark to 11
--     A inserts 10, COMMITs
--     puller reads WHERE op_seq > 11: op 10 is never returned again
--
-- Op 10 is durably stored and permanently undeliverable. For this product that
-- is a merchant's payment silently missing on one device, with no error raised
-- anywhere. Not acceptable at any window size.
--
-- THE FIX
--
-- Assignment and insertion move into one transaction, and that transaction
-- holds an exclusive per-workspace advisory lock across both. The lock is
-- transaction-scoped, so it is released at COMMIT — never before.
--
-- INVARIANT (per workspace W)
--
--     For any two audit rows r1, r2 in W with op_seq(r1) < op_seq(r2),
--     r1's transaction committed strictly before r2's transaction committed.
--
-- Proof: both drew nextval() while holding W's exclusive lock. r2 could not
-- acquire that lock until r1's transaction released it, and a transaction-scoped
-- advisory lock is released only at COMMIT or ROLLBACK. So r2's draw strictly
-- follows r1's commit (if r1 rolled back, r1 does not exist). Therefore any
-- snapshot that sees r2 also sees r1, and a reader ordering by op_seq can never
-- skip a row that appears later. The visibility gap is closed, not narrowed.
--
-- The lock is per workspace, not global: pulls always filter by workspace_id, so
-- ordering only has to be total within one tenant. Pushes to different
-- workspaces stay fully parallel.
--
-- Holding the lock across the duplicate check also removes the check-then-insert
-- race that push-sync-ops previously papered over by catching 23505.
-- ============================================================================

-- No new index is added for the idempotency probe. It filters on
-- (workspace_id, id) and orders by logged_at, which the (id, logged_at) primary
-- key already serves as a backward index scan with no sort — verified with
-- EXPLAIN. A (workspace_id, id) index was measured and the planner ignored it,
-- so it would have been pure write amplification on the hottest append-only
-- table in the schema.

-- ----------------------------------------------------------------------------
-- §1  append_sync_audit_op — the only sanctioned way to assign an op_seq
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.append_sync_audit_op(
  p_workspace_id UUID,
  p_op_id        TEXT,
  p_entity_type  TEXT,
  p_entity_id    TEXT,
  p_action       TEXT,
  p_payload      JSONB,
  p_logged_at    TIMESTAMPTZ,
  p_device_id    TEXT
)
RETURNS TABLE (
  op_seq            BIGINT,
  server_updated_at TIMESTAMPTZ,
  status            TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  -- Namespace seed keeps these locks from colliding with advisory locks taken
  -- anywhere else in the database.
  c_lock_seed CONSTANT BIGINT := 8801;
  v_op_seq    BIGINT;
  v_now       TIMESTAMPTZ;
BEGIN
  IF p_workspace_id IS NULL THEN
    RAISE EXCEPTION 'workspace_id is required' USING ERRCODE = '22023';
  END IF;
  IF p_op_id IS NULL OR length(p_op_id) = 0 THEN
    RAISE EXCEPTION 'op_id is required' USING ERRCODE = '22023';
  END IF;

  -- Serializes op_seq assignment within this workspace for the remainder of the
  -- transaction. Everything below — the duplicate probe, the draw and the
  -- insert — is therefore atomic with respect to other pushes to the same
  -- workspace, and becomes visible to readers as one unit.
  PERFORM pg_advisory_xact_lock(
    hashtextextended(p_workspace_id::TEXT, c_lock_seed)
  );

  -- Idempotency. Safe to read-then-write: the lock is already held, so no
  -- concurrent push to this workspace can insert between the two statements.
  SELECT a.op_seq, a.server_updated_at
    INTO v_op_seq, v_now
    FROM public.audit_logs a
   WHERE a.workspace_id = p_workspace_id
     AND a.id = p_op_id
     AND a.op_seq IS NOT NULL
   ORDER BY a.logged_at DESC
   LIMIT 1;

  IF FOUND THEN
    op_seq            := v_op_seq;
    server_updated_at := v_now;
    status            := 'duplicate';
    RETURN NEXT;
    RETURN;
  END IF;

  v_op_seq := nextval('public.global_op_seq');

  -- clock_timestamp(), not now(): now() is the transaction start time, and a
  -- transaction that waited on the lock started before the one ahead of it
  -- committed. Using the statement clock keeps server_updated_at monotonic with
  -- op_seq, which the client relies on for conflict resolution.
  v_now := clock_timestamp();

  INSERT INTO public.audit_logs (
    id, workspace_id, entity_type, entity_id, action,
    payload, logged_at, device_id, server_updated_at, op_seq
  ) VALUES (
    p_op_id, p_workspace_id, p_entity_type, p_entity_id, p_action,
    p_payload, COALESCE(p_logged_at, v_now), p_device_id, v_now, v_op_seq
  );

  op_seq            := v_op_seq;
  server_updated_at := v_now;
  status            := 'applied';
  RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION public.append_sync_audit_op(
  UUID, TEXT, TEXT, TEXT, TEXT, JSONB, TIMESTAMPTZ, TEXT
) IS
  'Assigns op_seq and appends the audit row in one transaction under a '
  'per-workspace advisory lock, so op_seq order equals commit order within a '
  'workspace and a puller can never skip a committed op. Returns '
  'status=duplicate for an op_id already present.';

REVOKE ALL ON FUNCTION public.append_sync_audit_op(
  UUID, TEXT, TEXT, TEXT, TEXT, JSONB, TIMESTAMPTZ, TEXT
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.append_sync_audit_op(
  UUID, TEXT, TEXT, TEXT, TEXT, JSONB, TIMESTAMPTZ, TEXT
) TO service_role;

-- ----------------------------------------------------------------------------
-- §2  Deprecate the unlocked draw
-- ----------------------------------------------------------------------------
-- next_global_op_seq() hands out a number with no lock and no row, which is
-- exactly the pattern that produced the visibility gap. It is left callable so
-- that a deploy which applies migrations before shipping the new Edge Function
-- bundle does not 500, and should be dropped once push-sync-ops is live.

COMMENT ON FUNCTION public.next_global_op_seq() IS
  'DEPRECATED — unsafe. Draws an op_seq outside any transaction that writes a '
  'row, so numbers become visible to readers out of order and a puller can skip '
  'a committed op. Use append_sync_audit_op(). Retained only for deploy '
  'compatibility; drop after push-sync-ops v8.8 is deployed.';
