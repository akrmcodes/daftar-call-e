-- ============================================================================
-- Stage 8.7 — Inline consume_rate_limits (single-pass lock per bucket)
-- ============================================================================
-- Replaces nested peek_rate_limit + consume_rate_limit double-lock pattern
-- to reduce lock hold time under concurrent invite-worker calls.

CREATE OR REPLACE FUNCTION public.consume_rate_limits(p_checks jsonb)
RETURNS TABLE (
  allowed boolean,
  retry_after_seconds integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check jsonb;
  v_key text;
  v_capacity double precision;
  v_refill double precision;
  v_cost double precision;
  v_now timestamptz := now();
  v_tokens double precision;
  v_last_refill timestamptz;
  v_hours double precision;
  v_retry integer;
  v_allowed boolean := true;
  v_max_retry integer := 0;
BEGIN
  IF p_checks IS NULL OR jsonb_typeof(p_checks) <> 'array' OR jsonb_array_length(p_checks) = 0 THEN
    RETURN QUERY SELECT true, 0;
    RETURN;
  END IF;

  -- Phase 1: ensure rows exist (no lock yet).
  FOR v_check IN
    SELECT elem.value
    FROM jsonb_array_elements(p_checks) AS elem(value)
    ORDER BY elem.value ->> 'key'
  LOOP
    v_key := v_check ->> 'key';
    v_capacity := (v_check ->> 'capacity')::double precision;
    INSERT INTO public.rate_limit_buckets (bucket_key, tokens, last_refill)
    VALUES (v_key, v_capacity, v_now)
    ON CONFLICT (bucket_key) DO NOTHING;
  END LOOP;

  -- Phase 2: lock each bucket once, refill, peek (deny without consume).
  FOR v_check IN
    SELECT elem.value
    FROM jsonb_array_elements(p_checks) AS elem(value)
    ORDER BY elem.value ->> 'key'
  LOOP
    v_key := v_check ->> 'key';
    v_capacity := (v_check ->> 'capacity')::double precision;
    v_refill := (v_check ->> 'refill_per_hour')::double precision;
    v_cost := COALESCE((v_check ->> 'cost')::double precision, 1.0);

    SELECT b.tokens, b.last_refill
    INTO v_tokens, v_last_refill
    FROM public.rate_limit_buckets AS b
    WHERE b.bucket_key = v_key
    FOR UPDATE;

    v_hours := GREATEST(
      0,
      EXTRACT(EPOCH FROM (v_now - v_last_refill)) / 3600.0
    );
    v_tokens := LEAST(v_capacity, v_tokens + v_hours * v_refill);

    IF v_tokens < v_cost THEN
      v_allowed := false;
      IF v_refill > 0 THEN
        v_retry := GREATEST(
          1,
          ceil((v_cost - v_tokens) / v_refill * 3600.0)::integer
        );
      ELSE
        v_retry := 3600;
      END IF;
      v_max_retry := GREATEST(v_max_retry, v_retry);

      UPDATE public.rate_limit_buckets
      SET tokens = v_tokens,
          last_refill = v_now
      WHERE bucket_key = v_key;
    END IF;
  END LOOP;

  IF NOT v_allowed THEN
    RETURN QUERY SELECT false, v_max_retry;
    RETURN;
  END IF;

  -- Phase 3: consume (rows already locked in sorted order from phase 2 —
  -- re-lock in same order; locks are released between loops).
  FOR v_check IN
    SELECT elem.value
    FROM jsonb_array_elements(p_checks) AS elem(value)
    ORDER BY elem.value ->> 'key'
  LOOP
    v_key := v_check ->> 'key';
    v_capacity := (v_check ->> 'capacity')::double precision;
    v_refill := (v_check ->> 'refill_per_hour')::double precision;
    v_cost := COALESCE((v_check ->> 'cost')::double precision, 1.0);

    SELECT b.tokens, b.last_refill
    INTO v_tokens, v_last_refill
    FROM public.rate_limit_buckets AS b
    WHERE b.bucket_key = v_key
    FOR UPDATE;

    v_hours := GREATEST(
      0,
      EXTRACT(EPOCH FROM (v_now - v_last_refill)) / 3600.0
    );
    v_tokens := LEAST(v_capacity, v_tokens + v_hours * v_refill);

    UPDATE public.rate_limit_buckets
    SET tokens = v_tokens - v_cost,
        last_refill = v_now
    WHERE bucket_key = v_key;
  END LOOP;

  RETURN QUERY SELECT true, 0;
END;
$$;

COMMENT ON FUNCTION public.consume_rate_limits IS
  'Stage 8.7 — single-pass multi-bucket evaluate+consume (sorted key order).';
