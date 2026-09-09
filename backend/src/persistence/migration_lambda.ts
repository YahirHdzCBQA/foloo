/** Private operator-invoked Lambda that applies migrations; it has no API route. */

import {
  GetSecretValueCommand,
  SecretsManagerClient,
} from "@aws-sdk/client-secrets-manager";
import pg from "pg";

import { applyMigrations, ensureApplicationRole } from "./migration_runner.js";

type Secret = { username: string; password: string };

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

export async function handler(): Promise<{ applied: string[] }> {
  const region = process.env.AWS_REGION;
  const adminArn = process.env.DB_ADMIN_SECRET_ARN;
  const appArn = process.env.DB_SECRET_ARN;
  const host = process.env.DB_HOST;
  const database = process.env.DB_NAME;
  if (!region || !adminArn || !appArn || !host || !database)
    throw new Error("Migration configuration is incomplete");

  const secrets = new SecretsManagerClient({ region });
  const [admin, app] = await Promise.all([
    readSecret(secrets, adminArn),
    readSecret(secrets, appArn),
  ]);
  if (app.username !== "foloo_app") {
    throw new Error(
      "Application database role does not match the migration contract",
    );
  }
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
      ),
    };
  } finally {
    await pool.end();
  }
}
