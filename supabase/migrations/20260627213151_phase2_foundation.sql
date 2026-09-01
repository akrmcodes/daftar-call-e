-- ============================================================================
-- MIGRATION: Phase 2 Foundation — Zero-MAU Custom JWT Architecture
-- ============================================================================
-- File:    20260627213151_phase2_foundation.sql
-- Stage:   8.2 — Supabase Project, Schema & RLS (COMPREHENSIVE)
-- Author:  CTO / AI (June–July 2026)
--
-- ARCHITECTURE NOTES:
--   • Supabase Auth is NOT used. auth.uid() IS MEANINGLESS in this project.
--   • Identity = Google Sign-In → Edge Function verifies → custom sync JWT
--     carrying { workspace_id, role, identity_hash }.
--   • All RLS policies extract claims from:
--       current_setting('request.jwt.claims', true)::json
--   • End users are NEVER Supabase MAUs → $0 MAU billing.
--   • Tenant key = workspace_id (not Google account ID).
--   • Ownership is a re-keyable TEXT pointer, enabling account transfers.
--
-- SECURITY POSTURE:
--   • RLS enabled on EVERY table before any data insert.
--   • Zero-Trust: deny by default; grant only via claim-matched policies.
--   • Seat cap (Owner + 2 Workers) enforced at DB level, not app logic.
--   • All monetary amounts are INT/BIGINT (smallest currency unit).
--   • Archival defense-in-depth: writers CANNOT mutate data under
--     is_user_archived = true ledgers (RLS WITH CHECK).
--
-- TABLES (16):
--   §2  workspaces              §9   contact_balances
--   §3  workspace_members       §10  audit_logs (time-partitioned)
--   §4  migration_challenges    §11  shared_accounts
--   §5  rate_limit_buckets      §12  deep_link_tokens
--   §6  ledgers                 §13  archived_shared_ledger
--   §7  contacts                §14  promo_codes + promo_redemptions
--   §8  transactions            §15  referrals
--                               §16  ai_usage_counters
--
-- DEPENDENCIES: None (first migration).
-- ============================================================================


-- ============================================================================
-- §0  HELPER: Automatic updated_at trigger function
-- ============================================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.set_updated_at()
  IS 'Trigger function: stamps updated_at = now() on every UPDATE. Phase 2 foundation.';


-- ============================================================================
-- §1  HELPER: JWT claim extraction functions (Zero-MAU architecture)
-- ============================================================================
-- Encapsulate claim parsing so RLS policies are readable and auditable.
-- current_setting('request.jwt.claims', true) returns NULL if the GUC is unset
-- (e.g., during migrations or direct DB access), which makes these functions
-- return NULL → all RLS policies fail-closed (deny).

CREATE OR REPLACE FUNCTION public.jwt_workspace_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT (
    current_setting('request.jwt.claims', true)::json ->> 'workspace_id'
  )::uuid;
$$;

COMMENT ON FUNCTION public.jwt_workspace_id()
  IS 'Extracts workspace_id (UUID) from the custom sync JWT claims. Returns NULL if no JWT → fail-closed.';


CREATE OR REPLACE FUNCTION public.jwt_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT current_setting('request.jwt.claims', true)::json ->> 'role';
$$;

COMMENT ON FUNCTION public.jwt_role()
  IS 'Extracts role (owner/editor/viewer) from the custom sync JWT claims. Returns NULL if no JWT → fail-closed.';


CREATE OR REPLACE FUNCTION public.jwt_identity_hash()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT current_setting('request.jwt.claims', true)::json ->> 'identity_hash';
$$;

COMMENT ON FUNCTION public.jwt_identity_hash()
  IS 'Extracts identity_hash from the custom sync JWT claims. Used for identity-scoped operations.';


-- ============================================================================
-- §1b  HELPER: Global op_seq sequence (Merge Engine ordering authority)
-- ============================================================================
-- Server assigns a monotonic op_seq on receipt of sync pushes.
-- Total ordering across all workspaces. Edge Functions call nextval().

CREATE SEQUENCE public.global_op_seq AS BIGINT START 1 INCREMENT 1 NO CYCLE;

COMMENT ON SEQUENCE public.global_op_seq
  IS 'Monotonic sequence for Merge Engine op ordering. Edge Functions assign via nextval(). Phase 2.';


-- ============================================================================
-- §2  TABLE: workspaces
-- ============================================================================
-- The fundamental tenant container. owner_identity is a re-keyable TEXT pointer
-- (not an FK to auth.users — Supabase Auth is disabled). This is what makes
-- account-ownership transfer (§8.1) possible: re-key the pointer, not the data.

CREATE TABLE public.workspaces (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_identity   TEXT        NOT NULL,
  status           TEXT        NOT NULL DEFAULT 'active'
                               CHECK (status IN ('active', 'suspended', 'deleted')),
  soft_deleted_at  TIMESTAMPTZ,
  purge_after      TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.workspaces
  ADD CONSTRAINT chk_workspaces_soft_delete_coherence
  CHECK (
    (status = 'deleted' AND soft_deleted_at IS NOT NULL)
    OR
    (status != 'deleted' AND soft_deleted_at IS NULL AND purge_after IS NULL)
  );

CREATE INDEX idx_workspaces_owner_identity ON public.workspaces (owner_identity);

CREATE TRIGGER trg_workspaces_updated_at
  BEFORE UPDATE ON public.workspaces
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

COMMENT ON TABLE public.workspaces
  IS 'Tenant container. owner_identity is a re-keyable pointer — not an FK to auth.users. Phase 2.';
COMMENT ON COLUMN public.workspaces.owner_identity
  IS 'Re-keyable identity pointer (NOT an FK to auth.users). Enables account-ownership transfer.';
COMMENT ON COLUMN public.workspaces.status
  IS 'Workspace lifecycle: active → suspended → deleted. Soft-delete with purge window.';
COMMENT ON COLUMN public.workspaces.purge_after
  IS 'TIMESTAMPTZ after which a deleted workspace may be permanently purged.';


-- ============================================================================
-- §3  TABLE: workspace_members
-- ============================================================================
-- FINANCIAL GATE: seat_index ∈ {0, 1, 2} per workspace enforces
-- "Owner + 2 Workers" hard cap at the database level.

CREATE TABLE public.workspace_members (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id    UUID        NOT NULL
                              REFERENCES public.workspaces (id) ON DELETE CASCADE,
  invited_email   TEXT,
  role            TEXT        NOT NULL
                              CHECK (role IN ('owner', 'editor', 'viewer')),
  status          TEXT        NOT NULL DEFAULT 'pending'
                              CHECK (status IN ('pending', 'active')),
  seat_index      INT         NOT NULL
                              CHECK (seat_index BETWEEN 0 AND 2),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.workspace_members
  ADD CONSTRAINT uq_workspace_members_seat
  UNIQUE (workspace_id, seat_index);

ALTER TABLE public.workspace_members
  ADD CONSTRAINT chk_workspace_members_owner_seat
  CHECK (
    (role = 'owner' AND seat_index = 0)
    OR
    (role != 'owner' AND seat_index > 0)
  );

CREATE INDEX idx_workspace_members_workspace_id ON public.workspace_members (workspace_id);
CREATE INDEX idx_workspace_members_invited_email ON public.workspace_members (invited_email)
  WHERE invited_email IS NOT NULL;

CREATE TRIGGER trg_workspace_members_updated_at
  BEFORE UPDATE ON public.workspace_members
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

COMMENT ON TABLE public.workspace_members
  IS 'Workspace membership. Seat cap (0-2) enforced at DB level → Owner + 2 Workers max.';
COMMENT ON COLUMN public.workspace_members.seat_index
  IS 'Seat 0 = owner. Seats 1-2 = workers. UNIQUE per workspace enforces hard cap.';
COMMENT ON COLUMN public.workspace_members.role
  IS 'Access tier: owner (full), editor (read+write), viewer (read-only). Enforced by RLS.';


-- ============================================================================
-- §4  TABLE: migration_challenges (Stage 8.1 Handshake)
-- ============================================================================
-- Single-use, short-TTL ownership-transfer challenges.
-- Three-factor verification: control of new identity, re-auth of old identity,
-- out-of-band email confirmation code.

CREATE TABLE public.migration_challenges (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  old_identity_hash   TEXT        NOT NULL,
  new_identity_id     TEXT        NOT NULL,
  nonce               TEXT,
  factor_1_verified   BOOLEAN     NOT NULL DEFAULT false,
  factor_2_verified   BOOLEAN     NOT NULL DEFAULT false,
  factor_3_verified   BOOLEAN     NOT NULL DEFAULT false,
  expires_at          TIMESTAMPTZ NOT NULL,
  reversal_token      TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT chk_migration_challenge_expiry
    CHECK (expires_at > created_at)
);

-- FIXED: Removed `WHERE expires_at > now()` partial-index predicate.
-- now() is STABLE, not IMMUTABLE — PostgreSQL rejects non-IMMUTABLE functions
-- in index predicates (SQLSTATE 42P17). Edge Function queries add the time
-- filter at query time; the composite B-tree still provides efficient scans.
CREATE INDEX idx_migration_challenges_lookup
  ON public.migration_challenges (old_identity_hash, new_identity_id, expires_at);

CREATE INDEX idx_migration_challenges_expires
  ON public.migration_challenges (expires_at)
  WHERE reversal_token IS NULL;

COMMENT ON TABLE public.migration_challenges
  IS 'Single-use, 3-factor ownership-transfer handshake tokens. Stage 8.1.';
COMMENT ON COLUMN public.migration_challenges.old_identity_hash
  IS 'SHA-256 hash of the old Google identity. Anti-enumeration: never the raw email.';
COMMENT ON COLUMN public.migration_challenges.reversal_token
  IS 'Single-use token emailed to Account A after transfer. Valid for N-day cooling-off window.';


-- ============================================================================
-- §5  TABLE: rate_limit_buckets (Stage 8.7 Circuit Breaker)
-- ============================================================================
-- Token-bucket rate limiter. Edge Function–only.

CREATE TABLE public.rate_limit_buckets (
  bucket_key   TEXT        PRIMARY KEY,
  tokens       FLOAT       NOT NULL DEFAULT 0,
  last_refill  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.rate_limit_buckets
  IS 'Token-bucket rate limiter keyed by dimension. Stage 8.7 circuit breaker. Edge Function–only.';
COMMENT ON COLUMN public.rate_limit_buckets.bucket_key
  IS 'Composite key: "identity:<hash>" | "ip:<addr>" | "email:<dest>" | "domain:<d>" | "global".';


-- ============================================================================
-- §6  TABLE: ledgers (Drift mirror + sync fields)
-- ============================================================================
-- Mirrors the local Drift Ledgers table with server-side sync fields.
-- Includes is_user_archived (Stage 6.7) and carry_forward_target_ledger_id.
-- PK is TEXT (UUID v4 string) matching the Drift convention.

CREATE TABLE public.ledgers (
  id                              TEXT        PRIMARY KEY,
  workspace_id                    UUID        NOT NULL
                                              REFERENCES public.workspaces (id) ON DELETE CASCADE,
  name                            TEXT        NOT NULL,
  type                            TEXT        NOT NULL,
  icon                            TEXT        NOT NULL,
  color                           TEXT        NOT NULL,
  sort_order                      INT         NOT NULL,
  is_deleted                      BOOLEAN     NOT NULL DEFAULT false,
  is_archived                     BOOLEAN     NOT NULL DEFAULT false,
  is_user_archived                BOOLEAN     NOT NULL DEFAULT false,
  carry_forward_target_ledger_id  TEXT        REFERENCES public.ledgers (id),
  sync_version                    INT         NOT NULL DEFAULT 0,
  created_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- Server-side sync fields (assigned by Edge Functions)
  server_updated_at               TIMESTAMPTZ,
  op_seq                          BIGINT,
  deleted_at                      TIMESTAMPTZ
);

CREATE INDEX idx_ledgers_workspace       ON public.ledgers (workspace_id);
CREATE INDEX idx_ledgers_deleted         ON public.ledgers (is_deleted);
CREATE INDEX idx_ledgers_user_archived   ON public.ledgers (is_user_archived);
CREATE INDEX idx_ledgers_workspace_active ON public.ledgers (workspace_id, is_deleted, is_archived, is_user_archived, sort_order);

CREATE TRIGGER trg_ledgers_updated_at
  BEFORE UPDATE ON public.ledgers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

COMMENT ON TABLE public.ledgers
  IS 'Drift-mirror ledgers with server sync fields. is_user_archived enforced by RLS defense-in-depth.';
COMMENT ON COLUMN public.ledgers.is_user_archived
  IS 'Stage 6.7: archived ledgers are read-only. Writers CANNOT mutate child contacts/transactions (RLS enforced).';
COMMENT ON COLUMN public.ledgers.carry_forward_target_ledger_id
  IS 'Self-referencing FK for fiscal carry-forward. Rollover ops are ordinary CREATEs.';


-- ============================================================================
-- §7  TABLE: contacts (Drift mirror + sync fields)
-- ============================================================================

CREATE TABLE public.contacts (
  id               TEXT        PRIMARY KEY,
  workspace_id     UUID        NOT NULL
                               REFERENCES public.workspaces (id) ON DELETE CASCADE,
  ledger_id        TEXT        NOT NULL
                               REFERENCES public.ledgers (id),
  name             TEXT        NOT NULL,
  phone            TEXT,
  notes            TEXT,
  credit_limit     INT,
  credit_currency  TEXT,
  avatar_color     TEXT        NOT NULL,
  is_deleted       BOOLEAN     NOT NULL DEFAULT false,
  is_archived      BOOLEAN     NOT NULL DEFAULT false,
  sync_version     INT         NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- Server-side sync fields
  server_updated_at TIMESTAMPTZ,
  op_seq            BIGINT,
  deleted_at        TIMESTAMPTZ
);

CREATE INDEX idx_contacts_workspace     ON public.contacts (workspace_id);
CREATE INDEX idx_contacts_ledger        ON public.contacts (ledger_id);
CREATE INDEX idx_contacts_name          ON public.contacts (name);
CREATE INDEX idx_contacts_workspace_active ON public.contacts (workspace_id, ledger_id, is_deleted, is_archived, name);

CREATE TRIGGER trg_contacts_updated_at
  BEFORE UPDATE ON public.contacts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

COMMENT ON TABLE public.contacts
  IS 'Drift-mirror contacts with server sync fields. Workspace-scoped via RLS.';


-- ============================================================================
-- §8  TABLE: transactions (Drift mirror + sync fields)
-- ============================================================================
-- amount is BIGINT — smallest currency unit. NEVER double/decimal.

CREATE TABLE public.transactions (
  id                TEXT        PRIMARY KEY,
  workspace_id      UUID        NOT NULL
                                REFERENCES public.workspaces (id) ON DELETE CASCADE,
  contact_id        TEXT        NOT NULL
                                REFERENCES public.contacts (id),
  type              TEXT        NOT NULL,
  amount            BIGINT      NOT NULL CHECK (amount > 0),
  currency          TEXT        NOT NULL,
  description       TEXT,
  item_name         TEXT,
  transaction_date  TIMESTAMPTZ NOT NULL,
  attachment_path   TEXT,
  is_deleted        BOOLEAN     NOT NULL DEFAULT false,
  is_archived       BOOLEAN     NOT NULL DEFAULT false,
  sync_version      INT         NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- Server-side sync fields
  server_updated_at TIMESTAMPTZ,
  op_seq            BIGINT,
  deleted_at        TIMESTAMPTZ
);

CREATE INDEX idx_txn_workspace       ON public.transactions (workspace_id);
CREATE INDEX idx_txn_contact         ON public.transactions (contact_id);
CREATE INDEX idx_txn_date            ON public.transactions (transaction_date);
CREATE INDEX idx_txn_workspace_active ON public.transactions (workspace_id, contact_id, is_deleted, is_archived, transaction_date);

CREATE TRIGGER trg_transactions_updated_at
  BEFORE UPDATE ON public.transactions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

COMMENT ON TABLE public.transactions
  IS 'Drift-mirror transactions. amount is BIGINT (smallest currency unit). NEVER double.';
COMMENT ON COLUMN public.transactions.amount
  IS 'Always positive integer in smallest currency unit. 1500 = 15.00 YER (2dp). NEVER double.';


-- ============================================================================
-- §9  TABLE: contact_balances (Drift mirror — derived data)
-- ============================================================================
-- Denormalized balances. No op_seq/server_updated_at — derived from transactions.
-- Recalculated atomically after every merge. Composite PK matches Drift.

CREATE TABLE public.contact_balances (
  contact_id    TEXT        NOT NULL
                            REFERENCES public.contacts (id),
  currency_code TEXT        NOT NULL,
  workspace_id  UUID        NOT NULL
                            REFERENCES public.workspaces (id) ON DELETE CASCADE,
  total_debt    BIGINT      NOT NULL DEFAULT 0,
  total_payment BIGINT      NOT NULL DEFAULT 0,
  net_balance   BIGINT      NOT NULL DEFAULT 0,
  last_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  PRIMARY KEY (contact_id, currency_code)
);

CREATE INDEX idx_contact_balances_workspace ON public.contact_balances (workspace_id);

COMMENT ON TABLE public.contact_balances
  IS 'Denormalized balances — derived from transactions. Recalculated after every merge, never trusted as transported.';
COMMENT ON COLUMN public.contact_balances.net_balance
  IS 'total_payment - total_debt. All values in BIGINT smallest currency unit.';


-- ============================================================================
-- §10  TABLE: audit_logs (Drift mirror — time-partitioned by month)
-- ============================================================================
-- Immutable, append-only op-log. Source of truth for sync replay.
-- PostgreSQL declarative partitioning by RANGE on logged_at (monthly).
-- PK must include partition key → (id, logged_at).

CREATE TABLE public.audit_logs (
  id                TEXT        NOT NULL,
  workspace_id      UUID        NOT NULL,
  entity_type       TEXT        NOT NULL,
  entity_id         TEXT        NOT NULL,
  action            TEXT        NOT NULL
                                CHECK (action IN ('CREATE', 'UPDATE', 'DELETE')),
  payload           JSONB,
  logged_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  device_id         TEXT        NOT NULL,
  -- Server-side sync fields
  server_updated_at TIMESTAMPTZ,
  op_seq            BIGINT,

  PRIMARY KEY (id, logged_at)
) PARTITION BY RANGE (logged_at);

-- Indexes on the parent table propagate to all partitions
CREATE INDEX idx_audit_workspace        ON public.audit_logs (workspace_id);
CREATE INDEX idx_audit_entity           ON public.audit_logs (entity_type, entity_id);
CREATE INDEX idx_audit_logged_at        ON public.audit_logs (logged_at);
CREATE INDEX idx_audit_op_seq           ON public.audit_logs (op_seq) WHERE op_seq IS NOT NULL;
CREATE INDEX idx_audit_workspace_entity ON public.audit_logs (workspace_id, entity_type, entity_id, logged_at);

-- Monthly partitions: 2026-07 through 2027-06 (12 months)
-- IMPORTANT: A scheduled job or migration must create future partitions
-- before their month begins. INSERT into a non-existent partition FAILS.
CREATE TABLE public.audit_logs_y2026m07 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE public.audit_logs_y2026m08 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE public.audit_logs_y2026m09 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE public.audit_logs_y2026m10 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE public.audit_logs_y2026m11 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE public.audit_logs_y2026m12 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE public.audit_logs_y2027m01 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2027-01-01') TO ('2027-02-01');
CREATE TABLE public.audit_logs_y2027m02 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2027-02-01') TO ('2027-03-01');
CREATE TABLE public.audit_logs_y2027m03 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2027-03-01') TO ('2027-04-01');
CREATE TABLE public.audit_logs_y2027m04 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2027-04-01') TO ('2027-05-01');
CREATE TABLE public.audit_logs_y2027m05 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2027-05-01') TO ('2027-06-01');
CREATE TABLE public.audit_logs_y2027m06 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2027-06-01') TO ('2027-07-01');

COMMENT ON TABLE public.audit_logs
  IS 'Immutable, append-only op-log. Time-partitioned by month. Source of truth for sync replay.';
COMMENT ON COLUMN public.audit_logs.payload
  IS 'JSONB field deltas. For carry-forward ops, includes carryForwardOperationId for server-side tracing.';
COMMENT ON COLUMN public.audit_logs.op_seq
  IS 'Monotonic sequence assigned by server on sync push. Clients order by this, not device clocks.';


-- ============================================================================
-- §11  TABLE: shared_accounts (Stage 11 — B2C Customer Sharing)
-- ============================================================================
-- Host workspace → contact → claim token → viewer device binding.
-- B2C viewers access their bound slice via this table, never the workspace.
-- Sharing cap (Free 0 / Pro 30 / Pro+ 500) enforced by Edge Functions
-- (tier information lives in entitlements, not in the DB).

CREATE TABLE public.shared_accounts (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id      UUID        NOT NULL
                                REFERENCES public.workspaces (id) ON DELETE CASCADE,
  contact_id        TEXT        NOT NULL
                                REFERENCES public.contacts (id),
  claim_token       TEXT        UNIQUE NOT NULL,
  viewer_device_id  TEXT,
  viewer_identity   TEXT,
  state             TEXT        NOT NULL DEFAULT 'active'
                                CHECK (state IN ('active', 'claimed', 'revoked')),
  revoked_at        TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.shared_accounts
  ADD CONSTRAINT chk_shared_accounts_revoke_coherence
  CHECK (
    (state = 'revoked' AND revoked_at IS NOT NULL)
    OR
    (state != 'revoked' AND revoked_at IS NULL)
  );

CREATE INDEX idx_shared_accounts_workspace ON public.shared_accounts (workspace_id);
CREATE INDEX idx_shared_accounts_contact   ON public.shared_accounts (contact_id);
CREATE INDEX idx_shared_accounts_viewer    ON public.shared_accounts (viewer_identity)
  WHERE viewer_identity IS NOT NULL;
CREATE INDEX idx_shared_accounts_claim     ON public.shared_accounts (claim_token)
  WHERE state = 'active';

CREATE TRIGGER trg_shared_accounts_updated_at
  BEFORE UPDATE ON public.shared_accounts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

COMMENT ON TABLE public.shared_accounts
  IS 'B2C customer sharing binding. Viewers get SELECT-only on their bound slice. Stage 11.';
COMMENT ON COLUMN public.shared_accounts.claim_token
  IS 'Opaque token for B2C viewer to claim their shared account view. Single-use.';
COMMENT ON COLUMN public.shared_accounts.state
  IS 'active → claimed (device bound) → revoked. Revoking frees a sharing slot.';


-- ============================================================================
-- §12  TABLE: deep_link_tokens (Stages 11 & 14 — Deep-Link & Attribution)
-- ============================================================================
-- Opaque tokens with intent payload, kind, TTL lifecycle, and state machine.

CREATE TABLE public.deep_link_tokens (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  token             TEXT        UNIQUE NOT NULL,
  workspace_id      UUID        REFERENCES public.workspaces (id) ON DELETE SET NULL,
  kind              TEXT        NOT NULL
                                CHECK (kind IN ('share', 'referral', 'worker_invite')),
  intent_payload    JSONB,
  ttl_expires_at    TIMESTAMPTZ NOT NULL,
  state             TEXT        NOT NULL DEFAULT 'active'
                                CHECK (state IN ('active', 'claimed', 'expired', 'revoked', 'superseded')),
  claimed_at        TIMESTAMPTZ,
  claimed_by_identity TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_deep_link_token_lookup ON public.deep_link_tokens (token) WHERE state = 'active';
CREATE INDEX idx_deep_link_workspace    ON public.deep_link_tokens (workspace_id)
  WHERE workspace_id IS NOT NULL;
CREATE INDEX idx_deep_link_expires      ON public.deep_link_tokens (ttl_expires_at)
  WHERE state = 'active';

COMMENT ON TABLE public.deep_link_tokens
  IS 'Opaque deep-link tokens with TTL lifecycle. Shared foundation for share/referral/invite flows.';
COMMENT ON COLUMN public.deep_link_tokens.state
  IS 'active → claimed/expired/revoked/superseded. Full TTL lifecycle per §8.6.';


-- ============================================================================
-- §13  TABLE: archived_shared_ledger (Stage 8.8 — Immutable Receipts)
-- ============================================================================
-- Decoupled, frozen, read-only customer snapshots that SURVIVE workspace
-- deletion. No FK to workspaces (intentional — must outlive merchant).
-- INSERT-only via Edge Functions. No UPDATE/DELETE ever.

CREATE TABLE public.archived_shared_ledger (
  id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id_origin   TEXT        NOT NULL,
  contact_id_origin     TEXT        NOT NULL,
  contact_name          TEXT        NOT NULL,
  ledger_name           TEXT        NOT NULL,
  currency              TEXT        NOT NULL,
  snapshot_data         JSONB       NOT NULL,
  archived_by_identity  TEXT        NOT NULL,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Viewers look up by their shared_account binding → contact_id_origin
CREATE INDEX idx_archived_shared_contact ON public.archived_shared_ledger (contact_id_origin);
CREATE INDEX idx_archived_shared_origin  ON public.archived_shared_ledger (workspace_id_origin);

COMMENT ON TABLE public.archived_shared_ledger
  IS 'Immutable customer receipt snapshots. No FK to workspaces — survives deletion. INSERT-only. Stage 8.8.';
COMMENT ON COLUMN public.archived_shared_ledger.snapshot_data
  IS 'JSONB: frozen transactions + balances at archive time. Regulatory-grade immutability.';
COMMENT ON COLUMN public.archived_shared_ledger.workspace_id_origin
  IS 'TEXT (not FK): traces origin workspace. Deliberately survives workspace CASCADE DELETE.';


-- ============================================================================
-- §14  TABLE: promo_codes + promo_redemptions (Stage 13)
-- ============================================================================
-- Single-use, atomic promo system. Edge Function–only.

CREATE TABLE public.promo_codes (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  code                TEXT        UNIQUE NOT NULL,
  description         TEXT,
  discount_type       TEXT        NOT NULL
                                  CHECK (discount_type IN ('percentage', 'fixed', 'trial_extension')),
  discount_value      INT         NOT NULL CHECK (discount_value > 0),
  max_redemptions     INT         NOT NULL DEFAULT 1,
  current_redemptions INT         NOT NULL DEFAULT 0,
  valid_from          TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_until         TIMESTAMPTZ,
  is_active           BOOLEAN     NOT NULL DEFAULT true,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.promo_codes
  ADD CONSTRAINT chk_promo_codes_redemption_cap
  CHECK (current_redemptions <= max_redemptions);

COMMENT ON TABLE public.promo_codes
  IS 'Promotional codes. Edge Function–only. Single-use per identity enforced by promo_redemptions.';

CREATE TABLE public.promo_redemptions (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  promo_code_id   UUID        NOT NULL
                              REFERENCES public.promo_codes (id),
  identity_hash   TEXT        NOT NULL,
  workspace_id    UUID        NOT NULL
                              REFERENCES public.workspaces (id) ON DELETE CASCADE,
  redeemed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Single-use per identity per promo code
  CONSTRAINT uq_promo_redemption_identity UNIQUE (promo_code_id, identity_hash)
);

CREATE INDEX idx_promo_redemptions_workspace ON public.promo_redemptions (workspace_id);

COMMENT ON TABLE public.promo_redemptions
  IS 'Atomic promo redemption ledger. UNIQUE(promo_code_id, identity_hash) enforces single-use.';


-- ============================================================================
-- §15  TABLE: referrals (Stage 14)
-- ============================================================================

CREATE TABLE public.referrals (
  id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_identity_hash  TEXT        NOT NULL,
  referee_identity_hash   TEXT,
  referral_code           TEXT        UNIQUE NOT NULL,
  install_verified        BOOLEAN     NOT NULL DEFAULT false,
  register_verified       BOOLEAN     NOT NULL DEFAULT false,
  reward_state            TEXT        NOT NULL DEFAULT 'pending'
                                      CHECK (reward_state IN ('pending', 'granted', 'expired', 'revoked')),
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_referrals_referrer ON public.referrals (referrer_identity_hash);
CREATE INDEX idx_referrals_referee  ON public.referrals (referee_identity_hash)
  WHERE referee_identity_hash IS NOT NULL;

CREATE TRIGGER trg_referrals_updated_at
  BEFORE UPDATE ON public.referrals
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

COMMENT ON TABLE public.referrals
  IS 'Referral tracking with install/register verification gates and reward state machine. Stage 14.';


-- ============================================================================
-- §16  TABLE: ai_usage_counters (Stage 10 — Voice AI Quotas)
-- ============================================================================
-- Per identity per month. Composite PK. Edge Function–managed.

CREATE TABLE public.ai_usage_counters (
  identity_hash       TEXT        NOT NULL,
  usage_month         TEXT        NOT NULL,
  voice_count         INT         NOT NULL DEFAULT 0,
  cloud_call_count    INT         NOT NULL DEFAULT 0,
  spend_estimate_cents INT        NOT NULL DEFAULT 0,
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  PRIMARY KEY (identity_hash, usage_month)
);

COMMENT ON TABLE public.ai_usage_counters
  IS 'Per-identity monthly AI usage counters. Edge Function–only. Stage 10 Voice AI quotas.';
COMMENT ON COLUMN public.ai_usage_counters.usage_month
  IS 'YYYY-MM format. Part of composite PK.';
COMMENT ON COLUMN public.ai_usage_counters.spend_estimate_cents
  IS 'Estimated spend in USD cents. INT — smallest unit. NEVER double.';


-- ============================================================================
-- §17  ROW LEVEL SECURITY — ZERO TRUST
-- ============================================================================
-- CRITICAL SECURITY ARCHITECTURE:
--   • auth.uid() is NEVER used. It is meaningless in this project.
--   • All policies extract workspace_id and role from the custom sync JWT.
--   • Helper functions jwt_workspace_id(), jwt_role() return NULL when no
--     JWT is present → all policies fail-closed (deny).
--   • Default posture: DENY ALL. Each policy is an explicit allow-list.
-- ============================================================================

-- ── Enable RLS on ALL tables ────────────────────────────────────────────────

ALTER TABLE public.workspaces              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_members       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.migration_challenges    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rate_limit_buckets      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledgers                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contacts                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_balances        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shared_accounts         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deep_link_tokens        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.archived_shared_ledger  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promo_codes             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promo_redemptions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_usage_counters       ENABLE ROW LEVEL SECURITY;

-- Force RLS on client-facing tables (defense-in-depth — even table owner is subject)
ALTER TABLE public.workspaces              FORCE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_members       FORCE ROW LEVEL SECURITY;
ALTER TABLE public.ledgers                 FORCE ROW LEVEL SECURITY;
ALTER TABLE public.contacts                FORCE ROW LEVEL SECURITY;
ALTER TABLE public.transactions            FORCE ROW LEVEL SECURITY;
ALTER TABLE public.contact_balances        FORCE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs              FORCE ROW LEVEL SECURITY;
ALTER TABLE public.shared_accounts         FORCE ROW LEVEL SECURITY;
-- NOTE: Edge Function–only tables are NOT forced.
-- service_role must bypass RLS on: migration_challenges, rate_limit_buckets,
-- deep_link_tokens, archived_shared_ledger, promo_codes, promo_redemptions,
-- referrals, ai_usage_counters.


-- ── workspaces ──────────────────────────────────────────────────────────────

CREATE POLICY workspaces_select
  ON public.workspaces FOR SELECT
  USING (
    id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('viewer', 'editor', 'owner')
  );

CREATE POLICY workspaces_update_editor
  ON public.workspaces FOR UPDATE
  USING (
    id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
  )
  WITH CHECK (
    id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
    -- Editors cannot change owner_identity or status
    AND owner_identity = (SELECT w.owner_identity FROM public.workspaces w WHERE w.id = id)
    AND status = (SELECT w.status FROM public.workspaces w WHERE w.id = id)
  );

CREATE POLICY workspaces_all_owner
  ON public.workspaces FOR ALL
  USING (
    id = public.jwt_workspace_id()
    AND public.jwt_role() = 'owner'
  )
  WITH CHECK (
    id = public.jwt_workspace_id()
    AND public.jwt_role() = 'owner'
  );


-- ── workspace_members ───────────────────────────────────────────────────────

CREATE POLICY workspace_members_select
  ON public.workspace_members FOR SELECT
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('viewer', 'editor', 'owner')
  );

CREATE POLICY workspace_members_insert_editor
  ON public.workspace_members FOR INSERT
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
  );

CREATE POLICY workspace_members_update_editor
  ON public.workspace_members FOR UPDATE
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
  )
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
  );

CREATE POLICY workspace_members_all_owner
  ON public.workspace_members FOR ALL
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() = 'owner'
  )
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() = 'owner'
  );


-- ── ledgers ─────────────────────────────────────────────────────────────────

CREATE POLICY ledgers_select
  ON public.ledgers FOR SELECT
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('viewer', 'editor', 'owner')
  );

CREATE POLICY ledgers_insert_editor
  ON public.ledgers FOR INSERT
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
  );

-- Editors can UPDATE but CANNOT toggle is_user_archived (owner-only).
CREATE POLICY ledgers_update_editor
  ON public.ledgers FOR UPDATE
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
  )
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
    -- Editor guard: is_user_archived must not change (subquery reads current value)
    AND (
      public.jwt_role() = 'owner'
      OR is_user_archived = (SELECT l.is_user_archived FROM public.ledgers l WHERE l.id = id)
    )
  );

CREATE POLICY ledgers_all_owner
  ON public.ledgers FOR ALL
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() = 'owner'
  )
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() = 'owner'
  );


-- ── contacts ────────────────────────────────────────────────────────────────
-- Defense-in-depth: writers CANNOT mutate contacts under user-archived ledgers.

CREATE POLICY contacts_select
  ON public.contacts FOR SELECT
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('viewer', 'editor', 'owner')
  );

CREATE POLICY contacts_insert_editor
  ON public.contacts FOR INSERT
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
    -- Archival lock: cannot insert into a user-archived ledger
    AND NOT EXISTS (
      SELECT 1 FROM public.ledgers l
      WHERE l.id = ledger_id AND l.is_user_archived = true
    )
  );

CREATE POLICY contacts_update_editor
  ON public.contacts FOR UPDATE
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
  )
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
    -- Archival lock: cannot mutate contacts under a user-archived ledger
    AND NOT EXISTS (
      SELECT 1 FROM public.ledgers l
      WHERE l.id = ledger_id AND l.is_user_archived = true
    )
  );

CREATE POLICY contacts_all_owner
  ON public.contacts FOR ALL
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() = 'owner'
  )
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() = 'owner'
  );


-- ── transactions ────────────────────────────────────────────────────────────
-- Defense-in-depth: writers CANNOT mutate transactions under user-archived ledgers.

CREATE POLICY transactions_select
  ON public.transactions FOR SELECT
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('viewer', 'editor', 'owner')
  );

CREATE POLICY transactions_insert_editor
  ON public.transactions FOR INSERT
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
    -- Archival lock: cannot insert into a contact under a user-archived ledger
    AND NOT EXISTS (
      SELECT 1 FROM public.contacts c
      JOIN public.ledgers l ON l.id = c.ledger_id
      WHERE c.id = contact_id AND l.is_user_archived = true
    )
  );

CREATE POLICY transactions_update_editor
  ON public.transactions FOR UPDATE
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
  )
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
    -- Archival lock
    AND NOT EXISTS (
      SELECT 1 FROM public.contacts c
      JOIN public.ledgers l ON l.id = c.ledger_id
      WHERE c.id = contact_id AND l.is_user_archived = true
    )
  );

CREATE POLICY transactions_all_owner
  ON public.transactions FOR ALL
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() = 'owner'
  )
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() = 'owner'
  );


-- ── contact_balances ────────────────────────────────────────────────────────

CREATE POLICY contact_balances_select
  ON public.contact_balances FOR SELECT
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('viewer', 'editor', 'owner')
  );

-- Balances are derived data — written by Edge Functions during merge.
-- INSERT/UPDATE granted for defense-in-depth but scoped.
CREATE POLICY contact_balances_write_editor
  ON public.contact_balances FOR INSERT
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
  );

CREATE POLICY contact_balances_update_editor
  ON public.contact_balances FOR UPDATE
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
  )
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
  );

CREATE POLICY contact_balances_all_owner
  ON public.contact_balances FOR ALL
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() = 'owner'
  )
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() = 'owner'
  );


-- ── audit_logs ──────────────────────────────────────────────────────────────
-- Append-only for all roles. SELECT for workspace members.

CREATE POLICY audit_logs_select
  ON public.audit_logs FOR SELECT
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('viewer', 'editor', 'owner')
  );

CREATE POLICY audit_logs_insert_editor
  ON public.audit_logs FOR INSERT
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
  );

-- No UPDATE or DELETE policies — audit logs are immutable.


-- ── shared_accounts ─────────────────────────────────────────────────────────
-- Workspace members can manage. B2C viewers can SELECT their own binding.

CREATE POLICY shared_accounts_select_member
  ON public.shared_accounts FOR SELECT
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('viewer', 'editor', 'owner')
  );

CREATE POLICY shared_accounts_select_b2c_viewer
  ON public.shared_accounts FOR SELECT
  USING (
    viewer_identity = public.jwt_identity_hash()
    AND state = 'claimed'
  );

CREATE POLICY shared_accounts_write_editor
  ON public.shared_accounts FOR INSERT
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
  );

CREATE POLICY shared_accounts_update_editor
  ON public.shared_accounts FOR UPDATE
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
  )
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() IN ('editor', 'owner')
  );

CREATE POLICY shared_accounts_all_owner
  ON public.shared_accounts FOR ALL
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() = 'owner'
  )
  WITH CHECK (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_role() = 'owner'
  );


-- ── Edge Function–only tables (deny all client access) ──────────────────────

CREATE POLICY migration_challenges_deny_all
  ON public.migration_challenges FOR ALL
  USING (false) WITH CHECK (false);

CREATE POLICY rate_limit_buckets_deny_all
  ON public.rate_limit_buckets FOR ALL
  USING (false) WITH CHECK (false);

CREATE POLICY deep_link_tokens_deny_all
  ON public.deep_link_tokens FOR ALL
  USING (false) WITH CHECK (false);

CREATE POLICY archived_shared_ledger_deny_all
  ON public.archived_shared_ledger FOR ALL
  USING (false) WITH CHECK (false);

CREATE POLICY promo_codes_deny_all
  ON public.promo_codes FOR ALL
  USING (false) WITH CHECK (false);

CREATE POLICY promo_redemptions_deny_all
  ON public.promo_redemptions FOR ALL
  USING (false) WITH CHECK (false);

CREATE POLICY referrals_deny_all
  ON public.referrals FOR ALL
  USING (false) WITH CHECK (false);

CREATE POLICY ai_usage_counters_deny_all
  ON public.ai_usage_counters FOR ALL
  USING (false) WITH CHECK (false);


-- ============================================================================
-- §18  REALTIME PUBLICATION
-- ============================================================================
-- Per supabase_config_reference.md §10: Realtime enabled programmatically
-- in migrations, NOT via Dashboard. Only sync-relevant business tables.
-- audit_logs excluded (too voluminous). Workspace/membership tables excluded
-- (managed via Edge Functions). B2C viewers have NO persistent socket.

ALTER PUBLICATION supabase_realtime ADD TABLE
  public.ledgers,
  public.contacts,
  public.transactions,
  public.contact_balances;


-- ============================================================================
-- §19  GRANTS — Principle of Least Privilege
-- ============================================================================
-- PostgREST roles: anon (unauthenticated), authenticated (has valid JWT).
-- Custom JWT arrives as 'authenticated' via Authorization header.
-- anon gets NOTHING on any table.

-- ── Revoke all from anon ────────────────────────────────────────────────────

REVOKE ALL ON public.workspaces              FROM anon;
REVOKE ALL ON public.workspace_members       FROM anon;
REVOKE ALL ON public.migration_challenges    FROM anon;
REVOKE ALL ON public.rate_limit_buckets      FROM anon;
REVOKE ALL ON public.ledgers                 FROM anon;
REVOKE ALL ON public.contacts                FROM anon;
REVOKE ALL ON public.transactions            FROM anon;
REVOKE ALL ON public.contact_balances        FROM anon;
REVOKE ALL ON public.audit_logs              FROM anon;
REVOKE ALL ON public.shared_accounts         FROM anon;
REVOKE ALL ON public.deep_link_tokens        FROM anon;
REVOKE ALL ON public.archived_shared_ledger  FROM anon;
REVOKE ALL ON public.promo_codes             FROM anon;
REVOKE ALL ON public.promo_redemptions       FROM anon;
REVOKE ALL ON public.referrals               FROM anon;
REVOKE ALL ON public.ai_usage_counters       FROM anon;

-- ── Grant authenticated on client-facing tables ─────────────────────────────

GRANT SELECT, INSERT, UPDATE         ON public.workspaces        TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.workspace_members TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON public.ledgers           TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON public.contacts          TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON public.transactions      TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON public.contact_balances  TO authenticated;
GRANT SELECT, INSERT                 ON public.audit_logs        TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON public.shared_accounts   TO authenticated;

-- ── Edge Function–only tables: NO client grants ─────────────────────────────

REVOKE ALL ON public.migration_challenges    FROM authenticated;
REVOKE ALL ON public.rate_limit_buckets      FROM authenticated;
REVOKE ALL ON public.deep_link_tokens        FROM authenticated;
REVOKE ALL ON public.archived_shared_ledger  FROM authenticated;
REVOKE ALL ON public.promo_codes             FROM authenticated;
REVOKE ALL ON public.promo_redemptions       FROM authenticated;
REVOKE ALL ON public.referrals               FROM authenticated;
REVOKE ALL ON public.ai_usage_counters       FROM authenticated;

-- ── Grant sequence usage for Edge Functions ─────────────────────────────────

GRANT USAGE ON SEQUENCE public.global_op_seq TO authenticated;

-- ── Grant helper functions ──────────────────────────────────────────────────

GRANT EXECUTE ON FUNCTION public.jwt_workspace_id()   TO authenticated;
GRANT EXECUTE ON FUNCTION public.jwt_role()           TO authenticated;
GRANT EXECUTE ON FUNCTION public.jwt_identity_hash()  TO authenticated;

REVOKE EXECUTE ON FUNCTION public.jwt_workspace_id()  FROM anon;
REVOKE EXECUTE ON FUNCTION public.jwt_role()          FROM anon;
REVOKE EXECUTE ON FUNCTION public.jwt_identity_hash() FROM anon;


-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
