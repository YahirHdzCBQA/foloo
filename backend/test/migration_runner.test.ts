/** Transaction, retry and concurrency coverage for the schema migration runner. */

import assert from "node:assert/strict";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import type pg from "pg";

import { applyMigrations } from "../src/persistence/migration_runner.js";

type FailurePoint = "migration" | "record" | "commit";

async function fixture(options?: {
  failure?: FailurePoint;
  lockAvailable?: boolean;
}) {
  const directory = await mkdtemp(join(tmpdir(), "foloo-migrations-"));
  await writeFile(join(directory, "009_a.sql"), "-- 009_a.sql");
  await writeFile(join(directory, "010_b.sql"), "-- 010_b.sql");
  await writeFile(
    join(directory, "011_c.sql"),
    "BEGIN;\n-- 011_c.sql\nCOMMIT;\n",
  );
  const applied = new Set(["009_a.sql"]);
  const executed: string[] = [];
  let inTransaction = false;
  let stagedMigration: string | undefined;
  let stagedRecord: string | undefined;
  let failure = options?.failure;
  const client = {
    async query<Row extends Record<string, unknown> = Record<string, unknown>>(
      sql: string,
      params?: string[],
    ) {
      if (sql.startsWith("SELECT pg_try_advisory_lock"))
        return {
          rows: [
            { acquired: options?.lockAvailable !== false } as unknown as Row,
          ],
          rowCount: 1,
        };
      if (sql.startsWith("SELECT pg_advisory_unlock"))
        return { rows: [], rowCount: 1 };
      if (sql === "BEGIN") {
        inTransaction = true;
        return { rows: [], rowCount: 0 };
      }
      if (sql === "COMMIT") {
        if (failure === "commit" && stagedRecord) {
          failure = undefined;
          throw new Error("synthetic commit failure");
        }
        if (stagedMigration) executed.push(stagedMigration);
        if (stagedRecord) applied.add(stagedRecord);
        stagedMigration = undefined;
        stagedRecord = undefined;
        inTransaction = false;
        return { rows: [], rowCount: 0 };
      }
      if (sql === "ROLLBACK") {
        stagedMigration = undefined;
        stagedRecord = undefined;
        inTransaction = false;
        return { rows: [], rowCount: 0 };
      }
      if (sql.startsWith("SELECT 1 FROM schema_migrations"))
        return { rows: [], rowCount: applied.has(params![0]!) ? 1 : 0 };
      if (sql.startsWith("INSERT INTO schema_migrations")) {
        if (failure === "record") {
          failure = undefined;
          throw new Error("synthetic record failure");
        }
        stagedRecord = params![0];
        return { rows: [], rowCount: 1 };
      }
      if (sql.startsWith("-- ")) {
        assert.equal(inTransaction, true);
        if (failure === "migration") {
          failure = undefined;
          throw new Error("synthetic migration failure");
        }
        stagedMigration = sql.slice(3).trim();
      }
      return { rows: [], rowCount: 0 };
    },
    release() {},
  };
  const pool = { connect: async () => client } as unknown as pg.Pool;
  return { directory, pool, applied, executed };
}

test("applies one migration and keeps legacy wrappers in the runner transaction", async () => {
  const { directory, pool, applied, executed } = await fixture();
  assert.deepEqual(await applyMigrations(pool, directory, "011_c.sql"), [
    "011_c.sql",
  ]);
  assert.deepEqual(executed, ["011_c.sql"]);
  assert.equal(applied.has("010_b.sql"), false);
  assert.deepEqual(await applyMigrations(pool, directory, "011_c.sql"), []);
  assert.deepEqual(await applyMigrations(pool, directory), ["010_b.sql"]);
});

test("migration and audit record roll back together and retry once", async () => {
  for (const failure of ["migration", "record", "commit"] as const) {
    const { directory, pool, applied, executed } = await fixture({ failure });
    await assert.rejects(
      applyMigrations(pool, directory, "010_b.sql"),
      /synthetic/,
    );
    assert.equal(applied.has("010_b.sql"), false);
    assert.deepEqual(executed, []);
    assert.deepEqual(await applyMigrations(pool, directory, "010_b.sql"), [
      "010_b.sql",
    ]);
    assert.equal(applied.has("010_b.sql"), true);
    assert.deepEqual(executed, ["010_b.sql"]);
  }
});

test("fails closed while another runner holds the advisory lock", async () => {
  const { directory, pool, executed } = await fixture({
    lockAvailable: false,
  });
  await assert.rejects(applyMigrations(pool, directory), /already running/);
  assert.deepEqual(executed, []);
});

test("rejects an unknown named migration", async () => {
  const { directory, pool, executed } = await fixture();
  await assert.rejects(
    applyMigrations(pool, directory, "999_missing.sql"),
    /does not exist/,
  );
  assert.deepEqual(executed, []);
});
