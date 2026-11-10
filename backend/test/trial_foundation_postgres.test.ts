/** Optional PostgreSQL verification for FL-021 migrations and operator roles. */

import assert from "node:assert/strict";
import { readdir } from "node:fs/promises";
import { resolve } from "node:path";
import test from "node:test";

import pg from "pg";

import { AdministrativeEntitlementService } from "../src/entitlements/administrative_entitlement.js";
import { EntitlementPreauthorizationService } from "../src/entitlements/entitlement_preauthorization.js";
import {
  applyMigrations,
  ensureApplicationRole,
} from "../src/persistence/migration_runner.js";
import { runFl021MigrationPreflight } from "../src/persistence/fl021_migration_preflight.js";

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
      const migrationNames = (await readdir(migrations))
        .filter((name) => /^\d+_.*\.sql$/u.test(name))
        .sort();
      assert.equal(migrationNames.length, 15);
      const applied: string[] = [];
      for (const name of migrationNames.slice(0, 11))
        applied.push(...(await applyMigrations(admin, migrations, name)));

      const before012 = await runFl021MigrationPreflight(admin);
      assert.equal(before012.safeToApply012, true);
      assert.deepEqual(before012.migrations, {
        migration010Count: 1,
        migration011Count: 1,
        migration012Count: 0,
      });
      assert.equal(before012.foundationObjects, null);

      applied.push(
        ...(await applyMigrations(
          admin,
          migrations,
          "012_trial_subscription_foundation.sql",
        )),
      );
      assert.equal(applied.length, 12);
      const after012 = await runFl021MigrationPreflight(admin);
      assert.equal(after012.migrations.migration012Count, 1);
      assert.equal(after012.integrityConsistent, true);
      assert.deepEqual(after012.foundationObjects, {
        tablesPresent: 3,
        indexesPresent: 2,
        writeFenceTriggersPresent: 3,
        entitlementAdminRolePresent: true,
        entitlementOperatorRolePresent: true,
        appAdministrativeWriteDenied: true,
        appMilestonePrivilegesPresent: true,
        adminPrivilegesPresent: true,
        operatorMembershipPresent: true,
      });
      applied.push(
        ...(await applyMigrations(
          admin,
          migrations,
          "013_fl021_entitlement_preauthorizations.sql",
        )),
      );
      applied.push(
        ...(await applyMigrations(
          admin,
          migrations,
          "014_fl021_account_deletion_preauthorization_invalidation.sql",
        )),
      );
      applied.push(
        ...(await applyMigrations(
          admin,
          migrations,
          "015_optional_lead_company.sql",
        )),
      );
      assert.equal(applied.length, 15);
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
      for (const table of [
        "entitlement_preauthorizations",
        "entitlement_preauthorization_audit",
      ]) {
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
        max: 4,
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

      const selector = {
        select: async (email: string) => ({
          keyVersion: "v1",
          canonicalizationPolicy: "foloo-email-v1-provisional" as const,
          digest: Buffer.from(email.padEnd(32, "0"))
            .subarray(0, 32)
            .toString("base64url"),
        }),
      };
      const preauthorizations = new EntitlementPreauthorizationService(
        operator,
        selector,
      );
      await preauthorizations.execute({
        action: "preauthorize",
        email: "before-registration@example.test",
        actor: "arn:aws:sts::123456789012:assumed-role/operator/test",
        reason: "Pre-registration verification",
      });
      await assert.rejects(
        preauthorizations.consumeVerifiedIdentity({
          subject: "subject-created-after-preauthorization",
          verifiedEmail: "before-registration@example.test",
        }),
        /has not completed account provisioning/u,
      );
      await admin.query("SELECT * FROM ensure_personal_workspace($1)", [
        "subject-created-after-preauthorization",
      ]);
      assert.deepEqual(
        await preauthorizations.consumeVerifiedIdentity({
          subject: "subject-created-after-preauthorization",
          verifiedEmail: "before-registration@example.test",
        }),
        { outcome: "granted" },
      );
      assert.deepEqual(
        await preauthorizations.execute({
          action: "preauthorize",
          email: "future@example.test",
          actor: "arn:aws:sts::123456789012:assumed-role/operator/test",
          reason: "Approved automatic QA entitlement",
        }),
        { action: "preauthorized", status: "active" },
      );
      assert.deepEqual(
        await preauthorizations.consumeVerifiedIdentity({
          subject: "subject-trial",
          verifiedEmail: "future@example.test",
        }),
        { outcome: "granted" },
      );
      assert.deepEqual(
        await preauthorizations.consumeVerifiedIdentity({
          subject: "subject-trial",
          verifiedEmail: "future@example.test",
        }),
        { outcome: "unchanged" },
      );
      assert.deepEqual(
        await preauthorizations.execute({
          action: "revoke-preauthorization",
          email: "future@example.test",
          actor: "arn:aws:sts::123456789012:assumed-role/operator/test",
          reason: "Automatic QA entitlement ended",
        }),
        { action: "revoked", status: "revoked" },
      );
      const afterAutomaticRevoke = await admin.query<{
        subscription_status: string;
        entitlement_source: string;
        trial_leads_used: number;
      }>(
        `SELECT a.subscription_status,a.entitlement_source,a.trial_leads_used
         FROM accounts a JOIN app_users u ON u.id=a.owner_user_id
         WHERE u.cognito_sub=$1`,
        ["subject-trial"],
      );
      assert.deepEqual(afterAutomaticRevoke.rows[0], {
        subscription_status: "trial",
        entitlement_source: "trial",
        trial_leads_used: 0,
      });

      await admin.query("SELECT * FROM ensure_personal_workspace($1)", [
        "subject-concurrent",
      ]);
      await admin.query(
        `UPDATE accounts SET trial_leads_used=5,subscription_status='trial_exhausted'
         WHERE owner_user_id=(SELECT id FROM app_users WHERE cognito_sub=$1)`,
        ["subject-concurrent"],
      );
      await preauthorizations.execute({
        action: "preauthorize",
        email: "concurrent@example.test",
        actor: "arn:aws:sts::123456789012:assumed-role/operator/test",
        reason: "Concurrency verification",
      });
      const concurrent = await Promise.all([
        preauthorizations.consumeVerifiedIdentity({
          subject: "subject-concurrent",
          verifiedEmail: "concurrent@example.test",
        }),
        preauthorizations.consumeVerifiedIdentity({
          subject: "subject-concurrent",
          verifiedEmail: "concurrent@example.test",
        }),
      ]);
      assert.deepEqual(concurrent.map((result) => result.outcome).sort(), [
        "granted",
        "unchanged",
      ]);
      assert.equal(
        (
          await admin.query<{ count: string }>(
            `SELECT count(*)::text AS count FROM entitlement_grants
             WHERE account_id=(SELECT a.id FROM accounts a JOIN app_users u
               ON u.id=a.owner_user_id WHERE u.cognito_sub=$1)
               AND status='active'`,
            ["subject-concurrent"],
          )
        ).rows[0]?.count,
        "1",
      );

      await admin.query("SELECT * FROM ensure_personal_workspace($1)", [
        "subject-no-preauthorization",
      ]);
      const noPreauthorizationAccount = await admin.query<{ id: string }>(
        `SELECT a.id FROM accounts a JOIN app_users u ON u.id=a.owner_user_id
         WHERE u.cognito_sub=$1`,
        ["subject-no-preauthorization"],
      );
      await admin.query(
        `UPDATE app_users SET deletion_request_id=$2,deletion_pending_at=now()
         WHERE cognito_sub=$1`,
        ["subject-no-preauthorization", "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"],
      );
      assert.equal(
        (
          await admin.query<{ count: number }>(
            `SELECT revoke_account_entitlement_preauthorizations(
               $1,$2::text[],$3::text[]
             ) AS count`,
            [noPreauthorizationAccount.rows[0]!.id, ["v1"], ["Z".repeat(43)]],
          )
        ).rows[0]?.count,
        0,
      );

      await admin.query("SELECT * FROM ensure_personal_workspace($1)", [
        "subject-legacy",
      ]);
      await admin.query(
        `UPDATE accounts SET subscription_status='active',
           entitlement_source='legacy_active'
         WHERE owner_user_id=(SELECT id FROM app_users WHERE cognito_sub=$1)`,
        ["subject-legacy"],
      );
      await preauthorizations.execute({
        action: "preauthorize",
        email: "legacy@example.test",
        actor: "arn:aws:sts::123456789012:assumed-role/operator/test",
        reason: "Legacy protection verification",
      });
      assert.deepEqual(
        await preauthorizations.consumeVerifiedIdentity({
          subject: "subject-legacy",
          verifiedEmail: "legacy@example.test",
        }),
        { outcome: "commercial-conflict" },
      );
      assert.deepEqual(
        (
          await admin.query<{
            subscription_status: string;
            entitlement_source: string;
          }>(
            `SELECT subscription_status,entitlement_source FROM accounts
             WHERE owner_user_id=(SELECT id FROM app_users WHERE cognito_sub=$1)`,
            ["subject-legacy"],
          )
        ).rows[0],
        { subscription_status: "active", entitlement_source: "legacy_active" },
      );

      await admin.query("SELECT * FROM ensure_personal_workspace($1)", [
        "subject-stripe",
      ]);
      await admin.query(
        `UPDATE accounts SET subscription_status='active',entitlement_source='stripe',
           stripe_customer_id='cus_local',stripe_subscription_id='sub_local'
         WHERE owner_user_id=(SELECT id FROM app_users WHERE cognito_sub=$1)`,
        ["subject-stripe"],
      );
      await preauthorizations.execute({
        action: "preauthorize",
        email: "stripe@example.test",
        actor: "arn:aws:sts::123456789012:assumed-role/operator/test",
        reason: "Commercial protection verification",
      });
      for (let attempt = 0; attempt < 2; attempt += 1) {
        assert.deepEqual(
          await preauthorizations.consumeVerifiedIdentity({
            subject: "subject-stripe",
            verifiedEmail: "stripe@example.test",
          }),
          { outcome: "commercial-conflict" },
        );
      }
      assert.equal(
        (
          await admin.query<{ count: string }>(
            `SELECT count(*)::text AS count
             FROM entitlement_preauthorization_audit audit
             JOIN entitlement_preauthorizations preauthorization
               ON preauthorization.id=audit.preauthorization_id
             WHERE audit.action='exception'
               AND audit.exception_code='commercial_entitlement_present'
               AND preauthorization.email_digest=$1`,
            [(await selector.select("stripe@example.test")).digest],
          )
        ).rows[0]?.count,
        "1",
      );

      assert.deepEqual(
        await preauthorizations.consumeVerifiedIdentity({
          subject: "subject-stripe",
          verifiedEmail: "relay@privaterelay.appleid.com",
        }),
        { outcome: "not-preauthorized" },
      );
      await assert.rejects(
        preauthorizations.consumeVerifiedIdentity({
          subject: "subject-not-provisioned",
          verifiedEmail: "concurrent@example.test",
        }),
        /has not completed account provisioning/u,
      );

      const concurrentAccount = await admin.query<{ id: string }>(
        `SELECT a.id FROM accounts a JOIN app_users u ON u.id=a.owner_user_id
         WHERE u.cognito_sub=$1`,
        ["subject-concurrent"],
      );
      const concurrentAccountId = concurrentAccount.rows[0]!.id;
      await admin.query(
        `UPDATE app_users SET deletion_request_id=$2,deletion_pending_at=now()
         WHERE cognito_sub=$1`,
        ["subject-concurrent", "77777777-7777-4777-8777-777777777777"],
      );
      const concurrentSelector = await selector.select(
        "concurrent@example.test",
      );
      assert.equal(
        (
          await admin.query<{ count: number }>(
            `SELECT revoke_account_entitlement_preauthorizations(
               $1,$2::text[],$3::text[]
             ) AS count`,
            [
              concurrentAccountId,
              ["v2", concurrentSelector.keyVersion],
              ["B".repeat(43), concurrentSelector.digest],
            ],
          )
        ).rows[0]?.count,
        1,
      );
      assert.equal(
        (
          await admin.query<{ status: string }>(
            `SELECT status FROM entitlement_preauthorizations
             WHERE email_digest=$1`,
            [(await selector.select("concurrent@example.test")).digest],
          )
        ).rows[0]?.status,
        "revoked",
      );

      assert.equal(
        (
          await admin.query<{ count: number }>(
            `SELECT revoke_account_entitlement_preauthorizations(
               $1,$2::text[],$3::text[]
             ) AS count`,
            [concurrentAccountId, ["v1"], [concurrentSelector.digest]],
          )
        ).rows[0]?.count,
        0,
      );
      assert.deepEqual(
        await preauthorizations.consumeVerifiedIdentity({
          subject: "subject-concurrent",
          verifiedEmail: "concurrent@example.test",
        }),
        { outcome: "revoked" },
      );

      await admin.query("SELECT * FROM ensure_personal_workspace($1)", [
        "subject-active-delete",
      ]);
      await preauthorizations.execute({
        action: "preauthorize",
        email: "active-delete@example.test",
        actor: "arn:aws:sts::123456789012:assumed-role/operator/test",
        reason: "Active deletion verification",
      });
      await preauthorizations.execute({
        action: "preauthorize",
        email: "different-owner@example.test",
        actor: "arn:aws:sts::123456789012:assumed-role/operator/test",
        reason: "Cross-owner isolation verification",
      });
      const activeAccount = await admin.query<{ id: string }>(
        `SELECT a.id FROM accounts a JOIN app_users u ON u.id=a.owner_user_id
         WHERE u.cognito_sub=$1`,
        ["subject-active-delete"],
      );
      await admin.query(
        `UPDATE app_users SET deletion_request_id=$2,deletion_pending_at=now()
         WHERE cognito_sub=$1`,
        ["subject-active-delete", "88888888-8888-4888-8888-888888888888"],
      );
      const activeSelector = await selector.select(
        "active-delete@example.test",
      );
      assert.equal(
        (
          await admin.query<{ count: number }>(
            `SELECT revoke_account_entitlement_preauthorizations(
               $1,$2::text[],$3::text[]
             ) AS count`,
            [activeAccount.rows[0]!.id, ["v1"], [activeSelector.digest]],
          )
        ).rows[0]?.count,
        1,
      );
      assert.equal(
        (
          await admin.query<{ status: string }>(
            `SELECT status FROM entitlement_preauthorizations
             WHERE email_digest=$1`,
            [activeSelector.digest],
          )
        ).rows[0]?.status,
        "revoked",
      );
      assert.equal(
        (
          await admin.query<{ status: string }>(
            `SELECT status FROM entitlement_preauthorizations
             WHERE email_digest=$1`,
            [(await selector.select("different-owner@example.test")).digest],
          )
        ).rows[0]?.status,
        "active",
      );
      assert.equal(
        (
          await admin.query<{ count: string }>(
            `SELECT count(*)::text AS count
             FROM entitlement_preauthorization_audit
             WHERE preauthorization_id=(SELECT id
               FROM entitlement_preauthorizations WHERE email_digest=$1)
               AND action='revoked'
               AND actor='system:account-deletion'`,
            [activeSelector.digest],
          )
        ).rows[0]?.count,
        "1",
      );

      await admin.query("SELECT * FROM ensure_personal_workspace($1)", [
        "subject-race-delete",
      ]);
      await preauthorizations.execute({
        action: "preauthorize",
        email: "race-delete@example.test",
        actor: "arn:aws:sts::123456789012:assumed-role/operator/test",
        reason: "Deletion concurrency verification",
      });
      const raceAccount = await admin.query<{ id: string }>(
        `SELECT a.id FROM accounts a JOIN app_users u ON u.id=a.owner_user_id
         WHERE u.cognito_sub=$1`,
        ["subject-race-delete"],
      );
      await admin.query(
        `UPDATE app_users SET deletion_request_id=$2,deletion_pending_at=now()
         WHERE cognito_sub=$1`,
        ["subject-race-delete", "99999999-9999-4999-8999-999999999999"],
      );
      const raceSelector = await selector.select("race-delete@example.test");
      const race = await Promise.all([
        preauthorizations.consumeVerifiedIdentity({
          subject: "subject-race-delete",
          verifiedEmail: "race-delete@example.test",
        }),
        admin.query(
          `SELECT revoke_account_entitlement_preauthorizations(
             $1,$2::text[],$3::text[]
           ) AS count`,
          [raceAccount.rows[0]!.id, ["v1"], [raceSelector.digest]],
        ),
      ]);
      assert.ok(
        ["account-deletion-pending", "revoked"].includes(race[0].outcome),
      );
      assert.equal(
        (
          await admin.query<{ status: string }>(
            `SELECT status FROM entitlement_preauthorizations
             WHERE email_digest=$1`,
            [raceSelector.digest],
          )
        ).rows[0]?.status,
        "revoked",
      );
      assert.equal(
        (
          await admin.query<{ count: string }>(
            `SELECT count(*)::text AS count FROM entitlement_grants
             WHERE account_id=$1 AND status='active'`,
            [raceAccount.rows[0]!.id],
          )
        ).rows[0]?.count,
        "0",
      );

      const appUrl = new URL(connectionString);
      appUrl.username = "foloo_app";
      appUrl.password = "local-test-only";
      const app = new pg.Pool({ connectionString: appUrl.toString(), max: 1 });
      try {
        assert.equal(
          (
            await app.query<{ count: number }>(
              `SELECT revoke_account_entitlement_preauthorizations(
                 $1,$2::text[],$3::text[]
               ) AS count`,
              [activeAccount.rows[0]!.id, ["v1"], [activeSelector.digest]],
            )
          ).rows[0]?.count,
          0,
        );
        await assert.rejects(
          app.query("UPDATE entitlement_preauthorizations SET status='active'"),
          /permission denied/u,
        );
      } finally {
        await app.end();
      }
      await operator.end();
    } finally {
      await admin.end();
    }
  },
);
