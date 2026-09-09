/** Applies ordered SQL migrations with an admin connection and audit table. */

import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";

import type pg from "pg";

const rolePattern = /^[a-z_][a-z0-9_]{0,62}$/;

function sqlLiteral(value: string): string {
  return `'${value.replaceAll("'", "''")}'`;
}

export async function ensureApplicationRole(
  client: pg.PoolClient,
  username: string,
  password: string,
): Promise<void> {
  if (!rolePattern.test(username))
    throw new Error("Application database username is invalid");
  const role = `"${username}"`;
  const secret = sqlLiteral(password);
  await client.query(
    `DO $foloo$ BEGIN
       IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = ${sqlLiteral(username)}) THEN
         EXECUTE 'CREATE ROLE ${role} LOGIN PASSWORD ' || quote_literal(${secret});
       ELSE
         EXECUTE 'ALTER ROLE ${role} PASSWORD ' || quote_literal(${secret});
       END IF;
     END $foloo$;`,
  );
}

export async function applyMigrations(
  pool: pg.Pool,
  directory: string,
): Promise<string[]> {
  const client = await pool.connect();
  try {
    await client.query(
      `CREATE TABLE IF NOT EXISTS schema_migrations (
         name text PRIMARY KEY,
         applied_at timestamptz NOT NULL DEFAULT now()
       )`,
    );
    const files = (await readdir(directory))
      .filter((name) => /^\d+_.*\.sql$/.test(name))
      .sort();
    const applied: string[] = [];
    for (const name of files) {
      const existing = await client.query(
        "SELECT 1 FROM schema_migrations WHERE name = $1",
        [name],
      );
      if (existing.rowCount) continue;
      const sql = await readFile(join(directory, name), "utf8");
      await client.query(sql);
      await client.query("INSERT INTO schema_migrations (name) VALUES ($1)", [
        name,
      ]);
      applied.push(name);
    }
    return applied;
  } finally {
    client.release();
  }
}
