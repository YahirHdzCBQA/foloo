/** Owns secret retrieval and a small reusable PostgreSQL pool for Lambda. */

import {
  GetSecretValueCommand,
  SecretsManagerClient,
} from "@aws-sdk/client-secrets-manager";
import pg from "pg";

import { loadEnvironment } from "../config/environment.js";

const { Pool } = pg;
let poolPromise: Promise<pg.Pool> | undefined;

type DatabaseSecret = { username: string; password: string };

async function createPool(): Promise<pg.Pool> {
  const config = loadEnvironment();
  const secrets = new SecretsManagerClient({ region: config.AWS_REGION });
  const response = await secrets.send(
    new GetSecretValueCommand({ SecretId: config.DB_SECRET_ARN }),
  );
  if (!response.SecretString)
    throw new Error("Database secret has no SecretString");
  const secret = JSON.parse(response.SecretString) as Partial<DatabaseSecret>;
  if (!secret.username || !secret.password)
    throw new Error("Database secret is incomplete");

  return new Pool({
    host: config.DB_HOST,
    port: config.DB_PORT,
    database: config.DB_NAME,
    user: secret.username,
    password: secret.password,
    ssl: { rejectUnauthorized: true },
    max: config.DB_POOL_MAX,
    idleTimeoutMillis: 10_000,
    connectionTimeoutMillis: 5_000,
  });
}

export function databasePool(): Promise<pg.Pool> {
  // Warm Lambda environments reuse this promise/pool; failed initialization may retry.
  poolPromise ??= createPool().catch((error: unknown) => {
    poolPromise = undefined;
    throw error;
  });
  return poolPromise;
}
