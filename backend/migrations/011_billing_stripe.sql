-- FL-021 / MON-15–MON-18: Stripe identity and atomic webhook deduplication.
BEGIN;
ALTER TABLE accounts
  ADD COLUMN stripe_customer_id text UNIQUE,
  ADD COLUMN stripe_subscription_id text,
  ADD COLUMN billing_event_at timestamptz,
  ADD COLUMN current_period_end timestamptz;
CREATE TABLE billing_events (
  event_id text PRIMARY KEY,
  type text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now()
);
-- Migration 001 grants future tables UPDATE/DELETE by default; remove inherited grants.
REVOKE UPDATE, DELETE ON billing_events FROM foloo_app;
GRANT SELECT, INSERT ON billing_events TO foloo_app;
COMMIT;
