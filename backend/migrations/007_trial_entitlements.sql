-- FL-020: server-authoritative historical trial consumption per account.
BEGIN;

ALTER TABLE accounts
  ADD COLUMN subscription_status text NOT NULL DEFAULT 'trial'
    CHECK (subscription_status IN ('trial', 'trial_exhausted', 'active', 'expired')),
  ADD COLUMN trial_leads_used integer NOT NULL DEFAULT 0
    CHECK (trial_leads_used BETWEEN 0 AND 5),
  ADD COLUMN entitlement_updated_at timestamptz NOT NULL DEFAULT now();

-- Preserve historical consumption for accounts that already own Leads.
WITH historical AS (
  SELECT w.account_id, LEAST(COUNT(l.id), 5)::integer AS used
  FROM workspaces w
  LEFT JOIN leads l ON l.workspace_id = w.id
  WHERE w.deleted_at IS NULL
  GROUP BY w.account_id
)
UPDATE accounts a
SET trial_leads_used = historical.used,
    subscription_status = CASE WHEN historical.used >= 5
      THEN 'trial_exhausted' ELSE 'trial' END,
    entitlement_updated_at = now()
FROM historical
WHERE a.id = historical.account_id;

COMMIT;
