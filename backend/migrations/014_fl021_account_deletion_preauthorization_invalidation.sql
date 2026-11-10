-- FL-021 / STORE-02D: invalidate active and consumed preauthorizations while
-- the verified deletion owner is still available. The runner owns transaction.

DO $foloo$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM schema_migrations
    WHERE name = '013_fl021_entitlement_preauthorizations.sql'
  ) THEN
    RAISE EXCEPTION 'migration 014 requires migration 013';
  END IF;
END
$foloo$;

CREATE OR REPLACE FUNCTION revoke_account_entitlement_preauthorizations(
  p_account_id uuid,
  p_key_versions text[],
  p_email_digests text[]
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $foloo$
DECLARE
  v_revoked integer;
BEGIN
  IF p_account_id IS NULL
     OR cardinality(p_key_versions) IS NULL
     OR cardinality(p_key_versions) = 0
     OR cardinality(p_key_versions) > 16
     OR cardinality(p_key_versions) <> cardinality(p_email_digests)
     OR EXISTS (
       SELECT 1
       FROM unnest(p_key_versions, p_email_digests)
         AS selector(key_version, email_digest)
       WHERE selector.key_version !~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'
          OR selector.email_digest !~ '^[A-Za-z0-9_-]{43}$'
     )
  THEN
    RAISE EXCEPTION 'account_deletion_selector_set_invalid'
      USING ERRCODE = '22023';
  END IF;

  -- This lock serializes deletion against account-scoped entitlement changes.
  PERFORM 1
  FROM public.accounts a
  JOIN public.app_users u ON u.id = a.owner_user_id
  WHERE a.id = p_account_id AND u.deletion_pending_at IS NOT NULL
  FOR UPDATE OF a, u;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'account_deletion_barrier_not_established'
      USING ERRCODE = 'P0001';
  END IF;

  WITH revoked AS (
    UPDATE public.entitlement_preauthorizations AS preauthorization
    SET status = 'revoked',
        bound_account_id = NULL,
        revoked_by = 'system:account-deletion',
        revoked_reason = 'Account deletion invalidated preauthorization',
        revoked_at = now()
    WHERE
      (preauthorization.status = 'consumed'
       AND preauthorization.bound_account_id = p_account_id)
      OR
      (preauthorization.status = 'active' AND EXISTS (
        SELECT 1
        FROM unnest(p_key_versions, p_email_digests)
          AS selector(key_version, email_digest)
        WHERE selector.key_version = preauthorization.key_version
          AND selector.email_digest = preauthorization.email_digest
      ))
    RETURNING preauthorization.id
  ), audited AS (
    INSERT INTO public.entitlement_preauthorization_audit
      (preauthorization_id, account_id, action, actor, reason)
    SELECT id, p_account_id, 'revoked', 'system:account-deletion',
      'Account deletion invalidated preauthorization'
    FROM revoked
    RETURNING 1
  )
  SELECT count(*)::integer INTO v_revoked FROM audited;

  RETURN v_revoked;
END
$foloo$;

REVOKE ALL ON FUNCTION revoke_account_entitlement_preauthorizations(
  uuid, text[], text[]
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION revoke_account_entitlement_preauthorizations(
  uuid, text[], text[]
) TO foloo_app;
