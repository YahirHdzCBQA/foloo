import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import test from "node:test";

test("FL-019 migration is additive and scopes mail entities", async () => {
  const sql = await readFile(
    join(import.meta.dirname, "../migrations/004_email_foundation.sql"),
    "utf8",
  );
  for (const table of [
    "email_templates",
    "email_connections",
    "email_oauth_states",
    "email_opt_outs",
    "email_unsubscribe_tokens",
    "email_follow_ups",
    "email_send_intents",
  ]) {
    assert.match(sql, new RegExp(`CREATE TABLE ${table} \\(`));
  }
  assert.match(sql, /UNIQUE \(workspace_id, id\)/);
  assert.match(sql, /FOREIGN KEY \(workspace_id, lead_id\)/);
  assert.match(sql, /confirmation_required/);
  assert.doesNotMatch(sql, /\bDROP\s+(TABLE|COLUMN)\b/i);
});
