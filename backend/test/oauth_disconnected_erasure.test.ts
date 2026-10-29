/** INF-15 / RNF-09, E-14: disconnected grants are destroyed locally only. */
import assert from "node:assert/strict";
import test from "node:test";
import { PostgresOAuthErasure } from "../src/account_deletion/postgres_oauth_erasure.js";

function fixture(statuses: string[]) {
  let rows = statuses.map((status, i) => ({
    status,
    workspace_id: `synthetic-${i}`,
    provider: "google",
    encrypted_credentials: Buffer.from("synthetic-ciphertext"),
  }));
  const sql: string[] = [];
  const revoked: string[] = [];
  let failSql = false;
  let failProvider = false;
  let negativeProvider = false;
  let releases = 0;
  const pool = {
    async query(query: string, values: string[]) {
      assert.deepEqual(values, ["synthetic-owner"]);
      assert.match(query, /u.cognito_sub=\$1/);
      if (query.includes("SELECT EXISTS"))
        return { rows: [{ exists: rows.length > 0 }] };
      return { rows };
    },
    async connect() {
      return {
        async query(query: string, values?: string[]) {
          sql.push(query);
          if (query.startsWith("DELETE"))
            assert.deepEqual(values, ["synthetic-owner"]);
          if (failSql && query.includes("DELETE FROM email_connections"))
            throw new Error("synthetic SQL failure");
          if (query === "COMMIT") rows = [];
          return { rows: [] };
        },
        release() {
          releases++;
        },
      };
    },
  };
  const provider = {
    async invoke(command: { workspaceId: string; action: string }) {
      assert.equal(command.action, "revoke");
      revoked.push(command.workspaceId);
      if (failProvider) throw new Error("synthetic provider failure");
      return { revoked: !negativeProvider };
    },
  };
  const erasure = new PostgresOAuthErasure(pool as never, provider as never);
  return {
    erasure,
    sql,
    revoked,
    setSqlFailure: (v: boolean) => {
      failSql = v;
    },
    setProviderFailure: (v: boolean) => {
      failProvider = v;
    },
    setNegative: () => {
      negativeProvider = true;
    },
    releases: () => releases,
  };
}

for (const status of ["connected", "reconnect_required"]) {
  test(`${status} still requires external revocation`, async () => {
    const f = fixture([status]);
    await f.erasure.revokeAndDestroy("synthetic-owner");
    assert.equal(f.revoked.length, 1);
    assert.equal(await f.erasure.isDestroyed("synthetic-owner"), true);
  });
}
test("disconnected destroys credentials, states and intents without invoking provider; retry is idempotent", async () => {
  const f = fixture(["disconnected"]);
  await f.erasure.revokeAndDestroy("synthetic-owner");
  assert.equal(f.revoked.length, 0);
  for (const table of [
    "email_send_intents",
    "email_oauth_states",
    "email_connections",
  ])
    assert.ok(f.sql.some((s) => s.includes(`DELETE FROM ${table}`)));
  assert.equal(await f.erasure.isDestroyed("synthetic-owner"), true);
  await f.erasure.revokeAndDestroy("synthetic-owner");
  assert.equal(f.revoked.length, 0);
});
test("mixed connections only revoke active and reconnect-required grants", async () => {
  const f = fixture(["disconnected", "connected", "reconnect_required"]);
  await f.erasure.revokeAndDestroy("synthetic-owner");
  assert.deepEqual(f.revoked, ["synthetic-1", "synthetic-2"]);
});
test("unknown status fails before revocation or SQL deletion", async () => {
  const f = fixture(["connected", "unrecognized"]);
  await assert.rejects(
    f.erasure.revokeAndDestroy("synthetic-owner"),
    /state is not supported/,
  );
  assert.deepEqual(f.revoked, []);
  assert.deepEqual(f.sql, []);
});
test("provider failure retains rows; retry must revoke active connection again", async () => {
  const f = fixture(["connected", "disconnected"]);
  f.setProviderFailure(true);
  await assert.rejects(
    f.erasure.revokeAndDestroy("synthetic-owner"),
    /provider failure/,
  );
  assert.deepEqual(f.sql, []);
  assert.equal(await f.erasure.isDestroyed("synthetic-owner"), false);
  f.setProviderFailure(false);
  await f.erasure.revokeAndDestroy("synthetic-owner");
  assert.deepEqual(f.revoked, ["synthetic-0", "synthetic-0"]);
});
test("negative revocation acknowledgement blocks local deletion", async () => {
  const f = fixture(["connected"]);
  f.setNegative();
  await assert.rejects(
    f.erasure.revokeAndDestroy("synthetic-owner"),
    /did not confirm/,
  );
  assert.deepEqual(f.sql, []);
});
test("SQL failure rolls back disconnected cleanup; retry never revokes externally", async () => {
  const f = fixture(["disconnected"]);
  f.setSqlFailure(true);
  await assert.rejects(
    f.erasure.revokeAndDestroy("synthetic-owner"),
    /SQL failure/,
  );
  assert.equal(f.sql.at(-1), "ROLLBACK");
  assert.equal(f.releases(), 1);
  assert.equal(await f.erasure.isDestroyed("synthetic-owner"), false);
  f.setSqlFailure(false);
  await f.erasure.revokeAndDestroy("synthetic-owner");
  assert.deepEqual(f.revoked, []);
  assert.equal(await f.erasure.isDestroyed("synthetic-owner"), true);
});
