-- Read-only preflight for STORE-02 migration 009. Run with an account that
-- cannot write; every row must be reviewed before invoking MigrationFunction.
SELECT current_database() AS database_name,
       current_user AS database_user,
       pg_is_in_recovery() AS is_replica;

SELECT name, applied_at
FROM schema_migrations
WHERE name = '009_account_deletion_barrier.sql';

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'app_users'
  AND column_name IN ('cognito_sub', 'deletion_request_id', 'deletion_pending_at')
ORDER BY column_name;

SELECT count(*) AS duplicate_subjects
FROM (
  SELECT cognito_sub
  FROM app_users
  GROUP BY cognito_sub
  HAVING count(*) > 1
) duplicates;
