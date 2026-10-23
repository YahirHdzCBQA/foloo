import assert from "node:assert/strict";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import type pg from "pg";

import { applyMigrations } from "../src/persistence/migration_runner.js";

async function fixture() {
  const directory = await mkdtemp(join(tmpdir(), "foloo-migrations-"));
  for (const name of ["009_a.sql", "010_b.sql", "011_c.sql"])
    await writeFile(join(directory, name), `-- ${name}`);
  const applied = new Set(["009_a.sql"]);
  const executed: string[] = [];
  const client = {
    async query(sql: string, params?: string[]) {
      if (sql.startsWith("SELECT 1 FROM schema_migrations"))
        return { rowCount: applied.has(params![0]!) ? 1 : 0 };
      if (sql.startsWith("INSERT INTO schema_migrations"))
        applied.add(params![0]!);
      else if (sql.startsWith("-- ")) executed.push(sql.slice(3));
      return { rowCount: 0 };
    },
    release() {},
  };
  const pool = { connect: async () => client } as unknown as pg.Pool;
  return { directory, pool, applied, executed };
}

test("MON-16 applies only the named migration and leaves earlier pending ones", async () => {
  const { directory, pool, applied, executed } = await fixture();
  assert.deepEqual(await applyMigrations(pool, directory, "011_c.sql"), [
    "011_c.sql",
  ]);
  assert.deepEqual(executed, ["011_c.sql"]);
  assert.equal(applied.has("010_b.sql"), false);
  assert.deepEqual(await applyMigrations(pool, directory, "011_c.sql"), []);
  assert.deepEqual(await applyMigrations(pool, directory), ["010_b.sql"]);
});

test("rejects an unknown named migration", async () => {
  const { directory, pool, executed } = await fixture();
  await assert.rejects(
    applyMigrations(pool, directory, "999_missing.sql"),
    /does not exist/,
  );
  assert.deepEqual(executed, []);
});
