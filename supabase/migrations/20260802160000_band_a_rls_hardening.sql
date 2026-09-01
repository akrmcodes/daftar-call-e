-- ============================================================================
-- MIGRATION: Band A RLS Hardening (Stages 8.1 / 8.2 foundation)
-- ============================================================================
-- Fixes:
--   • Active-membership RLS (JWT alone is insufficient)
--   • Owner-only workspace_members mutations
--   • Archived-ledger write lock for Owner AND Editor
--   • Tenant-integrity guards (same-workspace parent/child)
--   • identity_hash on workspace_members + hardened provision_workspace
--   • Unique normalized invited email per workspace
--   • sharing_cap DB guard stub on workspaces / shared_accounts
--   • Audit_log partitions through 2028-08 + DEFAULT partition
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- §1  Schema: identity_hash + sharing_cap
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.workspace_members
  ADD COLUMN IF NOT EXISTS identity_hash TEXT;

COMMENT ON COLUMN public.workspace_members.identity_hash
  IS 'SHA-256 of Google sub. Stamped by provision_workspace on first resolve. Used by RLS active-membership check.';

-- One identity may hold at most one active seat per workspace.
CREATE UNIQUE INDEX IF NOT EXISTS uq_workspace_members_identity_active
  ON public.workspace_members (workspace_id, identity_hash)
  WHERE status = 'active' AND identity_hash IS NOT NULL;

-- Normalized email uniqueness (pending + active consume seats).
CREATE UNIQUE INDEX IF NOT EXISTS uq_workspace_members_email_normalized
  ON public.workspace_members (workspace_id, lower(invited_email))
  WHERE invited_email IS NOT NULL
    AND status IN ('pending', 'active');

-- Backfill owner identity_hash from workspaces.owner_identity.
UPDATE public.workspace_members wm
SET identity_hash = w.owner_identity
FROM public.workspaces w
WHERE wm.workspace_id = w.id
  AND wm.role = 'owner'
  AND wm.seat_index = 0
  AND wm.identity_hash IS NULL
  AND w.owner_identity IS NOT NULL;

-- Sharing cap stub (Free default 0). Edge Functions raise for Pro/Pro+.
ALTER TABLE public.workspaces
  ADD COLUMN IF NOT EXISTS sharing_cap INT NOT NULL DEFAULT 0
  CHECK (sharing_cap >= 0 AND sharing_cap <= 500);

COMMENT ON COLUMN public.workspaces.sharing_cap
  IS 'DB guard for B2C shared_accounts inserts. Free=0 / Pro=30 / Pro+=500. Raised by entitlement Edge Functions.';


-- ────────────────────────────────────────────────────────────────────────────
-- §2  Active-membership helpers (bypass RLS via row_security=off)
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.jwt_member_role()
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_ws   uuid;
  v_hash text;
  v_role text;
BEGIN
  v_ws := public.jwt_workspace_id();
  v_hash := public.jwt_identity_hash();
  IF v_ws IS NULL OR v_hash IS NULL OR length(trim(v_hash)) = 0 THEN
    RETURN NULL;
  END IF;

  -- Prefer membership bound by identity_hash.
  SELECT wm.role INTO v_role
  FROM public.workspace_members wm
  WHERE wm.workspace_id = v_ws
    AND wm.status = 'active'
    AND wm.identity_hash = v_hash
  LIMIT 1;

  IF v_role IS NOT NULL THEN
    RETURN v_role;
  END IF;

  -- Legacy owner seat: identity_hash not yet stamped, match workspaces.owner_identity.
  SELECT wm.role INTO v_role
  FROM public.workspace_members wm
  JOIN public.workspaces w ON w.id = wm.workspace_id
  WHERE wm.workspace_id = v_ws
    AND wm.status = 'active'
    AND wm.role = 'owner'
    AND wm.identity_hash IS NULL
    AND w.owner_identity = v_hash
    AND w.status = 'active'
  LIMIT 1;

  RETURN v_role;
END;
$$;

COMMENT ON FUNCTION public.jwt_member_role()
  IS 'Effective workspace role from active workspace_members (DB), not stale JWT claim. NULL → fail-closed.';

CREATE OR REPLACE FUNCTION public.jwt_is_member(VARIADIC required_roles text[])
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
  SELECT public.jwt_member_role() = ANY (required_roles);
$$;

COMMENT ON FUNCTION public.jwt_is_member(text[])
  IS 'True when caller has an active membership whose DB role is in required_roles.';

-- SECURITY DEFINER helper: read ledger archive flag without recursive RLS.
CREATE OR REPLACE FUNCTION public.ledger_is_user_archived(p_ledger_id text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
  SELECT COALESCE(
    (SELECT l.is_user_archived FROM public.ledgers l WHERE l.id = p_ledger_id),
    false
  );
$$;

CREATE OR REPLACE FUNCTION public.contact_ledger_is_user_archived(p_contact_id text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
  SELECT COALESCE(
    (
      SELECT l.is_user_archived
      FROM public.contacts c
      JOIN public.ledgers l ON l.id = c.ledger_id
      WHERE c.id = p_contact_id
    ),
    false
  );
$$;

-- Prevent non-owners from toggling is_user_archived (replaces fragile RLS subquery).
CREATE OR REPLACE FUNCTION public.enforce_ledger_archive_toggle()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF NEW.is_user_archived IS DISTINCT FROM OLD.is_user_archived THEN
    IF public.jwt_member_role() IS DISTINCT FROM 'owner' THEN
      -- Allow service_role / no-JWT (Edge, migrations) to proceed.
      IF current_setting('request.jwt.claims', true) IS NOT NULL
         AND current_setting('request.jwt.claims', true) <> '' THEN
        RAISE EXCEPTION 'Only workspace owner may toggle is_user_archived';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ledgers_archive_toggle ON public.ledgers;
CREATE TRIGGER trg_ledgers_archive_toggle
  BEFORE UPDATE ON public.ledgers
  FOR EACH ROW EXECUTE FUNCTION public.enforce_ledger_archive_toggle();


-- ────────────────────────────────────────────────────────────────────────────
-- §3  Tenant-integrity triggers
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.enforce_contact_workspace_integrity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.ledgers l
    WHERE l.id = NEW.ledger_id AND l.workspace_id = NEW.workspace_id
  ) THEN
    RAISE EXCEPTION 'contacts.ledger_id must belong to the same workspace';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_contacts_workspace_integrity ON public.contacts;
CREATE TRIGGER trg_contacts_workspace_integrity
  BEFORE INSERT OR UPDATE OF ledger_id, workspace_id ON public.contacts
  FOR EACH ROW EXECUTE FUNCTION public.enforce_contact_workspace_integrity();

CREATE OR REPLACE FUNCTION public.enforce_transaction_workspace_integrity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.contacts c
    WHERE c.id = NEW.contact_id AND c.workspace_id = NEW.workspace_id
  ) THEN
    RAISE EXCEPTION 'transactions.contact_id must belong to the same workspace';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_transactions_workspace_integrity ON public.transactions;
CREATE TRIGGER trg_transactions_workspace_integrity
  BEFORE INSERT OR UPDATE OF contact_id, workspace_id ON public.transactions
  FOR EACH ROW EXECUTE FUNCTION public.enforce_transaction_workspace_integrity();

CREATE OR REPLACE FUNCTION public.enforce_balance_workspace_integrity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.contacts c
    WHERE c.id = NEW.contact_id AND c.workspace_id = NEW.workspace_id
  ) THEN
    RAISE EXCEPTION 'contact_balances.contact_id must belong to the same workspace';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_contact_balances_workspace_integrity ON public.contact_balances;
CREATE TRIGGER trg_contact_balances_workspace_integrity
  BEFORE INSERT OR UPDATE OF contact_id, workspace_id ON public.contact_balances
  FOR EACH ROW EXECUTE FUNCTION public.enforce_balance_workspace_integrity();

CREATE OR REPLACE FUNCTION public.enforce_ledger_carry_forward_integrity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF NEW.carry_forward_target_ledger_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.ledgers t
      WHERE t.id = NEW.carry_forward_target_ledger_id
        AND t.workspace_id = NEW.workspace_id
    ) THEN
      RAISE EXCEPTION 'carry_forward_target_ledger_id must belong to the same workspace';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ledgers_carry_forward_integrity ON public.ledgers;
CREATE TRIGGER trg_ledgers_carry_forward_integrity
  BEFORE INSERT OR UPDATE OF carry_forward_target_ledger_id, workspace_id ON public.ledgers
  FOR EACH ROW EXECUTE FUNCTION public.enforce_ledger_carry_forward_integrity();

CREATE OR REPLACE FUNCTION public.enforce_shared_account_workspace_integrity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.contacts c
    WHERE c.id = NEW.contact_id AND c.workspace_id = NEW.workspace_id
  ) THEN
    RAISE EXCEPTION 'shared_accounts.contact_id must belong to the same workspace';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_shared_accounts_workspace_integrity ON public.shared_accounts;
CREATE TRIGGER trg_shared_accounts_workspace_integrity
  BEFORE INSERT OR UPDATE OF contact_id, workspace_id ON public.shared_accounts
  FOR EACH ROW EXECUTE FUNCTION public.enforce_shared_account_workspace_integrity();


-- ────────────────────────────────────────────────────────────────────────────
-- §4  Sharing-cap DB guard
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.enforce_sharing_cap()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_cap   int;
  v_count int;
BEGIN
  -- Only count slots that consume the tier cap.
  IF NEW.state NOT IN ('active', 'claimed') THEN
    RETURN NEW;
  END IF;

  SELECT w.sharing_cap INTO v_cap
  FROM public.workspaces w
  WHERE w.id = NEW.workspace_id;

  IF v_cap IS NULL THEN
    RAISE EXCEPTION 'workspace not found for sharing_cap check';
  END IF;

  SELECT count(*)::int INTO v_count
  FROM public.shared_accounts sa
  WHERE sa.workspace_id = NEW.workspace_id
    AND sa.state IN ('active', 'claimed')
    AND (TG_OP = 'INSERT' OR sa.id IS DISTINCT FROM NEW.id);

  IF v_count >= v_cap THEN
    RAISE EXCEPTION 'sharing_cap exceeded for workspace (cap=%)', v_cap
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_shared_accounts_sharing_cap ON public.shared_accounts;
CREATE TRIGGER trg_shared_accounts_sharing_cap
  BEFORE INSERT OR UPDATE OF state, workspace_id ON public.shared_accounts
  FOR EACH ROW EXECUTE FUNCTION public.enforce_sharing_cap();


-- ────────────────────────────────────────────────────────────────────────────
-- §5  Hardened provision_workspace
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.provision_workspace(
  p_identity_hash TEXT,
  p_email         TEXT
)
RETURNS TABLE (workspace_id UUID, workspace_role TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_workspace_id UUID;
  v_role         TEXT;
  v_email        TEXT;
  v_member_id    UUID;
BEGIN
  IF p_identity_hash IS NULL OR length(trim(p_identity_hash)) = 0 THEN
    RAISE EXCEPTION 'identity_hash is required';
  END IF;

  v_email := NULLIF(lower(trim(COALESCE(p_email, ''))), '');

  -- 1. Existing owner workspace (stamp identity_hash on owner seat).
  SELECT w.id, 'owner'
    INTO v_workspace_id, v_role
    FROM public.workspaces w
   WHERE w.owner_identity = p_identity_hash
     AND w.status = 'active'
   ORDER BY w.created_at ASC
   LIMIT 1;

  IF v_workspace_id IS NOT NULL THEN
    UPDATE public.workspace_members
       SET identity_hash = p_identity_hash,
           invited_email = COALESCE(invited_email, v_email),
           updated_at = now()
     WHERE workspace_id = v_workspace_id
       AND role = 'owner'
       AND seat_index = 0
       AND (identity_hash IS NULL OR identity_hash = p_identity_hash);

    RETURN QUERY SELECT v_workspace_id, v_role;
    RETURN;
  END IF;

  -- 2. Active worker already bound by identity_hash.
  SELECT wm.workspace_id, wm.role, wm.id
    INTO v_workspace_id, v_role, v_member_id
    FROM public.workspace_members wm
   WHERE wm.identity_hash = p_identity_hash
     AND wm.status = 'active'
   ORDER BY wm.created_at ASC
   LIMIT 1;

  IF v_workspace_id IS NOT NULL THEN
    RETURN QUERY SELECT v_workspace_id, v_role;
    RETURN;
  END IF;

  -- 3. Active worker matched by normalized invited email (oldest first).
  IF v_email IS NOT NULL THEN
    SELECT wm.workspace_id, wm.role, wm.id
      INTO v_workspace_id, v_role, v_member_id
      FROM public.workspace_members wm
     WHERE lower(wm.invited_email) = v_email
       AND wm.status = 'active'
     ORDER BY wm.created_at ASC
     LIMIT 1;

    IF v_workspace_id IS NOT NULL THEN
      UPDATE public.workspace_members
         SET identity_hash = p_identity_hash,
             updated_at = now()
       WHERE id = v_member_id
         AND (identity_hash IS NULL OR identity_hash = p_identity_hash);

      RETURN QUERY SELECT v_workspace_id, v_role;
      RETURN;
    END IF;
  END IF;

  -- 4. First-time user — atomic workspace + owner seat.
  INSERT INTO public.workspaces (owner_identity, status)
  VALUES (p_identity_hash, 'active')
  ON CONFLICT (owner_identity) WHERE status = 'active'
  DO NOTHING
  RETURNING id INTO v_workspace_id;

  IF v_workspace_id IS NULL THEN
    SELECT w.id
      INTO v_workspace_id
      FROM public.workspaces w
     WHERE w.owner_identity = p_identity_hash
       AND w.status = 'active'
     ORDER BY w.created_at ASC
     LIMIT 1;
  END IF;

  IF v_workspace_id IS NULL THEN
    RAISE EXCEPTION 'Failed to provision workspace';
  END IF;

  INSERT INTO public.workspace_members (
    workspace_id,
    role,
    status,
    seat_index,
    invited_email,
    identity_hash
  )
  VALUES (v_workspace_id, 'owner', 'active', 0, v_email, p_identity_hash)
  ON CONFLICT (workspace_id, seat_index) DO UPDATE
    SET identity_hash = COALESCE(public.workspace_members.identity_hash, EXCLUDED.identity_hash),
        invited_email = COALESCE(public.workspace_members.invited_email, EXCLUDED.invited_email),
        updated_at = now();

  RETURN QUERY SELECT v_workspace_id, 'owner'::TEXT;
END;
$$;

COMMENT ON FUNCTION public.provision_workspace(TEXT, TEXT)
  IS 'Auth Bridge RPC: resolve identity→workspace+role; normalize email; stamp identity_hash; oldest-membership wins. service_role only.';

REVOKE ALL ON FUNCTION public.provision_workspace(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.provision_workspace(TEXT, TEXT) TO service_role;


-- ────────────────────────────────────────────────────────────────────────────
-- §6  Drop legacy JWT-only policies and recreate with membership checks
-- ────────────────────────────────────────────────────────────────────────────

-- workspaces
DROP POLICY IF EXISTS workspaces_select ON public.workspaces;
DROP POLICY IF EXISTS workspaces_update_editor ON public.workspaces;
DROP POLICY IF EXISTS workspaces_all_owner ON public.workspaces;

CREATE POLICY workspaces_select
  ON public.workspaces FOR SELECT
  USING (
    id = public.jwt_workspace_id()
    AND public.jwt_is_member('viewer', 'editor', 'owner')
  );

-- Owner-only mutations on workspace lifecycle / owner_identity.
CREATE POLICY workspaces_update_owner
  ON public.workspaces FOR UPDATE
  USING (
    id = public.jwt_workspace_id()
    AND public.jwt_is_member('owner')
  )
  WITH CHECK (
    id = public.jwt_workspace_id()
    AND public.jwt_is_member('owner')
  );

-- workspace_members — select for members; mutate owner-only
DROP POLICY IF EXISTS workspace_members_select ON public.workspace_members;
DROP POLICY IF EXISTS workspace_members_insert_editor ON public.workspace_members;
DROP POLICY IF EXISTS workspace_members_update_editor ON public.workspace_members;
DROP POLICY IF EXISTS workspace_members_all_owner ON public.workspace_members;

CREATE POLICY workspace_members_select
  ON public.workspace_members FOR SELECT
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('viewer', 'editor', 'owner')
  );

CREATE POLICY workspace_members_insert_owner
  ON public.workspace_members FOR INSERT
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('owner')
  );

CREATE POLICY workspace_members_update_owner
  ON public.workspace_members FOR UPDATE
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('owner')
  )
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('owner')
  );

CREATE POLICY workspace_members_delete_owner
  ON public.workspace_members FOR DELETE
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('owner')
  );

-- ledgers
DROP POLICY IF EXISTS ledgers_select ON public.ledgers;
DROP POLICY IF EXISTS ledgers_insert_editor ON public.ledgers;
DROP POLICY IF EXISTS ledgers_update_editor ON public.ledgers;
DROP POLICY IF EXISTS ledgers_all_owner ON public.ledgers;

CREATE POLICY ledgers_select
  ON public.ledgers FOR SELECT
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('viewer', 'editor', 'owner')
  );

CREATE POLICY ledgers_insert_writer
  ON public.ledgers FOR INSERT
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
  );

CREATE POLICY ledgers_update_writer
  ON public.ledgers FOR UPDATE
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
  )
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
  );

CREATE POLICY ledgers_delete_owner
  ON public.ledgers FOR DELETE
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('owner')
  );

-- contacts — archive lock on Owner AND Editor (no owner FOR ALL bypass)
DROP POLICY IF EXISTS contacts_select ON public.contacts;
DROP POLICY IF EXISTS contacts_insert_editor ON public.contacts;
DROP POLICY IF EXISTS contacts_update_editor ON public.contacts;
DROP POLICY IF EXISTS contacts_all_owner ON public.contacts;

CREATE POLICY contacts_select
  ON public.contacts FOR SELECT
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('viewer', 'editor', 'owner')
  );

CREATE POLICY contacts_insert_writer
  ON public.contacts FOR INSERT
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
    AND NOT public.ledger_is_user_archived(ledger_id)
  );

CREATE POLICY contacts_update_writer
  ON public.contacts FOR UPDATE
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
    AND NOT public.ledger_is_user_archived(ledger_id)
  )
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
    AND NOT public.ledger_is_user_archived(ledger_id)
  );

CREATE POLICY contacts_delete_writer
  ON public.contacts FOR DELETE
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
    AND NOT public.ledger_is_user_archived(ledger_id)
  );

-- transactions
DROP POLICY IF EXISTS transactions_select ON public.transactions;
DROP POLICY IF EXISTS transactions_insert_editor ON public.transactions;
DROP POLICY IF EXISTS transactions_update_editor ON public.transactions;
DROP POLICY IF EXISTS transactions_all_owner ON public.transactions;

CREATE POLICY transactions_select
  ON public.transactions FOR SELECT
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('viewer', 'editor', 'owner')
  );

CREATE POLICY transactions_insert_writer
  ON public.transactions FOR INSERT
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
    AND NOT public.contact_ledger_is_user_archived(contact_id)
  );

CREATE POLICY transactions_update_writer
  ON public.transactions FOR UPDATE
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
    AND NOT public.contact_ledger_is_user_archived(contact_id)
  )
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
    AND NOT public.contact_ledger_is_user_archived(contact_id)
  );

CREATE POLICY transactions_delete_writer
  ON public.transactions FOR DELETE
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
    AND NOT public.contact_ledger_is_user_archived(contact_id)
  );

-- contact_balances
DROP POLICY IF EXISTS contact_balances_select ON public.contact_balances;
DROP POLICY IF EXISTS contact_balances_write_editor ON public.contact_balances;
DROP POLICY IF EXISTS contact_balances_update_editor ON public.contact_balances;
DROP POLICY IF EXISTS contact_balances_all_owner ON public.contact_balances;

CREATE POLICY contact_balances_select
  ON public.contact_balances FOR SELECT
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('viewer', 'editor', 'owner')
  );

CREATE POLICY contact_balances_insert_writer
  ON public.contact_balances FOR INSERT
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
  );

CREATE POLICY contact_balances_update_writer
  ON public.contact_balances FOR UPDATE
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
  )
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
  );

CREATE POLICY contact_balances_delete_writer
  ON public.contact_balances FOR DELETE
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
  );

-- audit_logs
DROP POLICY IF EXISTS audit_logs_select ON public.audit_logs;
DROP POLICY IF EXISTS audit_logs_insert_editor ON public.audit_logs;

CREATE POLICY audit_logs_select
  ON public.audit_logs FOR SELECT
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('viewer', 'editor', 'owner')
  );

CREATE POLICY audit_logs_insert_writer
  ON public.audit_logs FOR INSERT
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
  );

-- shared_accounts (merchant path; B2C slice policies remain Stage 11)
DROP POLICY IF EXISTS shared_accounts_select_member ON public.shared_accounts;
DROP POLICY IF EXISTS shared_accounts_write_editor ON public.shared_accounts;
DROP POLICY IF EXISTS shared_accounts_update_editor ON public.shared_accounts;
DROP POLICY IF EXISTS shared_accounts_all_owner ON public.shared_accounts;
-- Keep shared_accounts_select_b2c_viewer

CREATE POLICY shared_accounts_select_member
  ON public.shared_accounts FOR SELECT
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('viewer', 'editor', 'owner')
  );

CREATE POLICY shared_accounts_insert_writer
  ON public.shared_accounts FOR INSERT
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
  );

CREATE POLICY shared_accounts_update_writer
  ON public.shared_accounts FOR UPDATE
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
  )
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('editor', 'owner')
  );

CREATE POLICY shared_accounts_delete_owner
  ON public.shared_accounts FOR DELETE
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('owner')
  );


-- ────────────────────────────────────────────────────────────────────────────
-- §7  Audit log partitions (extend through 2028-08) + DEFAULT safety net
-- ────────────────────────────────────────────────────────────────────────────

-- Existing partitions cover 2026-07 .. 2027-06. Add 2027-07 .. 2028-08.
CREATE TABLE IF NOT EXISTS public.audit_logs_y2027m07 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');
CREATE TABLE IF NOT EXISTS public.audit_logs_y2027m08 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2027-08-01') TO ('2027-09-01');
CREATE TABLE IF NOT EXISTS public.audit_logs_y2027m09 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2027-09-01') TO ('2027-10-01');
CREATE TABLE IF NOT EXISTS public.audit_logs_y2027m10 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2027-10-01') TO ('2027-11-01');
CREATE TABLE IF NOT EXISTS public.audit_logs_y2027m11 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2027-11-01') TO ('2027-12-01');
CREATE TABLE IF NOT EXISTS public.audit_logs_y2027m12 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2027-12-01') TO ('2028-01-01');
CREATE TABLE IF NOT EXISTS public.audit_logs_y2028m01 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2028-01-01') TO ('2028-02-01');
CREATE TABLE IF NOT EXISTS public.audit_logs_y2028m02 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2028-02-01') TO ('2028-03-01');
CREATE TABLE IF NOT EXISTS public.audit_logs_y2028m03 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2028-03-01') TO ('2028-04-01');
CREATE TABLE IF NOT EXISTS public.audit_logs_y2028m04 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2028-04-01') TO ('2028-05-01');
CREATE TABLE IF NOT EXISTS public.audit_logs_y2028m05 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2028-05-01') TO ('2028-06-01');
CREATE TABLE IF NOT EXISTS public.audit_logs_y2028m06 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2028-06-01') TO ('2028-07-01');
CREATE TABLE IF NOT EXISTS public.audit_logs_y2028m07 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2028-07-01') TO ('2028-08-01');
CREATE TABLE IF NOT EXISTS public.audit_logs_y2028m08 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2028-08-01') TO ('2028-09-01');

-- Catch-all for dates outside maintained monthly ranges (ops must still add months).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'audit_logs_default'
  ) THEN
    CREATE TABLE public.audit_logs_default PARTITION OF public.audit_logs DEFAULT;
  END IF;
END $$;
