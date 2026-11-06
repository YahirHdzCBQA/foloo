/** Optional PostgreSQL verification for migration 012 and operator roles. */

import assert from "node:assert/strict";
import { resolve } from "node:path";
import test from "node:test";

import pg from "pg";

import { AdministrativeEntitlementService } from "../src/entitlements/administrative_entitlement.js";
import {
  applyMigrations,
  ensureApplicationRole,
} from "../src/persistence/migration_runner.js";

test(
  "MON-21 PostgreSQL migrates atomically and isolates administrative grants",
  { skip: !process.env.TRIAL_FOUNDATION_TEST_DATABASE_URL },
  async () => {
    const connectionString = process.env.TRIAL_FOUNDATION_TEST_DATABASE_URL!;
    const admin = new pg.Pool({ connectionString, max: 2 });
    try {
      const client = await admin.connect();
      try {
        await ensureApplicationRole(client, "foloo_app", "local-test-only");
        await ensureApplicationRole(
          client,
          "foloo_entitlement_operator",
          "operator-test-only",
        );
      } finally {
        client.release();
      }
      const migrations = resolve("migrations");
      assert.equal((await applyMigrations(admin, migrations)).length, 12);
      assert.deepEqual(await applyMigrations(admin, migrations), []);

      const lockClient = await admin.connect();
      try {
        await lockClient.query(
          "SELECT pg_advisory_lock(hashtext('foloo-schema-migrations-v1'))",
        );
        await assert.rejects(
          applyMigrations(admin, migrations),
          /already running/,
        );
      } finally {
        await lockClient.query(
          "SELECT pg_advisory_unlock(hashtext('foloo-schema-migrations-v1'))",
        );
        lockClient.release();
      }

      const privilege = async (role: string, table: string, action: string) =>
        (
          await admin.query<{ allowed: boolean }>(
            "SELECT has_table_privilege($1,$2,$3) AS allowed",
            [role, table, action],
          )
        ).rows[0]?.allowed === true;
      for (const table of ["entitlement_grants", "entitlement_grant_audit"]) {
        for (const action of ["SELECT", "INSERT", "UPDATE", "DELETE"])
          assert.equal(await privilege("foloo_app", table, action), false);
      }
      for (const action of ["SELECT", "INSERT", "UPDATE"])
        assert.equal(
          await privilege("foloo_app", "trial_milestone_events", action),
          true,
        );
      assert.equal(
        await privilege("foloo_app", "trial_milestone_events", "DELETE"),
        false,
      );
      await admin.query("CREATE TABLE future_privilege_probe(id integer)");
      try {
        assert.equal(
          await privilege("foloo_app", "future_privilege_probe", "SELECT"),
          false,
        );
      } finally {
        await admin.query("DROP TABLE future_privilege_probe");
      }

      await admin.query("SELECT * FROM ensure_personal_workspace($1)", [
        "subject-trial",
      ]);
      const operatorUrl = new URL(connectionString);
      operatorUrl.username = "foloo_entitlement_operator";
      operatorUrl.password = "operator-test-only";
      const operator = new pg.Pool({
        connectionString: operatorUrl.toString(),
        max: 1,
      });
      const service = new AdministrativeEntitlementService(operator, {
        resolveVerifiedEmail: async () => ({
          subject: "subject-trial",
          emailVerified: true,
        }),
      });
      assert.equal(
        (
          await service.execute({
            action: "grant",
            email: "synthetic@example.test",
            actor: "arn:aws:sts::123456789012:assumed-role/operator/test",
            reason: "PostgreSQL integration verification",
          })
        ).action,
        "granted",
      );
      assert.equal(
        (
          await service.execute({
            action: "revoke",
            email: "synthetic@example.test",
            actor: "arn:aws:sts::123456789012:assumed-role/operator/test",
            reason: "PostgreSQL integration verification",
          })
        ).action,
        "revoked",
      );
      const restored = await admin.query<{
        subscription_status: string;
        entitlement_source: string;
      }>(
        `SELECT a.subscription_status,a.entitlement_source FROM accounts a
         JOIN app_users u ON u.id=a.owner_user_id WHERE u.cognito_sub=$1`,
        ["subject-trial"],
      );
      assert.deepEqual(restored.rows[0], {
        subscription_status: "trial",
        entitlement_source: "trial",
      });
      await operator.end();
    } finally {
      await admin.end();
    }
  },
);
