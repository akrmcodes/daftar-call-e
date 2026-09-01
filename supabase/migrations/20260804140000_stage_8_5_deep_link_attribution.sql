-- ============================================================================
-- Stage 8.5 — Deep-Link attribution: renewal stubs + analytics
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.invite_renewal_requests (
  id                       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id             UUID        NOT NULL
                                       REFERENCES public.workspaces (id) ON DELETE CASCADE,
  original_token           TEXT        NOT NULL,
  kind                     public.token_kind NOT NULL,
  intent_payload           JSONB       NOT NULL DEFAULT '{}'::jsonb,
  requester_identity_hash  TEXT,
  status                   TEXT        NOT NULL DEFAULT 'pending'
                                       CHECK (status IN ('pending', 'fulfilled', 'dismissed')),
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invite_renewal_workspace_pending
  ON public.invite_renewal_requests (workspace_id, status, created_at DESC);

COMMENT ON TABLE public.invite_renewal_requests
  IS 'Stage 8.5.1 stub merchant ping for expired-link ceremony. No FCM — inbox/read UI later.';

CREATE TABLE IF NOT EXISTS public.deep_link_events (
  id          BIGSERIAL   PRIMARY KEY,
  token       TEXT,
  event_type  TEXT        NOT NULL
                          CHECK (event_type IN (
                            'created',
                            'click',
                            'claim_ok',
                            'claim_terminal',
                            'renewal_requested'
                          )),
  metadata    JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_deep_link_events_token
  ON public.deep_link_events (token, created_at DESC)
  WHERE token IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_deep_link_events_type
  ON public.deep_link_events (event_type, created_at DESC);

COMMENT ON TABLE public.deep_link_events
  IS 'Attribution / claim analytics for Stage 8.5 and Stage 14 referrals.';

ALTER TABLE public.invite_renewal_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deep_link_events ENABLE ROW LEVEL SECURITY;

-- Deny-all for anon/authenticated; Edge Functions use service_role.
REVOKE ALL ON public.invite_renewal_requests FROM anon, authenticated;
REVOKE ALL ON public.deep_link_events FROM anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.invite_renewal_requests TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.deep_link_events TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.deep_link_events_id_seq TO service_role;

-- claim-deep-link activates pending workers
GRANT SELECT, INSERT, UPDATE, DELETE ON public.deep_link_tokens TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.workspace_members TO service_role;
GRANT SELECT, INSERT, UPDATE ON public.rate_limit_buckets TO service_role;
