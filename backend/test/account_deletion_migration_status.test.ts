/** Read-only migration inspection must return schema evidence without PII. */

import assert from "node:assert/strict";
import test from "node:test";

import { SecretsManagerClient } from "@aws-sdk/client-secrets-manager";
import pg from "pg";

import {
  handler,
  inspectAccountDeletionBarrier,
} from "../src/persistence/migration_lambda.js";

function deferred<T>(): {
  promise: Promise<T>;
  resolve: (value: T) => void;
} {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((complete) => {
    resolve = complete;
  });
  return { promise, resolve };
}

test("INF-18 migration status reports only aggregate schema evidence", async () => {
  const calls: string[] = [];
  const pool = {
    async query(sql: string) {
      calls.push(sql);
      if (sql.includes("schema_migrations"))
        return {
          rows: [
            { name: "008_email_sender_identity.sql" },
            { name: "009_account_deletion_barrier.sql" },
          ],
        };
      if (sql.includes("information_schema.columns"))
        return {
          rows: [
            { column_name: "deletion_pending_at" },
            { column_name: "deletion_request_id" },
          ],
        };
      if (sql.includes("pg_constraint")) return { rows: [{ present: true }] };
      if (sql.includes("pg_indexes")) return { rows: [{ present: true }] };
      if (sql.includes("pg_proc"))
        return {
          rows: [
            { proname: "assert_account_active" },
            { proname: "ensure_personal_workspace" },
            { proname: "mark_account_deletion_pending" },
          ],
        };
      return { rows: [{ count: "0" }] };
    },
  };
  const status = await inspectAccountDeletionBarrier(pool as never);
  assert.deepEqual(status, {
    migrationApplied: true,
    appliedMigrations: [
      "008_email_sender_identity.sql",
      "009_account_deletion_barrier.sql",
    ],
    columns: ["deletion_pending_at", "deletion_request_id"],
    constraintPresent: true,
    indexPresent: true,
    functions: [
      "assert_account_active",
      "ensure_personal_workspace",
      "mark_account_deletion_pending",
    ],
    inconsistentBarriers: 0,
  });
  assert.equal(calls.length, 6);
  assert.doesNotMatch(JSON.stringify(status), /@|fixture|synthetic-subject/iu);
});

test("MigrationFunction closes the pool only after status inspection completes", async () => {
  const queryResult = deferred<{ rows: Array<{ name: string }> }>();
  const events: string[] = [];
  const originalPool = Object.getOwnPropertyDescriptor(pg, "Pool");
  const originalSend = Object.getOwnPropertyDescriptor(
    SecretsManagerClient.prototype,
    "send",
  );
  const environment = {
    AWS_REGION: process.env.AWS_REGION,
    DB_ADMIN_SECRET_ARN: process.env.DB_ADMIN_SECRET_ARN,
    DB_SECRET_ARN: process.env.DB_SECRET_ARN,
    DB_HOST: process.env.DB_HOST,
    DB_NAME: process.env.DB_NAME,
  };

  class StatusPool {
    async query(sql: string): Promise<{ rows: unknown[] }> {
      if (sql.includes("schema_migrations")) {
        return queryResult.promise.then((result) => {
          events.push("status-query-completed");
          return result;
        });
      }
      if (sql.includes("information_schema.columns")) return { rows: [] };
      if (sql.includes("pg_constraint") || sql.includes("pg_indexes")) {
        return { rows: [{ present: false }] };
      }
      if (sql.includes("pg_proc")) return { rows: [] };
      throw new Error("Unexpected status query");
    }

    async end(): Promise<void> {
      events.push("pool-end");
    }
  }

  try {
    Object.defineProperty(pg, "Pool", {
      configurable: true,
      writable: true,
      value: StatusPool,
    });
    Object.defineProperty(SecretsManagerClient.prototype, "send", {
      configurable: true,
      writable: true,
      value: async () => ({
        SecretString: JSON.stringify({
          username: "synthetic_admin",
          password: "synthetic_password",
        }),
      }),
    });
    process.env.AWS_REGION = "us-east-1";
    process.env.DB_ADMIN_SECRET_ARN = "synthetic-admin-secret";
    process.env.DB_SECRET_ARN = "synthetic-app-secret";
    process.env.DB_HOST = "synthetic.invalid";
    process.env.DB_NAME = "synthetic_database";

    const statusPromise = handler({ action: "status" });
    await new Promise<void>((resolve) => setImmediate(resolve));
    assert.deepEqual(events, []);

    queryResult.resolve({ rows: [{ name: "008_email_sender_identity.sql" }] });
    const status = await statusPromise;

    assert.equal("migrationApplied" in status, true);
    assert.deepEqual(events, ["status-query-completed", "pool-end"]);
  } finally {
    if (originalPool) Object.defineProperty(pg, "Pool", originalPool);
    if (originalSend) {
      Object.defineProperty(
        SecretsManagerClient.prototype,
        "send",
        originalSend,
      );
    }
    for (const [key, value] of Object.entries(environment)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
});
