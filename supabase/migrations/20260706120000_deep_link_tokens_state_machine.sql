-- ============================================================================
-- Migration: deep_link_tokens_state_machine
-- ============================================================================
-- Stage 8.6.1 — Token state machine, Postgres ENUMs, and claim-coherence
-- constraints for the Deep-Link & Attribution Service.
--
-- Strategy: DROP + CREATE (pre-production). Re-applies deny-all RLS from §12.
--
-- State machine: active → claimed | expired | revoked | superseded
-- TTL by kind:  worker_invite ~72h, share ~30d, referral ~30d
-- ============================================================================

-- Drop legacy table (TEXT+CHECK, surrogate UUID PK, ttl_expires_at).
DROP TABLE IF EXISTS public.deep_link_tokens CASCADE;

-- Drop ENUMs if a prior partial apply left them behind.
DROP TYPE IF EXISTS public.token_kind CASCADE;
DROP TYPE IF EXISTS public.token_state CASCADE;

-- --------------------------------------------------------------------------
-- ENUMs
-- --------------------------------------------------------------------------

CREATE TYPE public.token_kind AS ENUM (
  'share',
  'referral',
  'worker_invite'
);

CREATE TYPE public.token_state AS ENUM (
  'active',
  'claimed',
  'expired',
  'revoked',
  'superseded'
);

COMMENT ON TYPE public.token_kind
  IS 'Deep-link intent classification (Stages 11 & 14).';
COMMENT ON TYPE public.token_state
  IS 'TTL lifecycle state: active → claimed/expired/revoked/superseded.';

-- --------------------------------------------------------------------------
-- TTL helper (mint-time expires_at computation)
-- --------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.deep_link_ttl_interval(p_kind public.token_kind)
RETURNS INTERVAL
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE p_kind
    WHEN 'worker_invite' THEN INTERVAL '72 hours'
    WHEN 'share'         THEN INTERVAL '30 days'
    WHEN 'referral'      THEN INTERVAL '30 days'
  END;
$$;

COMMENT ON FUNCTION public.deep_link_ttl_interval(public.token_kind)
  IS 'Default TTL interval per token kind (§8.6.1).';

-- --------------------------------------------------------------------------
-- TABLE: deep_link_tokens
-- --------------------------------------------------------------------------

CREATE TABLE public.deep_link_tokens (
  token           TEXT          PRIMARY KEY,
  kind            public.token_kind   NOT NULL,
  intent_payload  JSONB         NOT NULL DEFAULT '{}'::jsonb,
  workspace_id    UUID          REFERENCES public.workspaces (id) ON DELETE SET NULL,
  created_by      TEXT,
  state           public.token_state  NOT NULL DEFAULT 'active',
  expires_at      TIMESTAMPTZ   NOT NULL,
  claimed_by      TEXT,
  claimed_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),

  CONSTRAINT chk_deep_link_token_entropy CHECK (length(token) >= 32),

  CONSTRAINT chk_deep_link_claimed_coherence CHECK (
    (state = 'claimed' AND claimed_by IS NOT NULL AND claimed_at IS NOT NULL)
    OR
    (state <> 'claimed' AND claimed_by IS NULL AND claimed_at IS NULL)
  )
);

CREATE INDEX idx_deep_link_workspace
  ON public.deep_link_tokens (workspace_id)
  WHERE workspace_id IS NOT NULL;

CREATE INDEX idx_deep_link_expires_active
  ON public.deep_link_tokens (expires_at)
  WHERE state = 'active';

CREATE UNIQUE INDEX uq_deep_link_active_worker_invite
  ON public.deep_link_tokens ((intent_payload->>'member_id'))
  WHERE kind = 'worker_invite' AND state = 'active';

COMMENT ON TABLE public.deep_link_tokens
  IS 'Opaque deep-link tokens with TTL lifecycle. Shared foundation for share/referral/invite flows.';
COMMENT ON COLUMN public.deep_link_tokens.token
  IS 'High-entropy opaque token (PK). Minted by Edge Functions.';
COMMENT ON COLUMN public.deep_link_tokens.created_by
  IS 'Minter identity_hash (nullable for system-minted tokens).';
COMMENT ON COLUMN public.deep_link_tokens.claimed_by
  IS 'Claimer identity_hash. Required when state = claimed.';
COMMENT ON COLUMN public.deep_link_tokens.state
  IS 'active → claimed/expired/revoked/superseded. Full TTL lifecycle per §8.6.';

-- --------------------------------------------------------------------------
-- RLS & grants (Edge Function–only, deny-all for clients)
-- --------------------------------------------------------------------------

ALTER TABLE public.deep_link_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY deep_link_tokens_deny_all
  ON public.deep_link_tokens FOR ALL
  USING (false) WITH CHECK (false);

REVOKE ALL ON public.deep_link_tokens FROM anon;
REVOKE ALL ON public.deep_link_tokens FROM authenticated;
