-- Read-only preflight for STORE-02 migration 010.
SELECT name, applied_at
FROM schema_migrations
WHERE name = '010_account_deletion_write_fence.sql';

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'accounts', 'workspaces', 'workspace_members', 'seller_profiles',
    'events', 'leads', 'lead_media', 'content_files', 'idempotency_records',
    'email_templates', 'event_email_templates', 'email_connections',
    'email_oauth_states', 'email_opt_outs', 'email_owner_opt_outs',
    'email_unsubscribe_tokens', 'email_follow_ups', 'email_send_intents'
  )
ORDER BY table_name;

SELECT proname
FROM pg_proc
WHERE proname IN ('assert_account_active', 'mark_account_deletion_pending')
ORDER BY proname;
