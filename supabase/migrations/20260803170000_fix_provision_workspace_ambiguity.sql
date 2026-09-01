-- ============================================================================
-- Fix provision_workspace: disambiguate workspace_id (RETURNS TABLE vs columns)
-- ============================================================================
-- Postgres 42702: output column names from RETURNS TABLE shadow table columns
-- in UPDATE WHERE and ON CONFLICT clauses. Qualify table columns explicitly.

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
#variable_conflict use_variable
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
    UPDATE public.workspace_members wm
       SET identity_hash = p_identity_hash,
           invited_email = COALESCE(wm.invited_email, v_email),
           updated_at = now()
     WHERE wm.workspace_id = v_workspace_id
       AND wm.role = 'owner'
       AND wm.seat_index = 0
       AND (wm.identity_hash IS NULL OR wm.identity_hash = p_identity_hash);

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
      UPDATE public.workspace_members wm
         SET identity_hash = p_identity_hash,
             updated_at = now()
       WHERE wm.id = v_member_id
         AND (wm.identity_hash IS NULL OR wm.identity_hash = p_identity_hash);

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
  ON CONFLICT ON CONSTRAINT uq_workspace_members_seat DO UPDATE
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
