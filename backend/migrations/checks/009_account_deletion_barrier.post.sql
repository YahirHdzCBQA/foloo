-- Read-only verification for STORE-02 migration 009.
SELECT name, applied_at
FROM schema_migrations
WHERE name = '009_account_deletion_barrier.sql';

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'app_users'
  AND column_name IN ('deletion_request_id', 'deletion_pending_at')
ORDER BY column_name;

SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'app_users'::regclass
  AND conname = 'app_users_deletion_barrier_consistent';

SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'app_users'
  AND indexname = 'app_users_deletion_request_unique';

SELECT proname, pg_get_function_identity_arguments(oid) AS arguments
FROM pg_proc
WHERE proname IN (
  'assert_account_active',
  'mark_account_deletion_pending',
  'ensure_personal_workspace'
)
ORDER BY proname;

SELECT count(*) AS inconsistent_barriers
FROM app_users
WHERE (deletion_request_id IS NULL) <> (deletion_pending_at IS NULL);
