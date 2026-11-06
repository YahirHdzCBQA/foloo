/** Verifies migration invariants that protect tenancy and sync preparation. */

import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const migrationUrl = new URL("../migrations/001_initial.sql", import.meta.url);
const mediaMigrationUrl = new URL(
  "../migrations/002_media_upload_state.sql",
  import.meta.url,
);
const contentMigrationUrl = new URL(
  "../migrations/003_content_pdf.sql",
  import.meta.url,
);
const entitlementMigrationUrl = new URL(
  "../migrations/007_trial_entitlements.sql",
  import.meta.url,
);
const trialFoundationMigrationUrl = new URL(
  "../migrations/012_trial_subscription_foundation.sql",
  import.meta.url,
);

test("migration scopes resource foreign keys by workspace and excludes blobs", async () => {
  const sql = await readFile(migrationUrl, "utf8");
  assert.match(
    sql,
    /FOREIGN KEY \(workspace_id, event_id\) REFERENCES events\(workspace_id, id\)/,
  );
  assert.match(
    sql,
    /FOREIGN KEY \(workspace_id, lead_id\) REFERENCES leads\(workspace_id, id\)/,
  );
  assert.match(sql, /revision bigint NOT NULL DEFAULT 1/);
  assert.match(sql, /deleted_at timestamptz/);
  assert.doesNotMatch(sql, /\b(bytea|blob)\b/i);
});

test("migration defines idempotency and subject provisioning constraints", async () => {
  const sql = await readFile(migrationUrl, "utf8");
  assert.match(sql, /cognito_sub text NOT NULL UNIQUE/);
  assert.match(sql, /one_personal_account_per_user/);
  assert.match(sql, /PRIMARY KEY \(workspace_id, operation, idempotency_key\)/);
  assert.match(sql, /pg_advisory_xact_lock\(hashtext\(p_subject\)\)/);
});

test("FL-016 migration adds explicit pending/available media state without blobs", async () => {
  const sql = await readFile(mediaMigrationUrl, "utf8");
  assert.match(sql, /upload_status text NOT NULL DEFAULT 'pending'/);
  assert.match(sql, /uploaded_at timestamptz/);
  assert.match(sql, /storage_object_key IS NOT NULL/);
  assert.doesNotMatch(sql, /bytea|large object/i);
});

test("FL-018 constrains each PDF and freezes Lead Content without destructive cascade", async () => {
  const sql = await readFile(contentMigrationUrl, "utf8");
  assert.match(sql, /byte_size BETWEEN 1 AND 25000000/);
  assert.match(sql, /content_file_ids uuid\[\]/);
  assert.match(sql, /content_names text\[\]/);
  assert.doesNotMatch(sql, /DELETE FROM|ON DELETE CASCADE|bytea/i);
});

test("FL-020 stores constrained historical trial consumption on accounts", async () => {
  const sql = await readFile(entitlementMigrationUrl, "utf8");
  assert.match(
    sql,
    /subscription_status IN \('trial', 'trial_exhausted', 'active', 'expired'\)/,
  );
  assert.match(sql, /trial_leads_used BETWEEN 0 AND 5/);
  assert.match(sql, /LEAST\(COUNT\(l\.id\), 5\)/);
  assert.doesNotMatch(sql, /DELETE FROM leads|DROP TABLE|DROP COLUMN/i);
});

test("FL-021 MON-16 migration provides atomic deduplication without deleting data", async () => {
  const sql = await readFile(
    new URL("../migrations/011_billing_stripe.sql", import.meta.url),
    "utf8",
  );
  assert.match(sql, /BEGIN;/);
  assert.match(sql, /COMMIT;/);
  assert.match(sql, /stripe_customer_id text UNIQUE/);
  assert.match(sql, /stripe_subscription_id text/);
  assert.match(sql, /billing_event_at timestamptz/);
  assert.match(sql, /REVOKE UPDATE, DELETE ON billing_events FROM foloo_app/);
  assert.doesNotMatch(
    sql,
    /^GRANT[^;]*(UPDATE|DELETE)[^;]*ON billing_events/im,
  );
  assert.match(sql, /current_period_end timestamptz/);
  assert.match(sql, /event_id text PRIMARY KEY/);
  assert.match(sql, /GRANT SELECT, INSERT ON billing_events TO foloo_app/);
  assert.doesNotMatch(sql, /DELETE FROM|DROP TABLE|DROP COLUMN/i);
});

test("FL-021 adds auditable grants and one durable fifth-lead event", async () => {
  const sql = await readFile(trialFoundationMigrationUrl, "utf8");
  assert.match(sql, /CREATE TABLE entitlement_grants/);
  assert.match(sql, /migration 012 requires migrations 010 and 011/);
  assert.match(sql, /one_active_administrative_grant_per_account/);
  assert.match(sql, /CREATE TABLE entitlement_grant_audit/);
  assert.match(sql, /previous_subscription_status text NOT NULL/);
  assert.match(sql, /previous_entitlement_source text NOT NULL/);
  assert.match(sql, /UNIQUE \(account_id, event_type\)/);
  assert.match(sql, /trial\.fifth_lead_reached\.v1/);
  assert.match(sql, /delivery_status IN \('pending', 'failed'\)/);
  assert.doesNotMatch(sql, /^\s*(BEGIN|COMMIT);/gim);
  assert.match(
    sql,
    /REVOKE ALL PRIVILEGES ON entitlement_grants FROM foloo_app/,
  );
  assert.match(
    sql,
    /ALTER DEFAULT PRIVILEGES IN SCHEMA public\s+REVOKE ALL PRIVILEGES ON TABLES FROM foloo_app/,
  );
  assert.match(sql, /CREATE ROLE foloo_entitlement_admin NOLOGIN/);
  assert.match(
    sql,
    /migration 012 requires the dedicated foloo_entitlement_operator login/,
  );
  assert.match(
    sql,
    /GRANT foloo_entitlement_admin TO foloo_entitlement_operator/,
  );
  assert.doesNotMatch(sql, /GRANT foloo_entitlement_admin TO CURRENT_USER/);
  assert.match(
    sql,
    /GRANT SELECT, INSERT ON entitlement_grant_audit TO foloo_entitlement_admin/,
  );
  assert.doesNotMatch(
    sql,
    /GRANT[^;]*(INSERT|UPDATE|DELETE)[^;]*ON entitlement_grants TO foloo_app/i,
  );
  assert.doesNotMatch(sql, /DELETE FROM|DROP TABLE|DROP COLUMN/i);
});
