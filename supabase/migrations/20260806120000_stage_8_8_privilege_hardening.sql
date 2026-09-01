-- ============================================================================
-- Stage 8.8 — Privilege hardening + sync action vocabulary
-- ============================================================================
-- Fixes found in the Stage 8 backend audit:
--
--   1. audit_logs.action CHECK rejected 5 of the 8 action strings the Flutter
--      client emits (RESTORE, ACTIVATE_ARCHIVED, USER_ARCHIVE, USER_UNARCHIVE,
--      CARRY_FORWARD). push-sync-ops applied the entity change and then failed
--      the audit insert with 23514, aborting the whole batch — a permanent,
--      self-retrying push deadlock for any device that archived a ledger.
--
--   2. anon / authenticated held TRUNCATE, TRIGGER and REFERENCES on every
--      business table (leftovers from Supabase's schema-wide default
--      privileges). TRUNCATE is NOT filtered by row-level security, so those
--      grants defeated RLS, FORCE RLS and soft-delete simultaneously:
--      a single TRUNCATE public.audit_logs would erase the append-only op-log
--      of every tenant.
--
--   3. anon / authenticated held UPDATE on public.global_op_seq, allowing
--      setval() on the merge engine's global ordering authority.
--
--   4. SECURITY DEFINER helpers ran with EXECUTE granted to PUBLIC.
--
-- Non-destructive: no data is dropped or rewritten.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- §1  audit_logs.action — accept the full client action vocabulary
-- ----------------------------------------------------------------------------
-- The op-log is a verbatim record of what the client did. Actions beyond the
-- CRUD triple carry semantics the merge engine needs (archive vs delete vs
-- carry-forward), so they are stored as sent rather than flattened to UPDATE.
-- Keep this list in sync with SYNC_OP_ACTIONS in _shared/sync_ops.ts.

ALTER TABLE public.audit_logs
  DROP CONSTRAINT IF EXISTS audit_logs_action_check;

ALTER TABLE public.audit_logs
  ADD CONSTRAINT audit_logs_action_check
  CHECK (action IN (
    'CREATE',
    'UPDATE',
    'DELETE',
    'RESTORE',
    'ACTIVATE_ARCHIVED',
    'USER_ARCHIVE',
    'USER_UNARCHIVE',
    'CARRY_FORWARD'
  ));

COMMENT ON COLUMN public.audit_logs.action
  IS 'Client op verb. Mirrors SYNC_OP_ACTIONS in _shared/sync_ops.ts; push-sync-ops rejects anything outside this set with 400 invalid_action.';


-- ----------------------------------------------------------------------------
-- §2  Strip TRUNCATE / TRIGGER / REFERENCES from client roles
-- ----------------------------------------------------------------------------
-- Supabase grants these schema-wide by default. None are reachable through
-- PostgREST today, but all three defeat RLS if any direct-SQL path exists:
--   • TRUNCATE ignores row-level security entirely.
--   • TRIGGER lets a role attach code that runs inside other sessions.
--   • REFERENCES lets a role pin rows via foreign keys.
-- Covers partitions too (audit_logs_* are relkind 'r').

DO $$
DECLARE
  v_table regclass;
BEGIN
  FOR v_table IN
    SELECT c.oid::regclass
    FROM pg_class c
    WHERE c.relnamespace = 'public'::regnamespace
      AND c.relkind IN ('r', 'p')
    ORDER BY c.oid::regclass::text
  LOOP
    EXECUTE format(
      'REVOKE TRUNCATE, TRIGGER, REFERENCES ON TABLE %s FROM anon, authenticated',
      v_table
    );
  END LOOP;
END $$;

-- Stop future tables from re-acquiring them.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE TRUNCATE, TRIGGER, REFERENCES ON TABLES FROM anon, authenticated;


-- ----------------------------------------------------------------------------
-- §3  Sequences are server-side only
-- ----------------------------------------------------------------------------
-- global_op_seq is the merge engine's total-ordering authority. Only
-- next_global_op_seq() (SECURITY DEFINER, service_role) may advance it.

REVOKE ALL ON SEQUENCE public.global_op_seq FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.deep_link_events_id_seq FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;


-- ----------------------------------------------------------------------------
-- §4  SECURITY DEFINER helpers — least privilege
-- ----------------------------------------------------------------------------
-- RLS policy expressions are evaluated as the invoking role, so `authenticated`
-- needs EXECUTE on every helper referenced by a policy. Nothing else does, and
-- `anon` needs none of them.

REVOKE ALL ON FUNCTION public.jwt_workspace_id() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.jwt_role() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.jwt_identity_hash() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.jwt_member_role() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.jwt_is_member(text[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.ledger_is_user_archived(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.contact_ledger_is_user_archived(text)
  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.jwt_workspace_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.jwt_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.jwt_identity_hash() TO authenticated;
GRANT EXECUTE ON FUNCTION public.jwt_member_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.jwt_is_member(text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ledger_is_user_archived(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.contact_ledger_is_user_archived(text)
  TO authenticated;

-- Trigger functions fire under the DML, never by direct call. Postgres checks
-- EXECUTE at CREATE TRIGGER time, not at fire time, so revoking is safe.
REVOKE ALL ON FUNCTION public.set_updated_at() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enforce_ledger_archive_toggle()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enforce_contact_workspace_integrity()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enforce_transaction_workspace_integrity()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enforce_balance_workspace_integrity()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enforce_ledger_carry_forward_integrity()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enforce_shared_account_workspace_integrity()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enforce_sharing_cap()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enforce_workspace_device_cap()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.deep_link_ttl_interval(public.token_kind)
  FROM PUBLIC, anon, authenticated;


-- ----------------------------------------------------------------------------
-- §5  FORCE RLS on the remaining member-readable tables
-- ----------------------------------------------------------------------------
-- service_role and postgres carry BYPASSRLS, so Edge Functions are unaffected.

ALTER TABLE public.workspace_devices   FORCE ROW LEVEL SECURITY;
ALTER TABLE public.sync_usage_counters FORCE ROW LEVEL SECURITY;


-- ----------------------------------------------------------------------------
-- §6  audit_logs partition maintenance
-- ----------------------------------------------------------------------------
-- Monthly partitions currently run to 2028-09 and a DEFAULT partition exists,
-- so an insert can never fail on a missing range. The DEFAULT is a safety net,
-- not a destination: once a row for month M lands in it, creating the M
-- partition requires an exclusive lock and a scan. Ops should run this
-- function periodically to keep real partitions ahead of the clock.

CREATE OR REPLACE FUNCTION public.ensure_audit_log_partitions(
  p_months_ahead INT DEFAULT 12
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start   DATE := date_trunc('month', now())::date;
  v_month   DATE;
  v_name    TEXT;
  v_created INT := 0;
  i         INT;
BEGIN
  IF p_months_ahead < 1 OR p_months_ahead > 120 THEN
    RAISE EXCEPTION 'p_months_ahead must be between 1 and 120';
  END IF;

  FOR i IN 0..p_months_ahead LOOP
    v_month := (v_start + (i || ' months')::interval)::date;
    v_name := format('audit_logs_y%sm%s',
      to_char(v_month, 'YYYY'), to_char(v_month, 'MM'));

    IF NOT EXISTS (
      SELECT 1 FROM pg_class c
      WHERE c.relnamespace = 'public'::regnamespace AND c.relname = v_name
    ) THEN
      EXECUTE format(
        'CREATE TABLE public.%I PARTITION OF public.audit_logs '
        'FOR VALUES FROM (%L) TO (%L)',
        v_name,
        v_month,
        (v_month + interval '1 month')::date
      );
      EXECUTE format(
        'REVOKE TRUNCATE, TRIGGER, REFERENCES ON TABLE public.%I '
        'FROM anon, authenticated',
        v_name
      );
      v_created := v_created + 1;
    END IF;
  END LOOP;

  RETURN v_created;
END;
$$;

COMMENT ON FUNCTION public.ensure_audit_log_partitions(INT)
  IS 'Idempotently creates monthly audit_logs partitions from the current month forward. Returns the number created. Run from ops/cron.';

REVOKE ALL ON FUNCTION public.ensure_audit_log_partitions(INT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_audit_log_partitions(INT)
  TO service_role;
