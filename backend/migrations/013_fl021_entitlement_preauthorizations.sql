-- FL-021 / MON-21: pseudonymous, auditable PRO preauthorizations.
-- The migration runner owns the transaction and records this file atomically.

DO $foloo$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM schema_migrations
    WHERE name = '012_trial_subscription_foundation.sql'
  ) THEN
    RAISE EXCEPTION 'migration 013 requires migration 012';
  END IF;
END
$foloo$;

ALTER TABLE entitlement_grants
  ADD COLUMN grant_origin text NOT NULL DEFAULT 'manual'
    CHECK (grant_origin IN ('manual', 'preauthorization'));

ALTER TABLE entitlement_grant_audit
  ADD COLUMN grant_origin text NOT NULL DEFAULT 'manual'
    CHECK (grant_origin IN ('manual', 'preauthorization'));

CREATE TABLE entitlement_preauthorizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key_version text NOT NULL
    CHECK (key_version ~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'),
  canonicalization_policy text NOT NULL
    CHECK (canonicalization_policy = 'foloo-email-v1-provisional'),
  email_digest text NOT NULL CHECK (email_digest ~ '^[A-Za-z0-9_-]{43}$'),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'consumed', 'revoked')),
  authorized_by text NOT NULL
    CHECK (length(trim(authorized_by)) BETWEEN 1 AND 160),
  authorization_reason text NOT NULL
    CHECK (length(trim(authorization_reason)) BETWEEN 1 AND 500),
  bound_account_id uuid REFERENCES accounts(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  consumed_at timestamptz,
  revoked_by text,
  revoked_reason text,
  revoked_at timestamptz,
  last_exception_code text,
  last_exception_at timestamptz,
  UNIQUE (key_version, email_digest),
  CHECK (
    (status = 'active' AND bound_account_id IS NULL
      AND consumed_at IS NULL AND revoked_at IS NULL)
    OR
    (status = 'consumed' AND bound_account_id IS NOT NULL
      AND consumed_at IS NOT NULL AND revoked_at IS NULL)
    OR
    (status = 'revoked' AND revoked_by IS NOT NULL
      AND revoked_reason IS NOT NULL AND revoked_at IS NOT NULL)
  )
);

CREATE INDEX entitlement_preauthorizations_bound_account_idx
  ON entitlement_preauthorizations(bound_account_id)
  WHERE bound_account_id IS NOT NULL;

ALTER TABLE entitlement_grants
  ADD COLUMN preauthorization_id uuid
    REFERENCES entitlement_preauthorizations(id) ON DELETE SET NULL,
  ADD CONSTRAINT entitlement_grant_origin_consistent CHECK (
    (grant_origin = 'manual' AND preauthorization_id IS NULL)
    OR
    (grant_origin = 'preauthorization' AND preauthorization_id IS NOT NULL)
  );

CREATE TABLE entitlement_preauthorization_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  preauthorization_id uuid NOT NULL
    REFERENCES entitlement_preauthorizations(id) ON DELETE CASCADE,
  account_id uuid REFERENCES accounts(id) ON DELETE SET NULL,
  action text NOT NULL
    CHECK (action IN ('preauthorized', 'consumed', 'revoked', 'exception')),
  actor text NOT NULL CHECK (length(trim(actor)) BETWEEN 1 AND 160),
  reason text NOT NULL CHECK (length(trim(reason)) BETWEEN 1 AND 500),
  exception_code text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  CHECK (
    (action = 'exception' AND exception_code IS NOT NULL)
    OR (action <> 'exception' AND exception_code IS NULL)
  )
);

CREATE INDEX entitlement_preauthorization_audit_lookup_idx
  ON entitlement_preauthorization_audit(preauthorization_id, occurred_at);

-- STORE-02D may invalidate only a consumed preauthorization attached to the
-- account whose accepted deletion barrier is present. The application role
-- cannot otherwise mutate this private administrative state.
CREATE OR REPLACE FUNCTION invalidate_consumed_entitlement_preauthorization(
  p_account_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $foloo$
DECLARE
  v_preauthorization_id uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.accounts a
    JOIN public.app_users u ON u.id = a.owner_user_id
    WHERE a.id = p_account_id AND u.deletion_pending_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'account_deletion_barrier_not_established'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.entitlement_preauthorizations
  SET status = 'revoked',
      bound_account_id = NULL,
      revoked_by = 'system:account-deletion',
      revoked_reason = 'Account deletion invalidated consumed preauthorization',
      revoked_at = now()
  WHERE bound_account_id = p_account_id AND status = 'consumed'
  RETURNING id INTO v_preauthorization_id;

  IF v_preauthorization_id IS NOT NULL THEN
    INSERT INTO public.entitlement_preauthorization_audit
      (preauthorization_id, account_id, action, actor, reason)
    VALUES
      (v_preauthorization_id, p_account_id, 'revoked',
       'system:account-deletion',
       'Account deletion invalidated consumed preauthorization');
  END IF;
END
$foloo$;

REVOKE ALL PRIVILEGES ON entitlement_preauthorizations FROM PUBLIC, foloo_app;
REVOKE ALL PRIVILEGES ON entitlement_preauthorization_audit FROM PUBLIC, foloo_app;
REVOKE ALL ON FUNCTION invalidate_consumed_entitlement_preauthorization(uuid)
  FROM PUBLIC;

GRANT SELECT, INSERT, UPDATE ON entitlement_preauthorizations
  TO foloo_entitlement_admin;
GRANT SELECT, INSERT ON entitlement_preauthorization_audit
  TO foloo_entitlement_admin;
GRANT EXECUTE ON FUNCTION invalidate_consumed_entitlement_preauthorization(uuid)
  TO foloo_app;

