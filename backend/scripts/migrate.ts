/** Local/operator migration entry point; credentials are supplied at runtime only. */

import { resolve } from "node:path";

import pg from "pg";

import {
  applyMigrations,
  ensureApplicationRole,
} from "../src/persistence/migration_runner.js";

const databaseUrl = process.env.DATABASE_URL;
const appPassword = process.env.APP_DATABASE_PASSWORD;

if (!databaseUrl || !appPassword) {
  throw new Error(
    "DATABASE_URL and APP_DATABASE_PASSWORD must be supplied outside the repository.",
  );
}

const pool = new pg.Pool({ connectionString: databaseUrl, max: 1 });
try {
  const client = await pool.connect();
  try {
    await ensureApplicationRole(client, "foloo_app", appPassword);
  } finally {
    client.release();
  }
  const applied = await applyMigrations(pool, resolve("migrations"));
  console.info(JSON.stringify({ applied }));
} finally {
  await pool.end();
}
