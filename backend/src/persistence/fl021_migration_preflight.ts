/**
 * Private aggregate-only readiness inspection for FL-021/MON-21 migration 012.
 * It shares the runner lock, never returns owner data, and operates read-only.
 */

import type pg from "pg";

import { MIGRATION_ADVISORY_LOCK_NAME } from "./migration_runner.js";

const requiredMigrations = [
  "010_account_deletion_write_fence.sql",
  "011_billing_stripe.sql",
  "012_trial_subscription_foundation.sql",
] as const;

type Distribution = Readonly<{ value: string; count: number }>;

export type Fl021MigrationPreflight = Readonly<{
  migrations: Readonly<{
    migration010Count: number;
    migration011Count: number;
    migration012Count: number;
  }>;
  schema: Readonly<{
    entitlementSourceAvailable: boolean;
    stripeReferenceColumnsAvailable: boolean;
  }>;
  totals: Readonly<{
    accounts: number;
    trialLeadsUsed: number;
  }>;
  subscriptionStatusDistribution: readonly Distribution[];
  entitlementSourceDistribution: readonly Distribution[] | null;
  commercialBindings: Readonly<{
    activeWithCompleteStripeReferences: number;
    activeWithoutStripeReferences: number;
    partialStripeReferences: number;
    nonActiveWithStripeReferences: number;
  }>;
  foundationObjects: Readonly<{
    tablesPresent: number;
    indexesPresent: number;
    writeFenceTriggersPresent: number;
    entitlementAdminRolePresent: boolean;
    entitlementOperatorRolePresent: boolean;
    appAdministrativeWriteDenied: boolean;
    appMilestonePrivilegesPresent: boolean;
    adminPrivilegesPresent: boolean;
    operatorMembershipPresent: boolean;
  }> | null;
  inconsistencies: Readonly<{
    unexpectedSubscriptionStatuses: number;
    unexpectedEntitlementSources: number;
    stripeSourceWithoutCompleteReferences: number;
    nonStripeSourceWithStripeReferences: number;
    entitlementStatusMismatches: number;
  }>;
  integrityConsistent: boolean;
  safeToApply012: boolean;
}>;

type QueryableClient = Pick<pg.PoolClient, "query" | "release">;
type ConnectablePool = Pick<pg.Pool, "connect">;

/** Preserves safe operator error codes while suppressing database details. */
export async function runFl021MigrationPreflight(
  pool: ConnectablePool,
): Promise<Fl021MigrationPreflight> {
  try {
    return await inspectFl021MigrationPreflight(pool);
  } catch (error) {
    if (
      error instanceof Error &&
      error.message === "fl021_migration_concurrent"
    )
      throw error;
    // Database errors may contain SQL/object details and must not cross the
    // private operator boundary as an Error.cause.
    // eslint-disable-next-line preserve-caught-error
    throw new Error("fl021_preflight_unavailable");
  }
}

function count(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 0)
    throw new Error("fl021_preflight_invalid_aggregate");
  return parsed;
}

function distribution(
  rows: readonly Readonly<{ value: string; count: string | number }>[],
): Distribution[] {
  return rows.map((row) => ({ value: row.value, count: count(row.count) }));
}

/**
 * Takes a consistent MON-21 snapshot while excluding a concurrent runner.
 * The transaction is always rolled back and cannot mutate application state.
 */
export async function inspectFl021MigrationPreflight(
  pool: ConnectablePool,
): Promise<Fl021MigrationPreflight> {
  const client = (await pool.connect()) as QueryableClient;
  let transactionStarted = false;
  try {
    await client.query("BEGIN READ ONLY");
    transactionStarted = true;
    await client.query("SET LOCAL lock_timeout = '1s'");
    await client.query("SET LOCAL statement_timeout = '5s'");
    await client.query("SET LOCAL idle_in_transaction_session_timeout = '5s'");

    const lock = await client.query<{ acquired: boolean }>(
      "SELECT pg_try_advisory_xact_lock(hashtext($1)) AS acquired",
      [MIGRATION_ADVISORY_LOCK_NAME],
    );
    if (lock.rows[0]?.acquired !== true)
      throw new Error("fl021_migration_concurrent");

    const migrations = await client.query<{ name: string; count: string }>(
      `SELECT name, count(*)::text AS count
         FROM schema_migrations
        WHERE name = ANY($1::text[])
        GROUP BY name
        ORDER BY name`,
      [[...requiredMigrations]],
    );
    const migrationCounts = new Map(
      migrations.rows.map((row) => [row.name, count(row.count)]),
    );

    const columns = await client.query<{
      entitlement_source: boolean;
      stripe_customer_id: boolean;
      stripe_subscription_id: boolean;
    }>(
      `SELECT
         EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema='public' AND table_name='accounts'
                    AND column_name='entitlement_source') AS entitlement_source,
         EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema='public' AND table_name='accounts'
                    AND column_name='stripe_customer_id') AS stripe_customer_id,
         EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema='public' AND table_name='accounts'
                    AND column_name='stripe_subscription_id') AS stripe_subscription_id`,
    );
    const columnState = columns.rows[0];
    if (!columnState) throw new Error("fl021_preflight_schema_unavailable");

    const totals = await client.query<{
      accounts: string;
      trial_leads_used: string;
    }>(
      `SELECT count(*)::text AS accounts,
              COALESCE(sum(trial_leads_used), 0)::text AS trial_leads_used
         FROM accounts`,
    );
    const totalRow = totals.rows[0];
    if (!totalRow) throw new Error("fl021_preflight_aggregate_unavailable");

    const statuses = await client.query<{ value: string; count: string }>(
      `SELECT subscription_status AS value, count(*)::text AS count
         FROM accounts
        GROUP BY subscription_status
        ORDER BY subscription_status`,
    );

    const stripeColumnsAvailable =
      columnState.stripe_customer_id && columnState.stripe_subscription_id;
    const bindingRow = stripeColumnsAvailable
      ? (
          await client.query<{
            active_complete: string;
            active_none: string;
            partial: string;
            non_active_any: string;
          }>(
            `SELECT
               count(*) FILTER (WHERE subscription_status='active'
                 AND stripe_customer_id IS NOT NULL
                 AND stripe_subscription_id IS NOT NULL)::text AS active_complete,
               count(*) FILTER (WHERE subscription_status='active'
                 AND stripe_customer_id IS NULL
                 AND stripe_subscription_id IS NULL)::text AS active_none,
               count(*) FILTER (WHERE (stripe_customer_id IS NULL)
                 <> (stripe_subscription_id IS NULL))::text AS partial,
               count(*) FILTER (WHERE subscription_status<>'active'
                 AND (stripe_customer_id IS NOT NULL
                   OR stripe_subscription_id IS NOT NULL))::text AS non_active_any
             FROM accounts`,
          )
        ).rows[0]
      : undefined;

    const unexpectedStatuses = await client.query<{ count: string }>(
      `SELECT count(*)::text AS count FROM accounts
        WHERE subscription_status NOT IN ('trial','trial_exhausted','active','expired')`,
    );

    let sources: Distribution[] | null = null;
    let unexpectedSources = 0;
    let stripeSourceWithoutCompleteReferences = 0;
    let nonStripeSourceWithStripeReferences = 0;
    let entitlementStatusMismatches = 0;
    let foundationObjects: Fl021MigrationPreflight["foundationObjects"] = null;
    if (columnState.entitlement_source) {
      sources = distribution(
        (
          await client.query<{ value: string; count: string }>(
            `SELECT entitlement_source AS value, count(*)::text AS count
               FROM accounts
              GROUP BY entitlement_source
              ORDER BY entitlement_source`,
          )
        ).rows,
      );
      const sourceChecks = await client.query<{
        unexpected_sources: string;
        stripe_without_complete: string;
        non_stripe_with_references: string;
        status_mismatches: string;
      }>(
        stripeColumnsAvailable
          ? `SELECT
           count(*) FILTER (WHERE entitlement_source NOT IN
             ('trial','administrative','stripe','legacy_active'))::text
             AS unexpected_sources,
           count(*) FILTER (WHERE entitlement_source='stripe'
             AND (stripe_customer_id IS NULL OR stripe_subscription_id IS NULL))::text
             AS stripe_without_complete,
           count(*) FILTER (WHERE entitlement_source<>'stripe'
             AND (stripe_customer_id IS NOT NULL OR stripe_subscription_id IS NOT NULL))::text
             AS non_stripe_with_references,
           count(*) FILTER (WHERE
             (entitlement_source='trial'
               AND subscription_status NOT IN ('trial','trial_exhausted')) OR
             (entitlement_source='administrative' AND subscription_status<>'active') OR
             (entitlement_source='legacy_active' AND subscription_status<>'active') OR
             (entitlement_source='stripe'
               AND subscription_status NOT IN ('active','expired'))
           )::text AS status_mismatches
         FROM accounts`
          : `SELECT
           count(*) FILTER (WHERE entitlement_source NOT IN
             ('trial','administrative','stripe','legacy_active'))::text
             AS unexpected_sources,
           count(*) FILTER (WHERE entitlement_source='stripe')::text
             AS stripe_without_complete,
           0::text AS non_stripe_with_references,
           count(*) FILTER (WHERE
             (entitlement_source='trial'
               AND subscription_status NOT IN ('trial','trial_exhausted')) OR
             (entitlement_source='administrative' AND subscription_status<>'active') OR
             (entitlement_source='legacy_active' AND subscription_status<>'active') OR
             (entitlement_source='stripe'
               AND subscription_status NOT IN ('active','expired'))
           )::text AS status_mismatches
         FROM accounts`,
      );
      const checks = sourceChecks.rows[0];
      if (!checks) throw new Error("fl021_preflight_aggregate_unavailable");
      unexpectedSources = count(checks.unexpected_sources);
      stripeSourceWithoutCompleteReferences = count(
        checks.stripe_without_complete,
      );
      nonStripeSourceWithStripeReferences = count(
        checks.non_stripe_with_references,
      );
      entitlementStatusMismatches = count(checks.status_mismatches);

      const objects = await client.query<{
        tables_present: string;
        indexes_present: string;
        triggers_present: string;
        admin_role_present: boolean;
        operator_role_present: boolean;
        app_admin_write: boolean;
        app_milestone_select: boolean;
        app_milestone_insert: boolean;
        app_milestone_update: boolean;
        admin_grants_select: boolean;
        admin_grants_insert: boolean;
        admin_grants_update: boolean;
        admin_audit_select: boolean;
        admin_audit_insert: boolean;
        operator_membership: boolean;
      }>(
        `SELECT
           (SELECT count(*) FROM (VALUES
             (to_regclass('public.entitlement_grants')),
             (to_regclass('public.entitlement_grant_audit')),
             (to_regclass('public.trial_milestone_events'))
           ) AS tables(regclass) WHERE regclass IS NOT NULL)::text AS tables_present,
           (SELECT count(*) FROM pg_indexes
             WHERE schemaname='public' AND indexname IN
               ('one_active_administrative_grant_per_account',
                'trial_milestone_delivery_due_idx'))::text AS indexes_present,
           (SELECT count(*) FROM pg_trigger
             WHERE tgname='account_deletion_write_fence' AND NOT tgisinternal
               AND tgrelid IN (
                 to_regclass('public.entitlement_grants'),
                 to_regclass('public.entitlement_grant_audit'),
                 to_regclass('public.trial_milestone_events')
               ))::text AS triggers_present,
           EXISTS (SELECT 1 FROM pg_roles
             WHERE rolname='foloo_entitlement_admin') AS admin_role_present,
           EXISTS (SELECT 1 FROM pg_roles
             WHERE rolname='foloo_entitlement_operator') AS operator_role_present,
           COALESCE(has_table_privilege('foloo_app',
             to_regclass('public.entitlement_grants'),'INSERT,UPDATE,DELETE'), false)
             OR COALESCE(has_table_privilege('foloo_app',
               to_regclass('public.entitlement_grant_audit'),'INSERT,UPDATE,DELETE'), false)
             AS app_admin_write,
           COALESCE(has_table_privilege('foloo_app',
             to_regclass('public.trial_milestone_events'),'SELECT'), false)
             AS app_milestone_select,
           COALESCE(has_table_privilege('foloo_app',
             to_regclass('public.trial_milestone_events'),'INSERT'), false)
             AS app_milestone_insert,
           COALESCE(has_table_privilege('foloo_app',
             to_regclass('public.trial_milestone_events'),'UPDATE'), false)
             AS app_milestone_update,
           CASE WHEN EXISTS (SELECT 1 FROM pg_roles
             WHERE rolname='foloo_entitlement_admin') THEN
             COALESCE(has_table_privilege('foloo_entitlement_admin',
               to_regclass('public.entitlement_grants'),'SELECT'), false)
             ELSE false END
             AS admin_grants_select,
           CASE WHEN EXISTS (SELECT 1 FROM pg_roles
             WHERE rolname='foloo_entitlement_admin') THEN
             COALESCE(has_table_privilege('foloo_entitlement_admin',
               to_regclass('public.entitlement_grants'),'INSERT'), false)
             ELSE false END
             AS admin_grants_insert,
           CASE WHEN EXISTS (SELECT 1 FROM pg_roles
             WHERE rolname='foloo_entitlement_admin') THEN
             COALESCE(has_table_privilege('foloo_entitlement_admin',
               to_regclass('public.entitlement_grants'),'UPDATE'), false)
             ELSE false END
             AS admin_grants_update,
           CASE WHEN EXISTS (SELECT 1 FROM pg_roles
             WHERE rolname='foloo_entitlement_admin') THEN
             COALESCE(has_table_privilege('foloo_entitlement_admin',
               to_regclass('public.entitlement_grant_audit'),'SELECT'), false)
             ELSE false END
             AS admin_audit_select,
           CASE WHEN EXISTS (SELECT 1 FROM pg_roles
             WHERE rolname='foloo_entitlement_admin') THEN
             COALESCE(has_table_privilege('foloo_entitlement_admin',
               to_regclass('public.entitlement_grant_audit'),'INSERT'), false)
             ELSE false END
             AS admin_audit_insert,
           CASE WHEN EXISTS (SELECT 1 FROM pg_roles
             WHERE rolname='foloo_entitlement_operator')
             AND EXISTS (SELECT 1 FROM pg_roles
               WHERE rolname='foloo_entitlement_admin') THEN
             pg_has_role('foloo_entitlement_operator',
               'foloo_entitlement_admin','MEMBER')
             ELSE false END
             AS operator_membership`,
      );
      const objectState = objects.rows[0];
      if (!objectState)
        throw new Error("fl021_preflight_aggregate_unavailable");
      foundationObjects = {
        tablesPresent: count(objectState.tables_present),
        indexesPresent: count(objectState.indexes_present),
        writeFenceTriggersPresent: count(objectState.triggers_present),
        entitlementAdminRolePresent: objectState.admin_role_present,
        entitlementOperatorRolePresent: objectState.operator_role_present,
        appAdministrativeWriteDenied: !objectState.app_admin_write,
        appMilestonePrivilegesPresent:
          objectState.app_milestone_select &&
          objectState.app_milestone_insert &&
          objectState.app_milestone_update,
        adminPrivilegesPresent:
          objectState.admin_grants_select &&
          objectState.admin_grants_insert &&
          objectState.admin_grants_update &&
          objectState.admin_audit_select &&
          objectState.admin_audit_insert,
        operatorMembershipPresent: objectState.operator_membership,
      };
    }

    const migration010Count = migrationCounts.get(requiredMigrations[0]) ?? 0;
    const migration011Count = migrationCounts.get(requiredMigrations[1]) ?? 0;
    const migration012Count = migrationCounts.get(requiredMigrations[2]) ?? 0;
    const partialStripeReferences = count(bindingRow?.partial ?? 0);
    const nonActiveWithStripeReferences = count(
      bindingRow?.non_active_any ?? 0,
    );
    const unexpectedSubscriptionStatuses = count(
      unexpectedStatuses.rows[0]?.count ?? 0,
    );
    const foundationConsistent =
      foundationObjects === null ||
      (foundationObjects.tablesPresent === 3 &&
        foundationObjects.indexesPresent === 2 &&
        foundationObjects.writeFenceTriggersPresent === 3 &&
        foundationObjects.entitlementAdminRolePresent &&
        foundationObjects.entitlementOperatorRolePresent &&
        foundationObjects.appAdministrativeWriteDenied &&
        foundationObjects.appMilestonePrivilegesPresent &&
        foundationObjects.adminPrivilegesPresent &&
        foundationObjects.operatorMembershipPresent);
    const integrityConsistent =
      stripeColumnsAvailable &&
      partialStripeReferences === 0 &&
      // Before 012 these rows would be backfilled as trial despite retaining
      // commercial references; require review instead of silently classifying.
      (!columnState.entitlement_source
        ? nonActiveWithStripeReferences === 0
        : true) &&
      unexpectedSubscriptionStatuses === 0 &&
      unexpectedSources === 0 &&
      stripeSourceWithoutCompleteReferences === 0 &&
      nonStripeSourceWithStripeReferences === 0 &&
      entitlementStatusMismatches === 0 &&
      foundationConsistent;

    return {
      migrations: {
        migration010Count,
        migration011Count,
        migration012Count,
      },
      schema: {
        entitlementSourceAvailable: columnState.entitlement_source,
        stripeReferenceColumnsAvailable: stripeColumnsAvailable,
      },
      totals: {
        accounts: count(totalRow.accounts),
        trialLeadsUsed: count(totalRow.trial_leads_used),
      },
      subscriptionStatusDistribution: distribution(statuses.rows),
      entitlementSourceDistribution: sources,
      commercialBindings: {
        activeWithCompleteStripeReferences: count(
          bindingRow?.active_complete ?? 0,
        ),
        activeWithoutStripeReferences: count(bindingRow?.active_none ?? 0),
        partialStripeReferences,
        nonActiveWithStripeReferences,
      },
      foundationObjects,
      inconsistencies: {
        unexpectedSubscriptionStatuses,
        unexpectedEntitlementSources: unexpectedSources,
        stripeSourceWithoutCompleteReferences,
        nonStripeSourceWithStripeReferences,
        entitlementStatusMismatches,
      },
      integrityConsistent,
      safeToApply012:
        migration010Count === 1 &&
        migration011Count === 1 &&
        migration012Count === 0 &&
        !columnState.entitlement_source &&
        integrityConsistent,
    };
  } finally {
    if (transactionStarted) await client.query("ROLLBACK").catch(() => {});
    client.release();
  }
}
