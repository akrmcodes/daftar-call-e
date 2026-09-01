-- ============================================================================
-- MIGRATION: JWT workspace_role claim + atomic workspace provisioning
-- ============================================================================
-- Stage 8.3 — Auth Bridge hardening
--
-- PostgREST requires JWT `role` = 'authenticated' (Postgres session role).
-- Workspace permission tier lives in `workspace_role` (owner/editor/viewer).
-- ============================================================================

-- Partial unique index: one active workspace per owner identity (race-safe).
CREATE UNIQUE INDEX IF NOT EXISTS uq_workspaces_owner_identity_active
  ON public.workspaces (owner_identity)
  WHERE status = 'active';

COMMENT ON INDEX public.uq_workspaces_owner_identity_active
  IS 'Enforces one active workspace per owner_identity. Enables ON CONFLICT provisioning.';


-- Read workspace permission tier from workspace_role claim (fallback: legacy role).
CREATE OR REPLACE FUNCTION public.jwt_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    current_setting('request.jwt.claims', true)::json ->> 'workspace_role',
    current_setting('request.jwt.claims', true)::json ->> 'role'
  );
$$;

COMMENT ON FUNCTION public.jwt_role()
  IS 'Extracts workspace permission tier (owner/editor/viewer) from custom sync JWT. Prefers workspace_role claim; falls back to legacy role claim.';


-- Atomic identity → workspace resolution for the Auth Bridge Edge Function.
CREATE OR REPLACE FUNCTION public.provision_workspace(
  p_identity_hash TEXT,
  p_email         TEXT
)
RETURNS TABLE (workspace_id UUID, workspace_role TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_workspace_id UUID;
  v_role         TEXT;
BEGIN
  IF p_identity_hash IS NULL OR length(trim(p_identity_hash)) = 0 THEN
    RAISE EXCEPTION 'identity_hash is required';
  END IF;

  -- 1. Existing owner workspace
  SELECT w.id, 'owner'
    INTO v_workspace_id, v_role
    FROM public.workspaces w
   WHERE w.owner_identity = p_identity_hash
     AND w.status = 'active'
   LIMIT 1;

  IF v_workspace_id IS NOT NULL THEN
    RETURN QUERY SELECT v_workspace_id, v_role;
    RETURN;
  END IF;

  -- 2. Active worker membership (matched by invited email)
  IF p_email IS NOT NULL AND length(trim(p_email)) > 0 THEN
    SELECT wm.workspace_id, wm.role
      INTO v_workspace_id, v_role
      FROM public.workspace_members wm
     WHERE wm.invited_email = p_email
       AND wm.status = 'active'
     LIMIT 1;

    IF v_workspace_id IS NOT NULL THEN
      RETURN QUERY SELECT v_workspace_id, v_role;
      RETURN;
    END IF;
  END IF;

  -- 3. First-time user — atomic workspace + owner seat
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
    invited_email
  )
  VALUES (v_workspace_id, 'owner', 'active', 0, p_email)
  ON CONFLICT (workspace_id, seat_index) DO NOTHING;

  RETURN QUERY SELECT v_workspace_id, 'owner'::TEXT;
END;
$$;

COMMENT ON FUNCTION public.provision_workspace(TEXT, TEXT)
  IS 'Auth Bridge RPC: resolve identity to workspace+role; auto-provision owner workspace on first sync. Called with service_role only.';

REVOKE ALL ON FUNCTION public.provision_workspace(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.provision_workspace(TEXT, TEXT) TO service_role;
