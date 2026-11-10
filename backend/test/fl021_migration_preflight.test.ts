/** Aggregate, read-only and concurrency coverage for FL-021 preflight. */

import assert from "node:assert/strict";
import test from "node:test";

import type pg from "pg";

import {
  inspectFl021MigrationPreflight,
  runFl021MigrationPreflight,
} from "../src/persistence/fl021_migration_preflight.js";
import { handler } from "../src/persistence/migration_lambda.js";

type SchemaState = "before" | "after";

function fixture(
  state: SchemaState,
  options?: Readonly<{
    lockAvailable?: boolean;
    failWith?: Error;
    nonActiveStripeReferences?: number;
  }>,
) {
  const queries: string[] = [];
  let released = false;
  let failed = false;
  const client = {
    async query(sql: string) {
      queries.push(sql);
      if (
        options?.failWith &&
        !failed &&
        sql.includes("FROM schema_migrations")
      ) {
        failed = true;
        throw options.failWith;
      }
      if (sql.includes("pg_try_advisory_xact_lock"))
        return {
          rows: [{ acquired: options?.lockAvailable !== false }],
          rowCount: 1,
        };
      if (sql.includes("FROM schema_migrations"))
        return {
          rows: [
            { name: "010_account_deletion_write_fence.sql", count: "1" },
            { name: "011_billing_stripe.sql", count: "1" },
            ...(state === "after"
              ? [
                  {
                    name: "012_trial_subscription_foundation.sql",
                    count: "1",
                  },
                ]
              : []),
          ],
          rowCount: state === "after" ? 3 : 2,
        };
      if (sql.includes("information_schema.columns"))
        return {
          rows: [
            {
              entitlement_source: state === "after",
              stripe_customer_id: true,
              stripe_subscription_id: true,
            },
          ],
          rowCount: 1,
        };
      if (sql.includes("COALESCE(sum(trial_leads_used)"))
        return {
          rows: [{ accounts: "7", trial_leads_used: "19" }],
          rowCount: 1,
        };
      if (sql.includes("GROUP BY subscription_status"))
        return {
          rows: [
            { value: "active", count: "2" },
            { value: "trial", count: "5" },
          ],
          rowCount: 2,
        };
      if (sql.includes("AS active_complete"))
        return {
          rows: [
            {
              active_complete: "1",
              active_none: "1",
              partial: "0",
              non_active_any: String(options?.nonActiveStripeReferences ?? 0),
            },
          ],
          rowCount: 1,
        };
      if (sql.includes("GROUP BY entitlement_source"))
        return {
          rows: [
            { value: "legacy_active", count: "1" },
            { value: "stripe", count: "1" },
            { value: "trial", count: "5" },
          ],
          rowCount: 3,
        };
      if (sql.includes("AS unexpected_sources"))
        return {
          rows: [
            {
              unexpected_sources: "0",
              stripe_without_complete: "0",
              non_stripe_with_references: "0",
              status_mismatches: "0",
            },
          ],
          rowCount: 1,
        };
      if (sql.includes("AS tables_present"))
        return {
          rows: [
            {
              tables_present: "3",
              indexes_present: "2",
              triggers_present: "3",
              admin_role_present: true,
              operator_role_present: true,
              app_admin_write: false,
              app_milestone_select: true,
              app_milestone_insert: true,
              app_milestone_update: true,
              admin_grants_select: true,
              admin_grants_insert: true,
              admin_grants_update: true,
              admin_audit_select: true,
              admin_audit_insert: true,
              operator_membership: true,
            },
          ],
          rowCount: 1,
        };
      if (sql.includes("subscription_status NOT IN"))
        return { rows: [{ count: "0" }], rowCount: 1 };
      return { rows: [], rowCount: 0 };
    },
    release() {
      released = true;
    },
  };
  const pool = {
    connect: async () => client,
  } as unknown as Pick<pg.Pool, "connect">;
  return {
    pool,
    queries,
    released: () => released,
  };
}

test("MON-21 reports a safe aggregate-only snapshot before migration 012", async () => {
  const { pool, queries, released } = fixture("before");
  const result = await inspectFl021MigrationPreflight(pool);

  assert.deepEqual(result.migrations, {
    migration010Count: 1,
    migration011Count: 1,
    migration012Count: 0,
  });
  assert.deepEqual(result.totals, { accounts: 7, trialLeadsUsed: 19 });
  assert.equal(result.entitlementSourceDistribution, null);
  assert.equal(result.foundationObjects, null);
  assert.equal(result.integrityConsistent, true);
  assert.equal(result.safeToApply012, true);
  assert.equal(queries[0], "BEGIN READ ONLY");
  assert.ok(queries.includes("SET LOCAL lock_timeout = '1s'"));
  assert.ok(queries.includes("SET LOCAL statement_timeout = '5s'"));
  assert.equal(queries.at(-1), "ROLLBACK");
  assert.equal(released(), true);
  assert.equal(JSON.stringify(result).includes("email"), false);
  assert.equal(JSON.stringify(result).includes("subject"), false);
});

test("MON-21 adapts after migration 012 and reports entitlement evidence", async () => {
  const { pool } = fixture("after");
  const result = await inspectFl021MigrationPreflight(pool);

  assert.equal(result.migrations.migration012Count, 1);
  assert.deepEqual(result.entitlementSourceDistribution, [
    { value: "legacy_active", count: 1 },
    { value: "stripe", count: 1 },
    { value: "trial", count: 5 },
  ]);
  assert.deepEqual(result.foundationObjects, {
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
  assert.equal(result.integrityConsistent, true);
  assert.equal(result.safeToApply012, false);
});

test("MON-21 fails closed when another migration owns the runner lock", async () => {
  const { pool, queries, released } = fixture("before", {
    lockAvailable: false,
  });
  await assert.rejects(
    runFl021MigrationPreflight(pool),
    /fl021_migration_concurrent/,
  );
  assert.equal(queries.at(-1), "ROLLBACK");
  assert.equal(released(), true);
});

test("MON-21 rolls back and releases on permission or timeout errors", async () => {
  for (const error of [
    new Error("permission denied for table accounts"),
    new Error("canceling statement due to statement timeout"),
  ]) {
    const { pool, queries, released } = fixture("before", {
      failWith: error,
    });
    await assert.rejects(
      runFl021MigrationPreflight(pool),
      /fl021_preflight_unavailable/,
    );
    assert.equal(queries.at(-1), "ROLLBACK");
    assert.equal(released(), true);
  }
});

test("MON-21 blocks readiness when 012 would misclassify Stripe references", async () => {
  const { pool } = fixture("before", { nonActiveStripeReferences: 1 });
  const result = await inspectFl021MigrationPreflight(pool);

  assert.equal(result.commercialBindings.nonActiveWithStripeReferences, 1);
  assert.equal(result.integrityConsistent, false);
  assert.equal(result.safeToApply012, false);
});

test("MON-21 private preflight rejects parameters before configuration", async () => {
  await assert.rejects(
    handler({
      action: "fl021-preflight",
      only: "012_trial_subscription_foundation.sql",
    }),
    /invalid_operator_action/,
  );
});
