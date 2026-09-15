/** Verifies migration invariants that protect tenancy and sync preparation. */

import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const migrationUrl = new URL("../migrations/001_initial.sql", import.meta.url);
const mediaMigrationUrl = new URL(
  "../migrations/002_media_upload_state.sql",
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
