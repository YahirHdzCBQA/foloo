/** Applies ordered SQL migrations with an admin connection and audit table. */

import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";

import type pg from "pg";

const rolePattern = /^[a-z_][a-z0-9_]{0,62}$/;
/** Shared lock identity for migration writes and their read-only preflight. */
export const MIGRATION_ADVISORY_LOCK_NAME = "foloo-schema-migrations-v1";

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
  only?: string,
): Promise<string[]> {
  const client = await pool.connect();
  let lockHeld = false;
  try {
    const lock = await client.query<{ acquired: boolean }>(
      "SELECT pg_try_advisory_lock(hashtext($1)) AS acquired",
      [MIGRATION_ADVISORY_LOCK_NAME],
    );
    if (lock.rows[0]?.acquired !== true)
      throw new Error("Another migration operation is already running");
    lockHeld = true;
    await client.query(
      `CREATE TABLE IF NOT EXISTS schema_migrations (
         name text PRIMARY KEY,
         applied_at timestamptz NOT NULL DEFAULT now()
       )`,
    );
    const files = (await readdir(directory))
      .filter((name) => /^\d+_.*\.sql$/.test(name))
      .filter((name) => only === undefined || name === only)
      .sort();
    if (only !== undefined && files.length === 0)
      throw new Error(`Migration ${only} does not exist`);
    const applied: string[] = [];
    for (const name of files) {
      await client.query("BEGIN");
      try {
        await client.query("SET LOCAL lock_timeout = '5s'");
        await client.query("SET LOCAL statement_timeout = '5min'");
        const existing = await client.query(
          "SELECT 1 FROM schema_migrations WHERE name = $1 FOR UPDATE",
          [name],
        );
        if (existing.rowCount) {
          await client.query("COMMIT");
          continue;
        }
        const sql = stripOuterTransaction(
          await readFile(join(directory, name), "utf8"),
        );
        await client.query(sql);
        await client.query("INSERT INTO schema_migrations (name) VALUES ($1)", [
          name,
        ]);
        await client.query("COMMIT");
        applied.push(name);
      } catch (error) {
        await client.query("ROLLBACK");
        throw error;
      }
    }
    return applied;
  } finally {
    if (lockHeld) {
      await client
        .query("SELECT pg_advisory_unlock(hashtext($1))", [
          MIGRATION_ADVISORY_LOCK_NAME,
        ])
        .catch(() => {});
    }
    client.release();
  }
}

/** Existing migrations self-wrapped in BEGIN/COMMIT remain byte-compatible.
 * The runner removes only their outer control lines so DDL and audit record
 * share one transaction, including on clean database installation.
 */
function stripOuterTransaction(sql: string): string {
  const withoutBegin = sql.replace(/^(\s*(?:--[^\n]*\n\s*)*)BEGIN;\s*/u, "$1");
  return withoutBegin.replace(/\s*COMMIT;\s*$/u, "\n");
}
