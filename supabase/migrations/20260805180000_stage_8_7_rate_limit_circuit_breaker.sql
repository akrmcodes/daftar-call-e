-- ============================================================================
-- Stage 8.7 — Atomic rate-limit RPCs, invite queue, ops alerts
-- ============================================================================

-- ----------------------------------------------------------------------------
-- peek_rate_limit — refill math without consuming (used by consume_rate_limits)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.peek_rate_limit(
  p_bucket_key text,
  p_capacity double precision,
  p_refill_per_hour double precision,
  p_cost double precision DEFAULT 1
)
RETURNS TABLE (
  allowed boolean,
  tokens_remaining double precision,
  retry_after_seconds integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now timestamptz := now();
  v_tokens double precision;
  v_last_refill timestamptz;
  v_hours double precision;
  v_retry integer;
BEGIN
  INSERT INTO public.rate_limit_buckets (bucket_key, tokens, last_refill)
  VALUES (p_bucket_key, p_capacity, v_now)
  ON CONFLICT (bucket_key) DO NOTHING;

  SELECT b.tokens, b.last_refill
  INTO v_tokens, v_last_refill
  FROM public.rate_limit_buckets AS b
  WHERE b.bucket_key = p_bucket_key
  FOR UPDATE;

  v_hours := GREATEST(
    0,
    EXTRACT(EPOCH FROM (v_now - v_last_refill)) / 3600.0
  );
  v_tokens := LEAST(p_capacity, v_tokens + v_hours * p_refill_per_hour);

  IF v_tokens < p_cost THEN
    IF p_refill_per_hour > 0 THEN
      v_retry := GREATEST(
        1,
        ceil((p_cost - v_tokens) / p_refill_per_hour * 3600.0)::integer
      );
    ELSE
      v_retry := 3600;
    END IF;

    UPDATE public.rate_limit_buckets
    SET tokens = v_tokens,
        last_refill = v_now
    WHERE bucket_key = p_bucket_key;

    RETURN QUERY SELECT false, v_tokens, v_retry;
    RETURN;
  END IF;

  RETURN QUERY SELECT true, v_tokens - p_cost, 0;
END;
$$;

COMMENT ON FUNCTION public.peek_rate_limit IS
  'Stage 8.7 — evaluate a token bucket after refill without consuming.';

-- ----------------------------------------------------------------------------
-- consume_rate_limit — atomic single-bucket consume
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.consume_rate_limit(
  p_bucket_key text,
  p_capacity double precision,
  p_refill_per_hour double precision,
  p_cost double precision DEFAULT 1
)
RETURNS TABLE (
  allowed boolean,
  tokens_remaining double precision,
  retry_after_seconds integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now timestamptz := now();
  v_tokens double precision;
  v_last_refill timestamptz;
  v_hours double precision;
  v_retry integer;
  v_allowed boolean;
  v_remaining double precision;
BEGIN
  INSERT INTO public.rate_limit_buckets (bucket_key, tokens, last_refill)
  VALUES (p_bucket_key, p_capacity, v_now)
  ON CONFLICT (bucket_key) DO NOTHING;

  SELECT b.tokens, b.last_refill
  INTO v_tokens, v_last_refill
  FROM public.rate_limit_buckets AS b
  WHERE b.bucket_key = p_bucket_key
  FOR UPDATE;

  v_hours := GREATEST(
    0,
    EXTRACT(EPOCH FROM (v_now - v_last_refill)) / 3600.0
  );
  v_tokens := LEAST(p_capacity, v_tokens + v_hours * p_refill_per_hour);

  IF v_tokens < p_cost THEN
    v_allowed := false;
    v_remaining := v_tokens;
    IF p_refill_per_hour > 0 THEN
      v_retry := GREATEST(
        1,
        ceil((p_cost - v_tokens) / p_refill_per_hour * 3600.0)::integer
      );
    ELSE
      v_retry := 3600;
    END IF;

    UPDATE public.rate_limit_buckets
    SET tokens = v_remaining,
        last_refill = v_now
    WHERE bucket_key = p_bucket_key;
  ELSE
    v_allowed := true;
    v_remaining := v_tokens - p_cost;
    v_retry := 0;

    UPDATE public.rate_limit_buckets
    SET tokens = v_remaining,
        last_refill = v_now
    WHERE bucket_key = p_bucket_key;
  END IF;

  RETURN QUERY SELECT v_allowed, v_remaining, v_retry;
END;
$$;

COMMENT ON FUNCTION public.consume_rate_limit IS
  'Stage 8.7 — atomically refill and consume from a token bucket.';

-- ----------------------------------------------------------------------------
-- consume_rate_limits — multi-dimensional, most-restrictive-wins (peek then consume)
-- ----------------------------------------------------------------------------

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
  v_allowed boolean := true;
  v_retry integer := 0;
  v_result record;
BEGIN
  IF p_checks IS NULL OR jsonb_typeof(p_checks) <> 'array' OR jsonb_array_length(p_checks) = 0 THEN
    RETURN QUERY SELECT true, 0;
    RETURN;
  END IF;

  FOR v_check IN
    SELECT elem.value
    FROM jsonb_array_elements(p_checks) AS elem(value)
    ORDER BY elem.value ->> 'key'
  LOOP
    SELECT *
    INTO v_result
    FROM public.peek_rate_limit(
      v_check ->> 'key',
      (v_check ->> 'capacity')::double precision,
      (v_check ->> 'refill_per_hour')::double precision,
      COALESCE((v_check ->> 'cost')::double precision, 1.0)
    );

    IF NOT v_result.allowed THEN
      v_allowed := false;
      v_retry := GREATEST(v_retry, v_result.retry_after_seconds);
    END IF;
  END LOOP;

  IF NOT v_allowed THEN
    RETURN QUERY SELECT false, v_retry;
    RETURN;
  END IF;

  FOR v_check IN
    SELECT elem.value
    FROM jsonb_array_elements(p_checks) AS elem(value)
    ORDER BY elem.value ->> 'key'
  LOOP
    PERFORM public.consume_rate_limit(
      v_check ->> 'key',
      (v_check ->> 'capacity')::double precision,
      (v_check ->> 'refill_per_hour')::double precision,
      COALESCE((v_check ->> 'cost')::double precision, 1.0)
    );
  END LOOP;

  RETURN QUERY SELECT true, 0;
END;
$$;

COMMENT ON FUNCTION public.consume_rate_limits IS
  'Stage 8.7 — evaluate many buckets; deny if any would fail; else consume all.';

-- ----------------------------------------------------------------------------
-- invite_send_queue — paused work when global breaker trips
-- ----------------------------------------------------------------------------

CREATE TABLE public.invite_send_queue (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid        REFERENCES public.workspaces (id) ON DELETE CASCADE,
  kind          text        NOT NULL,
  payload       jsonb       NOT NULL DEFAULT '{}'::jsonb,
  status        text        NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending', 'sent', 'cancelled')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  available_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_invite_send_queue_status_available
  ON public.invite_send_queue (status, available_at);

COMMENT ON TABLE public.invite_send_queue IS
  'Stage 8.7 — invites paused when the global email/hr circuit breaker trips.';

-- ----------------------------------------------------------------------------
-- ops_alert_events — internal ops log (no external pager in this band)
-- ----------------------------------------------------------------------------

CREATE TABLE public.ops_alert_events (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_type  text        NOT NULL,
  detail      jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_ops_alert_events_type_created
  ON public.ops_alert_events (alert_type, created_at DESC);

COMMENT ON TABLE public.ops_alert_events IS
  'Stage 8.7 — internal alert log for circuit-breaker and ops events.';

-- ----------------------------------------------------------------------------
-- RLS + grants (Edge Function service_role only)
-- ----------------------------------------------------------------------------

ALTER TABLE public.invite_send_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ops_alert_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY invite_send_queue_deny_all
  ON public.invite_send_queue FOR ALL
  USING (false);

CREATE POLICY ops_alert_events_deny_all
  ON public.ops_alert_events FOR ALL
  USING (false);

REVOKE ALL ON public.invite_send_queue FROM anon, authenticated;
REVOKE ALL ON public.ops_alert_events FROM anon, authenticated;

GRANT SELECT, INSERT, UPDATE ON public.invite_send_queue TO service_role;
GRANT SELECT, INSERT ON public.ops_alert_events TO service_role;

REVOKE ALL ON FUNCTION public.peek_rate_limit(text, double precision, double precision, double precision)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.consume_rate_limit(text, double precision, double precision, double precision)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.consume_rate_limits(jsonb)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.peek_rate_limit(text, double precision, double precision, double precision)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.consume_rate_limit(text, double precision, double precision, double precision)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.consume_rate_limits(jsonb)
  TO service_role;
