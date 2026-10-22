-- Read-only verification for STORE-02 migration 010.
SELECT name, applied_at
FROM schema_migrations
WHERE name = '010_account_deletion_write_fence.sql';

SELECT c.relname AS table_name, t.tgname AS trigger_name,
       pg_get_triggerdef(t.oid) AS definition
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND t.tgname = 'account_deletion_write_fence'
  AND NOT t.tgisinternal
ORDER BY c.relname;

SELECT proname, pg_get_function_identity_arguments(oid) AS arguments
FROM pg_proc
WHERE proname IN (
  'account_owner_subject_for_workspace',
  'fence_account_owner_write',
  'fence_workspace_owner_write',
  'fence_account_row_owner_write',
  'fence_workspace_row_owner_write',
  'fence_membership_owner_write'
)
ORDER BY proname;
