-- ============================================================================
-- Stage 8.8 — Server-side entitlement tier + atomic seat/usage RPCs
-- ============================================================================
-- Replaces three read-modify-write races in the Edge Functions with
-- single-transaction RPCs, and gives the rate limiter a server-side source of
-- truth for the caller's entitlement tier.
--
--   §1  workspaces.tier      — server-side entitlement (was client-only)
--   §2  consume_sync_usage   — atomic monthly sync-event cap
--   §3  claim_worker_seat    — atomic seat cap + concurrent-editor cap
-- ============================================================================


-- ----------------------------------------------------------------------------
-- §1  workspaces.tier
-- ----------------------------------------------------------------------------
-- Until Stage 13 stamps entitlements server-side this stays NULL for existing
-- rows. NULL means "unknown", and _shared/rate_limit.ts fails closed on unknown
-- by applying the strictest schedule. It is deliberately nullable rather than
-- DEFAULT 'pro_plus' so an unstamped workspace can never silently inherit the
-- loosest limits.

ALTER TABLE public.workspaces
  ADD COLUMN IF NOT EXISTS tier TEXT;

ALTER TABLE public.workspaces
  DROP CONSTRAINT IF EXISTS chk_workspaces_tier;

ALTER TABLE public.workspaces
  ADD CONSTRAINT chk_workspaces_tier
  CHECK (tier IS NULL OR tier IN ('free', 'pro', 'pro_plus'));

COMMENT ON COLUMN public.workspaces.tier
  IS 'Server-side entitlement tier (free/pro/pro_plus). NULL = not yet stamped; the rate limiter treats NULL as unknown and applies the strictest schedule.';

GRANT SELECT ON public.workspaces TO service_role;


-- ----------------------------------------------------------------------------
-- §2  consume_sync_usage — atomic monthly sync-event cap
-- ----------------------------------------------------------------------------
-- push-sync-ops previously did SELECT event_count → UPSERT count + n, so two
-- concurrent pushes lost one another's increment and could both pass a cap they
-- jointly exceeded. The row lock makes check-and-increment one operation.

CREATE OR REPLACE FUNCTION public.consume_sync_usage(
  p_workspace_id UUID,
  p_usage_month  TEXT,
  p_events       INT,
  p_cap          INT
)
RETURNS TABLE (
  allowed     BOOLEAN,
  event_count INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
#variable_conflict use_variable
DECLARE
  v_count INT;
BEGIN
  IF p_workspace_id IS NULL THEN
    RAISE EXCEPTION 'workspace_id is required';
  END IF;
  IF p_usage_month !~ '^\d{4}-\d{2}$' THEN
    RAISE EXCEPTION 'usage_month must be YYYY-MM';
  END IF;
  IF p_events IS NULL THEN
    RAISE EXCEPTION 'events is required';
  END IF;
  IF p_cap IS NULL OR p_cap < 0 THEN
    RAISE EXCEPTION 'cap must be >= 0';
  END IF;

  INSERT INTO public.sync_usage_counters AS c
    (workspace_id, usage_month, event_count, updated_at)
  VALUES (p_workspace_id, p_usage_month, 0, now())
  ON CONFLICT ON CONSTRAINT sync_usage_counters_pkey DO NOTHING;

  SELECT c.event_count
    INTO v_count
    FROM public.sync_usage_counters c
   WHERE c.workspace_id = p_workspace_id
     AND c.usage_month = p_usage_month
     FOR UPDATE;

  IF v_count IS NULL THEN
    RAISE EXCEPTION 'sync usage counter missing after upsert';
  END IF;

  IF p_events = 0 THEN
    RETURN QUERY SELECT true, v_count;
    RETURN;
  END IF;

  -- Negative events release an earlier reservation (duplicate or rejected ops).
  -- Releases are never capped and never drive the counter below zero.
  IF p_events > 0 AND v_count + p_events > p_cap THEN
    RETURN QUERY SELECT false, v_count;
    RETURN;
  END IF;

  v_count := GREATEST(0, v_count + p_events);

  UPDATE public.sync_usage_counters c
     SET event_count = v_count,
         updated_at = now()
   WHERE c.workspace_id = p_workspace_id
     AND c.usage_month = p_usage_month;

  RETURN QUERY SELECT true, v_count;
END;
$$;

COMMENT ON FUNCTION public.consume_sync_usage(UUID, TEXT, INT, INT)
  IS 'Atomically check-and-increment the monthly sync-event counter. Returns allowed=false without incrementing when the batch would exceed the cap. A negative p_events releases an earlier reservation, clamped at zero.';

REVOKE ALL ON FUNCTION public.consume_sync_usage(UUID, TEXT, INT, INT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_sync_usage(UUID, TEXT, INT, INT)
  TO service_role;


-- ----------------------------------------------------------------------------
-- §3  claim_worker_seat — atomic seat cap + concurrent-editor cap
-- ----------------------------------------------------------------------------
-- Two distinct caps with deliberately different failure modes:
--
--   Seat cap (2 workers)    → REJECTED. outcome = 'seat_cap_exceeded'.
--   Editor cap (2 editors)  → DOWNGRADED, never rejected. The caller is told
--                             the effective role so it can inform the user.
--
-- The Owner is editor-capable by definition and always occupies one of the two
-- editor slots, so at most ONE worker may be an Editor. This bounds the
-- concurrent-writer set to a single pair (pairs = W·(W−1)/2 = 1), which is what
-- the client merge engine and conflict-review UI were sized for.
--
-- The workspace row lock serializes concurrent invites, so the tally cannot be
-- read stale — the previous SELECT-then-INSERT in invite-worker could seat two
-- Editors under a race even with a correct tally.

CREATE OR REPLACE FUNCTION public.claim_worker_seat(
  p_workspace_id   UUID,
  p_invited_email  TEXT,
  p_requested_role TEXT
)
RETURNS TABLE (
  member_id      UUID,
  effective_role TEXT,
  seat_index     INT,
  outcome        TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
#variable_conflict use_variable
DECLARE
  -- Owner + 2 workers (workspace_members.seat_index ∈ {0,1,2}).
  c_max_workers  CONSTANT INT := 2;
  -- Owner + at most 1 worker Editor.
  c_max_editors  CONSTANT INT := 2;

  v_email        TEXT;
  v_requested    TEXT;
  v_effective    TEXT;
  v_worker_count INT;
  v_editor_count INT;
  v_seat         INT;
  v_member_id    UUID;
BEGIN
  IF p_workspace_id IS NULL THEN
    RAISE EXCEPTION 'workspace_id is required';
  END IF;

  v_email := NULLIF(lower(trim(COALESCE(p_invited_email, ''))), '');
  IF v_email IS NULL THEN
    RAISE EXCEPTION 'invited_email is required';
  END IF;

  v_requested := lower(trim(COALESCE(p_requested_role, 'viewer')));
  IF v_requested NOT IN ('editor', 'viewer') THEN
    RAISE EXCEPTION 'role must be editor or viewer';
  END IF;

  PERFORM 1 FROM public.workspaces w
   WHERE w.id = p_workspace_id
     FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY
      SELECT NULL::UUID, NULL::TEXT, NULL::INT, 'workspace_not_found'::TEXT;
    RETURN;
  END IF;

  -- Re-inviting an address that already holds a pending seat reuses that seat
  -- rather than consuming a second one.
  SELECT wm.id, wm.seat_index
    INTO v_member_id, v_seat
    FROM public.workspace_members wm
   WHERE wm.workspace_id = p_workspace_id
     AND wm.status = 'pending'
     AND lower(wm.invited_email) = v_email
   ORDER BY wm.seat_index ASC
   LIMIT 1;

  -- Editor tally counts the Owner. A member whose seat is being reused is
  -- excluded so re-inviting the same Editor does not downgrade them.
  SELECT count(*)::INT
    INTO v_editor_count
    FROM public.workspace_members wm
   WHERE wm.workspace_id = p_workspace_id
     AND wm.status IN ('pending', 'active')
     AND wm.role IN ('owner', 'editor')
     AND (v_member_id IS NULL OR wm.id <> v_member_id);

  v_effective := v_requested;
  IF v_effective = 'editor' AND v_editor_count >= c_max_editors THEN
    v_effective := 'viewer';
  END IF;

  IF v_member_id IS NOT NULL THEN
    UPDATE public.workspace_members wm
       SET role = v_effective,
           updated_at = now()
     WHERE wm.id = v_member_id;

    RETURN QUERY SELECT v_member_id, v_effective, v_seat, 'reused'::TEXT;
    RETURN;
  END IF;

  SELECT count(*)::INT
    INTO v_worker_count
    FROM public.workspace_members wm
   WHERE wm.workspace_id = p_workspace_id
     AND wm.seat_index > 0
     AND wm.status IN ('pending', 'active');

  IF v_worker_count >= c_max_workers THEN
    RETURN QUERY
      SELECT NULL::UUID, NULL::TEXT, NULL::INT, 'seat_cap_exceeded'::TEXT;
    RETURN;
  END IF;

  SELECT s.idx
    INTO v_seat
    FROM generate_series(1, c_max_workers) AS s(idx)
   WHERE NOT EXISTS (
     SELECT 1 FROM public.workspace_members wm
      WHERE wm.workspace_id = p_workspace_id
        AND wm.seat_index = s.idx
   )
   ORDER BY s.idx ASC
   LIMIT 1;

  IF v_seat IS NULL THEN
    RETURN QUERY
      SELECT NULL::UUID, NULL::TEXT, NULL::INT, 'seat_cap_exceeded'::TEXT;
    RETURN;
  END IF;

  INSERT INTO public.workspace_members
    (workspace_id, invited_email, role, status, seat_index)
  VALUES (p_workspace_id, v_email, v_effective, 'pending', v_seat)
  RETURNING id INTO v_member_id;

  RETURN QUERY SELECT v_member_id, v_effective, v_seat, 'created'::TEXT;
END;
$$;

COMMENT ON FUNCTION public.claim_worker_seat(UUID, TEXT, TEXT)
  IS 'Atomically allocate a worker seat. Seat cap over-subscription is rejected (outcome=seat_cap_exceeded); editor-cap over-subscription downgrades the role to viewer and reports it via effective_role. Owner counts toward the 2-editor cap.';

REVOKE ALL ON FUNCTION public.claim_worker_seat(UUID, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_worker_seat(UUID, TEXT, TEXT)
  TO service_role;
