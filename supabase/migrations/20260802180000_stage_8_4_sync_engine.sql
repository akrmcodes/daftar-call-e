-- ============================================================================
-- Stage 8.4 — Sync Engine: device registry, usage caps, pull indexes
-- ============================================================================

-- Device registry per workspace (max 10 active devices enforced by trigger)
CREATE TABLE IF NOT EXISTS public.workspace_devices (
  workspace_id   UUID        NOT NULL
                             REFERENCES public.workspaces (id) ON DELETE CASCADE,
  device_id      TEXT        NOT NULL,
  identity_hash  TEXT        NOT NULL,
  last_seen_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  status         TEXT        NOT NULL DEFAULT 'active'
                             CHECK (status IN ('active', 'revoked')),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),

  PRIMARY KEY (workspace_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_workspace_devices_active
  ON public.workspace_devices (workspace_id, status)
  WHERE status = 'active';

CREATE TRIGGER trg_workspace_devices_updated_at
  BEFORE UPDATE ON public.workspace_devices
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

COMMENT ON TABLE public.workspace_devices
  IS 'Registered sync devices per workspace. Max 10 active enforced by trigger.';

-- Monthly sync event counter (50k/month cap enforced in push-sync-ops)
CREATE TABLE IF NOT EXISTS public.sync_usage_counters (
  workspace_id  UUID        NOT NULL
                            REFERENCES public.workspaces (id) ON DELETE CASCADE,
  usage_month   TEXT        NOT NULL CHECK (usage_month ~ '^\d{4}-\d{2}$'),
  event_count   INT         NOT NULL DEFAULT 0 CHECK (event_count >= 0),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

  PRIMARY KEY (workspace_id, usage_month)
);

COMMENT ON TABLE public.sync_usage_counters
  IS 'Monthly accepted push-op counter per workspace (50k cap in Edge Function).';

-- Enforce max 10 active devices per workspace
CREATE OR REPLACE FUNCTION public.enforce_workspace_device_cap()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  active_count INT;
BEGIN
  IF NEW.status = 'active' THEN
    SELECT COUNT(*)
      INTO active_count
      FROM public.workspace_devices
     WHERE workspace_id = NEW.workspace_id
       AND status = 'active'
       AND device_id <> NEW.device_id;

    IF active_count >= 10 THEN
      RAISE EXCEPTION 'device_cap_exceeded'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_workspace_devices_cap ON public.workspace_devices;
CREATE TRIGGER trg_workspace_devices_cap
  BEFORE INSERT OR UPDATE OF status ON public.workspace_devices
  FOR EACH ROW EXECUTE FUNCTION public.enforce_workspace_device_cap();

-- Composite pull index for op-log catch-up
CREATE INDEX IF NOT EXISTS idx_audit_workspace_op_seq
  ON public.audit_logs (workspace_id, op_seq)
  WHERE op_seq IS NOT NULL;

-- RLS: workspace members can read their device registry; writes via service role only
ALTER TABLE public.workspace_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_usage_counters ENABLE ROW LEVEL SECURITY;

CREATE POLICY workspace_devices_select_member
  ON public.workspace_devices
  FOR SELECT
  TO authenticated
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('viewer', 'editor', 'owner')
  );

CREATE POLICY sync_usage_counters_select_member
  ON public.sync_usage_counters
  FOR SELECT
  TO authenticated
  USING (
    workspace_id = public.jwt_workspace_id()
    AND public.jwt_is_member('viewer', 'editor', 'owner')
  );

GRANT SELECT ON public.workspace_devices TO authenticated;
GRANT SELECT ON public.sync_usage_counters TO authenticated;

-- RPC for Edge Functions to assign monotonic op_seq atomically
CREATE OR REPLACE FUNCTION public.next_global_op_seq()
RETURNS BIGINT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT nextval('public.global_op_seq');
$$;

REVOKE ALL ON FUNCTION public.next_global_op_seq() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.next_global_op_seq() TO service_role;
