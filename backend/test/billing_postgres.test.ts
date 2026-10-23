/** MON-15/MON-16: optional isolated PostgreSQL verification of migration and real SQL. */
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import pg from "pg";
import {
  PostgresBillingRepository,
  type BillingEvent,
} from "../src/billing/postgres_billing_repository.js";

test(
  "MON-15/MON-16 real PostgreSQL serializes billing, preserves expiry and restricts grants",
  { skip: !process.env.BILLING_TEST_DATABASE_URL },
  async () => {
    const connectionString = process.env.BILLING_TEST_DATABASE_URL;
    const schema = `billing_test_${process.pid}_${Date.now()}`;
    const admin = new pg.Pool({
      connectionString,
      options: `-c search_path=${schema}`,
    });
    const pool = new pg.Pool({
      connectionString,
      options: `-c search_path=${schema} -c role=foloo_app`,
    });
    try {
      await admin.query(`CREATE SCHEMA ${schema}`);
      await admin.query(
        `DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='foloo_app') THEN CREATE ROLE foloo_app; END IF; END $$`,
      );
      await admin.query(`CREATE TABLE app_users(id uuid PRIMARY KEY, cognito_sub text UNIQUE NOT NULL);
      CREATE TABLE accounts(id uuid PRIMARY KEY, owner_user_id uuid REFERENCES app_users(id), subscription_status text NOT NULL DEFAULT 'trial_exhausted', deleted_at timestamptz, updated_at timestamptz, entitlement_updated_at timestamptz);
      GRANT USAGE ON SCHEMA ${schema} TO foloo_app;
      GRANT SELECT ON app_users TO foloo_app;
      GRANT SELECT, UPDATE ON accounts TO foloo_app;
      ALTER DEFAULT PRIVILEGES IN SCHEMA ${schema} GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO foloo_app;`);
      await admin.query(
        await readFile(
          new URL("../migrations/011_billing_stripe.sql", import.meta.url),
          "utf8",
        ),
      );
      const id = "d7ca7b4c-5f14-4160-9f07-0cf05b1fd661";
      await admin.query("INSERT INTO app_users VALUES ($1,'alice');", [id]);
      await admin.query(
        "INSERT INTO accounts(id,owner_user_id) VALUES ($1,$1)",
        [id],
      );
      const repo = new PostgresBillingRepository(pool);
      const customers = await Promise.all([
        repo.linkCustomer(id, "cus_a"),
        repo.linkCustomer(id, "cus_b"),
      ]);
      assert.equal(customers[0], customers[1]);
      const customer = customers[0];
      const checkout: BillingEvent = {
        id: "evt_checkout",
        created: 100,
        type: "checkout.session.completed",
        data: {
          object: {
            mode: "subscription",
            client_reference_id: id,
            metadata: { sub: "alice", origin: "foloo-app" },
            customer,
            subscription: "sub_a",
            payment_status: "unpaid",
          },
        },
      };
      const update: BillingEvent = {
        id: "evt_update",
        created: 200,
        type: "customer.subscription.updated",
        data: {
          object: {
            id: "sub_a",
            customer,
            status: "active",
            current_period_end: 1800000000,
          },
        },
      };
      await assert.rejects(() => repo.apply(update), /temporarily unavailable/);
      assert.equal(
        (await admin.query("SELECT * FROM billing_events")).rowCount,
        0,
      );
      await Promise.all(Array.from({ length: 8 }, () => repo.apply(checkout)));
      assert.equal(
        (await repo.account(id))?.subscriptionStatus,
        "trial_exhausted",
      );
      await repo.apply(update);
      assert.equal((await repo.account(id))?.subscriptionStatus, "active");
      await repo.apply({
        ...update,
        id: "evt_delete",
        created: 300,
        type: "customer.subscription.deleted",
      });
      await Promise.all([
        repo.apply({ ...update, id: "evt_late", created: 250 }),
        repo.apply({ ...update, id: "evt_tie", created: 300 }),
        repo.apply({
          ...checkout,
          id: "evt_checkout_late",
          created: 250,
          data: { object: { ...checkout.data.object, payment_status: "paid" } },
        }),
        repo.apply(update),
      ]);
      assert.equal((await repo.account(id))?.subscriptionStatus, "expired");
      assert.equal(
        (
          await admin.query(
            "SELECT extract(epoch FROM billing_event_at)::int AS at FROM accounts",
          )
        ).rows[0].at,
        300,
      );
      assert.equal(
        (await admin.query("SELECT * FROM billing_events")).rowCount,
        6,
      );
      const grants = (
        await admin.query(
          `SELECT has_table_privilege('foloo_app', '${schema}.billing_events', 'SELECT') AS read, has_table_privilege('foloo_app', '${schema}.billing_events', 'INSERT') AS insert, has_table_privilege('foloo_app', '${schema}.billing_events', 'UPDATE') AS update, has_table_privilege('foloo_app', '${schema}.billing_events', 'DELETE') AS delete`,
        )
      ).rows[0];
      assert.deepEqual(grants, {
        read: true,
        insert: true,
        update: false,
        delete: false,
      });
    } finally {
      await Promise.all([pool.end(), admin.end()]);
    }
  },
);
