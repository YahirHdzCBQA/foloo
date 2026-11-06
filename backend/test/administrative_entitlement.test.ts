/** FL-021 administrative grants remain verified, auditable, and reversible. */

import assert from "node:assert/strict";
import test from "node:test";

import type pg from "pg";

import { AdministrativeEntitlementService } from "../src/entitlements/administrative_entitlement.js";

class GrantDatabase {
  activeGrant = false;
  status = "trial_exhausted";
  source = "trial";
  trialLeadsUsed = 5;
  stripeCustomerId: string | null = null;
  stripeSubscriptionId: string | null = null;
  previousStatus: "trial" | "trial_exhausted" = "trial_exhausted";
  failAccountUpdate = false;
  failGrantRevocation = false;
  auditActions: string[] = [];

  async query<Row extends Record<string, unknown> = Record<string, unknown>>(
    sql: string,
  ) {
    if (sql.includes("SELECT a.id")) {
      return {
        rows: [
          {
            id: "account-a",
            subscription_status: this.status,
            entitlement_source: this.source,
            stripe_customer_id: this.stripeCustomerId,
            stripe_subscription_id: this.stripeSubscriptionId,
          } as unknown as Row,
        ],
        rowCount: 1,
      };
    }
    if (sql.includes("SELECT id FROM entitlement_grants")) {
      return {
        rows: this.activeGrant ? [{ id: "grant-a" } as unknown as Row] : [],
        rowCount: this.activeGrant ? 1 : 0,
      };
    }
    if (sql.includes("SELECT id,previous_subscription_status")) {
      return {
        rows: this.activeGrant
          ? [
              {
                id: "grant-a",
                previous_subscription_status: this.previousStatus,
                previous_entitlement_source: "trial",
              } as unknown as Row,
            ]
          : [],
        rowCount: this.activeGrant ? 1 : 0,
      };
    }
    if (sql.includes("INSERT INTO entitlement_grants")) {
      this.activeGrant = true;
      return { rows: [{ id: "grant-a" } as unknown as Row], rowCount: 1 };
    }
    if (sql.includes("INSERT INTO entitlement_grant_audit")) {
      this.auditActions.push(sql.includes("'granted'") ? "granted" : "revoked");
    }
    if (sql.includes("subscription_status='active'")) {
      if (this.failAccountUpdate) return { rows: [], rowCount: 0 };
      this.status = "active";
      this.source = "administrative";
      return { rows: [{ id: "account-a" } as unknown as Row], rowCount: 1 };
    }
    if (sql.includes("SET status='revoked'")) {
      if (this.failGrantRevocation) return { rows: [], rowCount: 0 };
      this.activeGrant = false;
      return { rows: [{ id: "grant-a" } as unknown as Row], rowCount: 1 };
    }
    if (sql.includes("subscription_status=$2")) {
      if (this.failAccountUpdate) return { rows: [], rowCount: 0 };
      this.status = this.previousStatus;
      this.source = "trial";
      return { rows: [], rowCount: 1 };
    }
    return { rows: [], rowCount: 0 };
  }

  async connect() {
    return { query: this.query.bind(this), release() {} };
  }
}

const verifiedIdentity = {
  resolveVerifiedEmail: async () => ({
    subject: "subject-a",
    emailVerified: true as const,
  }),
};

test("verified grant is idempotent, auditable, and preserves historical use", async () => {
  const database = new GrantDatabase();
  const service = new AdministrativeEntitlementService(
    database as unknown as pg.Pool,
    verifiedIdentity,
  );
  const command = {
    action: "grant" as const,
    email: "qa@example.test",
    actor: "admin-a",
    reason: "Approved Foloo V1 administrative grant",
  };
  assert.deepEqual(await service.execute(command), {
    action: "granted",
    entitlement: "PRO",
  });
  assert.deepEqual(await service.execute(command), {
    action: "unchanged",
    entitlement: "PRO",
  });
  assert.equal(database.trialLeadsUsed, 5);
  assert.deepEqual(database.auditActions, ["granted"]);
});

test("grant preserves the exact FREE state for trial and exhausted accounts", async () => {
  for (const status of ["trial", "trial_exhausted"] as const) {
    const database = new GrantDatabase();
    database.status = status;
    database.previousStatus = status;
    const service = new AdministrativeEntitlementService(
      database as unknown as pg.Pool,
      verifiedIdentity,
    );
    await service.execute({
      action: "grant",
      email: "qa@example.test",
      actor: "arn:aws:sts::123456789012:assumed-role/operator/session",
      reason: "Approved Foloo V1 administrative grant",
    });
    await service.execute({
      action: "revoke",
      email: "qa@example.test",
      actor: "arn:aws:sts::123456789012:assumed-role/operator/session",
      reason: "Administrative access ended",
    });
    assert.equal(database.status, status);
  }
});

test("revocation restores FREE without returning historical uses", async () => {
  const database = new GrantDatabase();
  database.activeGrant = true;
  database.status = "active";
  database.source = "administrative";
  const service = new AdministrativeEntitlementService(
    database as unknown as pg.Pool,
    verifiedIdentity,
  );
  assert.deepEqual(
    await service.execute({
      action: "revoke",
      email: "qa@example.test",
      actor: "admin-a",
      reason: "Administrative access ended",
    }),
    { action: "revoked", entitlement: "FREE" },
  );
  assert.equal(database.status, "trial_exhausted");
  assert.equal(database.trialLeadsUsed, 5);
  assert.deepEqual(database.auditActions, ["revoked"]);
});

test("administrative operations fail closed for legacy and Stripe entitlements", async () => {
  for (const source of ["legacy_active", "stripe"] as const) {
    const database = new GrantDatabase();
    database.status = "active";
    database.source = source;
    if (source === "stripe") {
      database.stripeCustomerId = "cus_synthetic";
      database.stripeSubscriptionId = "sub_synthetic";
    }
    const service = new AdministrativeEntitlementService(
      database as unknown as pg.Pool,
      verifiedIdentity,
    );
    await assert.rejects(
      service.execute({
        action: "grant",
        email: "qa@example.test",
        actor: "admin-a",
        reason: "Must not replace an existing entitlement",
      }),
      /cannot be replaced administratively/,
    );
    assert.equal(database.activeGrant, false);
    assert.deepEqual(database.auditActions, []);
  }
});

test("a Stripe binding blocks grants even when the cached status is FREE", async () => {
  const database = new GrantDatabase();
  database.stripeCustomerId = "cus_synthetic";
  database.stripeSubscriptionId = "sub_synthetic";
  const service = new AdministrativeEntitlementService(
    database as unknown as pg.Pool,
    verifiedIdentity,
  );
  await assert.rejects(
    service.execute({
      action: "grant",
      email: "qa@example.test",
      actor: "admin-a",
      reason: "Must not replace a commercial binding",
    }),
    /cannot be replaced administratively/,
  );
});

test("concurrent grant or revoke state changes roll back closed", async () => {
  const grantDatabase = new GrantDatabase();
  grantDatabase.failAccountUpdate = true;
  await assert.rejects(
    new AdministrativeEntitlementService(
      grantDatabase as unknown as pg.Pool,
      verifiedIdentity,
    ).execute({
      action: "grant",
      email: "qa@example.test",
      actor: "admin-a",
      reason: "Concurrent state test",
    }),
    /changed concurrently/,
  );

  const revokeDatabase = new GrantDatabase();
  revokeDatabase.activeGrant = true;
  revokeDatabase.status = "active";
  revokeDatabase.source = "administrative";
  revokeDatabase.failGrantRevocation = true;
  await assert.rejects(
    new AdministrativeEntitlementService(
      revokeDatabase as unknown as pg.Pool,
      verifiedIdentity,
    ).execute({
      action: "revoke",
      email: "qa@example.test",
      actor: "admin-a",
      reason: "Concurrent state test",
    }),
    /changed concurrently/,
  );
});

test("unverified identity is rejected before database mutation", async () => {
  const database = new GrantDatabase();
  const service = new AdministrativeEntitlementService(
    database as unknown as pg.Pool,
    {
      resolveVerifiedEmail: async () => {
        throw new Error("identity_not_verified");
      },
    },
  );
  await assert.rejects(
    service.execute({
      action: "grant",
      email: "qa@example.test",
      actor: "admin-a",
      reason: "Verification required",
    }),
    /identity_not_verified/,
  );
  assert.deepEqual(database.auditActions, []);
});
