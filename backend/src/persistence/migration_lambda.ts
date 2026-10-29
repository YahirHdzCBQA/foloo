/** Private operator-invoked Lambda that applies migrations; it has no API route. */

import {
  GetSecretValueCommand,
  SecretsManagerClient,
} from "@aws-sdk/client-secrets-manager";
import pg from "pg";
import type { Context } from "aws-lambda";
import {
  inventorySubject,
  inspectSyntheticInventory,
  type QaInventory,
} from "./qa_inventory.js";

import { applyMigrations, ensureApplicationRole } from "./migration_runner.js";

type Secret = { username: string; password: string };
// `only` applies one named pending migration, leaving earlier pending ones untouched.
type MigrationEvent = {
  action?: "apply" | "status" | "qa-inventory";
  only?: string;
};

export type AccountDeletionMigrationStatus = Readonly<{
  migrationApplied: boolean;
  writeFenceMigrationApplied: boolean;
  appliedMigrations: readonly string[];
  columns: readonly string[];
  constraintPresent: boolean;
  indexPresent: boolean;
  functions: readonly string[];
  inconsistentBarriers: number;
  writeFenceTriggerCount: number;
}>;

async function readSecret(
  client: SecretsManagerClient,
  arn: string,
): Promise<Secret> {
  const result = await client.send(
    new GetSecretValueCommand({ SecretId: arn }),
  );
  if (!result.SecretString) throw new Error("Secret has no string value");
  const value = JSON.parse(result.SecretString) as Partial<Secret>;
  if (!value.username || !value.password)
    throw new Error("Secret is incomplete");
  return { username: value.username, password: value.password };
}

export async function handler(
  event: MigrationEvent = {},
  context?: Pick<Context, "invokedFunctionArn">,
): Promise<
  { applied: string[] } | AccountDeletionMigrationStatus | QaInventory
> {
  // Fail closed for misspelled inventory actions/extra fields before touching secrets.
  if (
    !event ||
    typeof event !== "object" ||
    Array.isArray(event) ||
    Object.keys(event).some((k) => !["action", "only"].includes(k)) ||
    (event.action !== undefined &&
      !["apply", "status", "qa-inventory"].includes(event.action))
  )
    throw new Error("invalid_operator_action");
  if (event.action === "qa-inventory") {
    if (Object.keys(event).some((k) => k !== "action"))
      throw new Error("invalid_operator_action");
    const subject = inventorySubject(process.env, context?.invokedFunctionArn);
    let pool: pg.Pool | undefined;
    try {
      if (
        !process.env.DB_SECRET_ARN ||
        !process.env.DB_HOST ||
        !process.env.DB_NAME
      )
        throw new Error("missing_configuration");
      const secrets = new SecretsManagerClient({
        region: process.env.AWS_REGION,
        maxAttempts: 1,
        requestHandler: { connectionTimeout: 3000, requestTimeout: 5000 },
      });
      const app = await readSecret(secrets, process.env.DB_SECRET_ARN);
      if (app.username !== "foloo_app")
        throw new Error("invalid_database_role");
      pool = new pg.Pool({
        host: process.env.DB_HOST,
        port: 5432,
        database: process.env.DB_NAME,
        user: app.username,
        password: app.password,
        ssl: { rejectUnauthorized: true },
        max: 1,
        connectionTimeoutMillis: 5000,
        query_timeout: 8000,
        options:
          "-c default_transaction_read_only=on -c statement_timeout=5000 -c lock_timeout=1000 -c idle_in_transaction_session_timeout=5000",
      });
      return await inspectSyntheticInventory(pool, subject);
    } catch {
      // No database/SDK errors containing identifiers, SQL or credentials escape.
      throw new Error("qa_inventory_unavailable");
    } finally {
      if (pool) await pool.end().catch(() => {});
    }
  }
  const region = process.env.AWS_REGION;
  const adminArn = process.env.DB_ADMIN_SECRET_ARN;
  const appArn = process.env.DB_SECRET_ARN;
  const host = process.env.DB_HOST;
  const database = process.env.DB_NAME;
  if (!region || !adminArn || !appArn || !host || !database)
    throw new Error("Migration configuration is incomplete");

  const secrets = new SecretsManagerClient({ region });
  const action = event.action ?? "apply";
  const admin = await readSecret(secrets, adminArn);
  const pool = new pg.Pool({
    host,
    port: 5432,
    database,
    user: admin.username,
    password: admin.password,
    ssl: { rejectUnauthorized: true },
    max: 1,
  });
  try {
    if (action === "status") return await inspectAccountDeletionBarrier(pool);
    const app = await readSecret(secrets, appArn);
    if (app.username !== "foloo_app") {
      throw new Error(
        "Application database role does not match the migration contract",
      );
    }
    const client = await pool.connect();
    try {
      await ensureApplicationRole(client, "foloo_app", app.password);
    } finally {
      client.release();
    }
    return {
      applied: await applyMigrations(
        pool,
        process.env.MIGRATIONS_DIR ?? "/var/task/migrations",
        event.only,
      ),
    };
  } finally {
    await pool.end();
  }
}

/** Returns only schema metadata and aggregate counts; never row identity data. */
export async function inspectAccountDeletionBarrier(
  pool: Pick<pg.Pool, "query">,
): Promise<AccountDeletionMigrationStatus> {
  const [migrations, columns, constraint, index, functions, writeFences] =
    await Promise.all([
      pool.query<{ name: string }>(
        "SELECT name FROM schema_migrations ORDER BY name",
      ),
      pool.query<{ column_name: string }>(
        `SELECT column_name FROM information_schema.columns
         WHERE table_schema='public' AND table_name='app_users'
           AND column_name IN ('deletion_request_id','deletion_pending_at')
         ORDER BY column_name`,
      ),
      pool.query<{ present: boolean }>(
        `SELECT EXISTS (
           SELECT 1 FROM pg_constraint
           WHERE conrelid='app_users'::regclass
             AND conname='app_users_deletion_barrier_consistent'
         ) AS present`,
      ),
      pool.query<{ present: boolean }>(
        `SELECT EXISTS (
           SELECT 1 FROM pg_indexes
           WHERE schemaname='public' AND tablename='app_users'
             AND indexname='app_users_deletion_request_unique'
         ) AS present`,
      ),
      pool.query<{ proname: string }>(
        `SELECT proname FROM pg_proc
         WHERE proname IN (
           'assert_account_active',
           'mark_account_deletion_pending',
           'ensure_personal_workspace'
         ) ORDER BY proname`,
      ),
      pool.query<{ count: string }>(
        `SELECT count(*)::text AS count
         FROM pg_trigger
         WHERE tgname='account_deletion_write_fence' AND NOT tgisinternal`,
      ),
    ]);
  const inconsistent =
    columns.rows.length === 2
      ? await pool.query<{ count: string }>(
          `SELECT count(*)::text AS count FROM app_users
           WHERE (deletion_request_id IS NULL) <>
                 (deletion_pending_at IS NULL)`,
        )
      : { rows: [{ count: "0" }] };
  return {
    migrationApplied: migrations.rows.some(
      (row) => row.name === "009_account_deletion_barrier.sql",
    ),
    writeFenceMigrationApplied: migrations.rows.some(
      (row) => row.name === "010_account_deletion_write_fence.sql",
    ),
    appliedMigrations: migrations.rows.map((row) => row.name),
    columns: columns.rows.map((row) => row.column_name),
    constraintPresent: constraint.rows[0]?.present === true,
    indexPresent: index.rows[0]?.present === true,
    functions: functions.rows.map((row) => row.proname),
    inconsistentBarriers: Number(inconsistent.rows[0]?.count ?? "0"),
    writeFenceTriggerCount: Number(writeFences.rows[0]?.count ?? "0"),
  };
}
