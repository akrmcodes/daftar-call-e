-- ============================================================================
-- Grant service_role DML on sync tables for Edge Functions (push/pull-sync-ops)
-- ============================================================================
-- push-sync-ops and pull-sync-ops use ctx.supabaseAdmin (service_role).
-- Band A RLS hardening left service_role with only TRUNCATE/REFERENCES/TRIGGER
-- on client tables — causing 42501 "permission denied" on audit_logs SELECT.

GRANT SELECT, INSERT, UPDATE, DELETE ON public.audit_logs TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ledgers TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.contacts TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.transactions TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.contact_balances TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.workspace_devices TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.sync_usage_counters TO service_role;
GRANT SELECT ON public.workspace_members TO service_role;
