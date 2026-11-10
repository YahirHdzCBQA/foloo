-- CAP-03 / E-03: a Lead requires a name and at least one direct contact;
-- company remains useful context but is not required to preserve the capture.
SET LOCAL lock_timeout = '5s';

ALTER TABLE leads
  ALTER COLUMN company DROP NOT NULL;

ALTER TABLE leads
  DROP CONSTRAINT IF EXISTS leads_company_check;

ALTER TABLE leads
  ADD CONSTRAINT leads_company_check
  CHECK (company IS NULL OR length(company) BETWEEN 1 AND 160);
