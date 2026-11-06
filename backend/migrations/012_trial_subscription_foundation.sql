-- FL-021 / MON-01–MON-12: auditable administrative grants and durable 5/5 milestone.
-- The migration runner owns the transaction and records this file atomically.

DO $foloo$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM schema_migrations
    WHERE name = '010_account_deletion_write_fence.sql'
  ) OR NOT EXISTS (
    SELECT 1 FROM schema_migrations
    WHERE name = '011_billing_stripe.sql'
  ) THEN
    RAISE EXCEPTION 'migration 012 requires migrations 010 and 011';
  END IF;
END
$foloo$;

ALTER TABLE accounts
  ADD COLUMN entitlement_source text NOT NULL DEFAULT 'trial'
    CHECK (entitlement_source IN ('trial', 'administrative', 'stripe', 'legacy_active'));

UPDATE accounts
SET entitlement_source = CASE
  WHEN subscription_status <> 'active' THEN 'trial'
  WHEN stripe_subscription_id IS NOT NULL THEN 'stripe'
  ELSE 'legacy_active'
END;

CREATE TABLE entitlement_grants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  source text NOT NULL CHECK (source = 'administrative'),
  status text NOT NULL CHECK (status IN ('active', 'revoked')),
  granted_by text NOT NULL CHECK (length(trim(granted_by)) BETWEEN 1 AND 160),
  reason text NOT NULL CHECK (length(trim(reason)) BETWEEN 1 AND 500),
  previous_subscription_status text NOT NULL
    CHECK (previous_subscription_status IN ('trial', 'trial_exhausted')),
  previous_entitlement_source text NOT NULL
    CHECK (previous_entitlement_source = 'trial'),
  granted_at timestamptz NOT NULL DEFAULT now(),
  revoked_by text,
  revoked_reason text,
  revoked_at timestamptz,
  CHECK (
    (status = 'active' AND revoked_by IS NULL AND revoked_reason IS NULL AND revoked_at IS NULL)
    OR
    (status = 'revoked' AND revoked_by IS NOT NULL AND revoked_reason IS NOT NULL AND revoked_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX one_active_administrative_grant_per_account
  ON entitlement_grants(account_id)
  WHERE status = 'active';

CREATE TABLE entitlement_grant_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  grant_id uuid NOT NULL REFERENCES entitlement_grants(id) ON DELETE CASCADE,
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  action text NOT NULL CHECK (action IN ('granted', 'revoked')),
  actor text NOT NULL CHECK (length(trim(actor)) BETWEEN 1 AND 160),
  reason text NOT NULL CHECK (length(trim(reason)) BETWEEN 1 AND 500),
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE trial_milestone_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type = 'trial.fifth_lead_reached.v1'),
  lead_id uuid NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  delivery_status text NOT NULL DEFAULT 'pending'
    CHECK (delivery_status IN ('pending', 'in_flight', 'accepted', 'delivered', 'failed', 'disabled')),
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  next_attempt_at timestamptz,
  provider_message_id text,
  last_error_code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  accepted_at timestamptz,
  delivered_at timestamptz,
  UNIQUE (account_id, event_type)
);

CREATE INDEX trial_milestone_delivery_due_idx
  ON trial_milestone_events(delivery_status, next_attempt_at)
  WHERE delivery_status IN ('pending', 'failed');

-- New account-scoped writes participate in the STORE-02D owner fence.
CREATE TRIGGER account_deletion_write_fence
BEFORE INSERT OR UPDATE ON entitlement_grants
FOR EACH ROW EXECUTE FUNCTION fence_workspace_row_owner_write();

CREATE TRIGGER account_deletion_write_fence
BEFORE INSERT OR UPDATE ON entitlement_grant_audit
FOR EACH ROW EXECUTE FUNCTION fence_workspace_row_owner_write();

CREATE TRIGGER account_deletion_write_fence
BEFORE INSERT OR UPDATE ON trial_milestone_events
FOR EACH ROW EXECUTE FUNCTION fence_workspace_row_owner_write();

-- Migration 001 granted broad default table privileges to the application
-- role. Administrative entitlement state is a private operator boundary, so
-- revoke those inherited privileges explicitly and grant it to a separate
-- NOLOGIN role used through SET LOCAL ROLE by the authenticated operator.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL PRIVILEGES ON TABLES FROM foloo_app;
REVOKE ALL PRIVILEGES ON entitlement_grants FROM foloo_app;
REVOKE ALL PRIVILEGES ON entitlement_grant_audit FROM foloo_app;

DO $foloo$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'foloo_entitlement_admin') THEN
    CREATE ROLE foloo_entitlement_admin NOLOGIN;
  END IF;
END
$foloo$;

ALTER ROLE foloo_entitlement_admin NOLOGIN NOINHERIT;

DO $foloo$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'foloo_entitlement_operator') THEN
    RAISE EXCEPTION 'migration 012 requires the dedicated foloo_entitlement_operator login';
  END IF;
END
$foloo$;

GRANT USAGE ON SCHEMA public TO foloo_entitlement_admin;
GRANT SELECT ON app_users, accounts TO foloo_entitlement_admin;
GRANT UPDATE (subscription_status, entitlement_source,
  entitlement_updated_at, updated_at) ON accounts TO foloo_entitlement_admin;
GRANT SELECT, INSERT, UPDATE ON entitlement_grants TO foloo_entitlement_admin;
GRANT SELECT, INSERT ON entitlement_grant_audit TO foloo_entitlement_admin;
GRANT foloo_entitlement_admin TO foloo_entitlement_operator;

-- API creation and the disabled notification worker need only these actions.
REVOKE ALL PRIVILEGES ON trial_milestone_events FROM foloo_app;
GRANT SELECT, INSERT, UPDATE ON trial_milestone_events TO foloo_app;
