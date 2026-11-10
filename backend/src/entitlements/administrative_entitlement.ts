/** Administrative PRO grants bound to a verified Cognito identity.
 *
 * This boundary is intentionally independent from Stripe. Callers must be
 * IAM-authorized and identities are resolved server-side before PostgreSQL is
 * mutated (MON-04/MON-05).
 */

import type pg from "pg";

export type VerifiedCognitoIdentity = {
  subject: string;
  emailVerified: true;
};

export interface VerifiedCognitoIdentityResolver {
  resolveVerifiedEmail(email: string): Promise<VerifiedCognitoIdentity>;
}

export type AdministrativeEntitlementCommand =
  | { action: "status"; email: string }
  | {
      action: "grant" | "revoke";
      email: string;
      actor: string;
      reason: string;
    };

export type AdministrativeEntitlementResult = {
  action: "status" | "granted" | "revoked" | "unchanged";
  entitlement: "PRO" | "FREE";
  subscriptionStatus?: string;
  entitlementSource?: string;
  trialLeadsUsed?: number;
};

export class AdministrativeEntitlementService {
  constructor(
    private readonly pool: pg.Pool,
    private readonly identities: VerifiedCognitoIdentityResolver,
  ) {}

  async execute(
    command: AdministrativeEntitlementCommand,
  ): Promise<AdministrativeEntitlementResult> {
    const email = command.email.trim().toLowerCase();
    if (!email || !email.includes("@")) {
      throw new Error("A valid administrative entitlement email is required.");
    }
    const identity = await this.identities.resolveVerifiedEmail(email);
    if (!identity.emailVerified || !identity.subject.trim()) {
      throw new Error("Administrative entitlement identity is not verified.");
    }
    if (command.action === "status") return this.status(identity.subject);
    const actor = requiredText(command.actor, "actor", 160);
    const reason = requiredText(command.reason, "reason", 500);
    return command.action === "grant"
      ? this.grant(identity.subject, actor, reason)
      : this.revoke(identity.subject, actor, reason);
  }

  private async grant(
    subject: string,
    actor: string,
    reason: string,
  ): Promise<AdministrativeEntitlementResult> {
    const db = await this.pool.connect();
    try {
      await db.query("BEGIN");
      await db.query("SET LOCAL ROLE foloo_entitlement_admin");
      const account = await accountForSubject(db, subject, true);
      const existing = await db.query<{ id: string }>(
        `SELECT id FROM entitlement_grants
         WHERE account_id=$1 AND source='administrative' AND status='active'
         FOR UPDATE`,
        [account.id],
      );
      if (account.entitlement_source === "administrative") {
        if (existing.rowCount === 1) {
          await db.query("COMMIT");
          return { action: "unchanged", entitlement: "PRO" };
        }
        throw new Error("Administrative entitlement state is inconsistent.");
      }
      if (
        account.entitlement_source !== "trial" ||
        !["trial", "trial_exhausted"].includes(account.subscription_status) ||
        account.stripe_customer_id !== null ||
        account.stripe_subscription_id !== null
      ) {
        throw new Error(
          "Existing entitlements cannot be replaced administratively.",
        );
      }
      if (existing.rowCount)
        throw new Error("Administrative entitlement state is inconsistent.");
      const inserted = await db.query<{ id: string }>(
        `INSERT INTO entitlement_grants
           (account_id,source,status,grant_origin,granted_by,reason,
            previous_subscription_status,previous_entitlement_source)
         VALUES ($1,'administrative','active','manual',$2,$3,$4,$5)
         RETURNING id`,
        [
          account.id,
          actor,
          reason,
          account.subscription_status,
          account.entitlement_source,
        ],
      );
      const grantId = inserted.rows[0]?.id;
      if (!grantId) throw new Error("Administrative grant was not persisted.");
      await db.query(
        `INSERT INTO entitlement_grant_audit
           (grant_id,account_id,action,actor,reason,grant_origin)
         VALUES ($1,$2,'granted',$3,$4,'manual')`,
        [grantId, account.id, actor, reason],
      );
      const updated = await db.query(
        `UPDATE accounts SET subscription_status='active',
           entitlement_source='administrative', entitlement_updated_at=now(),
           updated_at=now()
         WHERE id=$1 AND entitlement_source='trial'
           AND subscription_status=$2
           AND stripe_customer_id IS NULL AND stripe_subscription_id IS NULL
         RETURNING id`,
        [account.id, account.subscription_status],
      );
      if (updated.rowCount !== 1)
        throw new Error("Administrative entitlement changed concurrently.");
      await db.query("COMMIT");
      return { action: "granted", entitlement: "PRO" };
    } catch (error) {
      await db.query("ROLLBACK");
      throw error;
    } finally {
      db.release();
    }
  }

  private async revoke(
    subject: string,
    actor: string,
    reason: string,
  ): Promise<AdministrativeEntitlementResult> {
    const db = await this.pool.connect();
    try {
      await db.query("BEGIN");
      await db.query("SET LOCAL ROLE foloo_entitlement_admin");
      const account = await accountForSubject(db, subject, true);
      const active = await db.query<{
        id: string;
        previous_subscription_status: "trial" | "trial_exhausted";
        previous_entitlement_source: "trial";
        grant_origin: "manual" | "preauthorization";
        preauthorization_id: string | null;
      }>(
        `SELECT id,previous_subscription_status,previous_entitlement_source,
                grant_origin,preauthorization_id
         FROM entitlement_grants
         WHERE account_id=$1 AND source='administrative' AND status='active'
         FOR UPDATE`,
        [account.id],
      );
      const grantId = active.rows[0]?.id;
      if (!grantId) {
        if (account.entitlement_source === "administrative")
          throw new Error("Administrative entitlement state is inconsistent.");
        await db.query("COMMIT");
        return {
          action: "unchanged",
          entitlement:
            account.subscription_status === "active" ? "PRO" : "FREE",
        };
      }
      if (account.entitlement_source !== "administrative")
        throw new Error("Administrative entitlement state is inconsistent.");
      if (
        active.rows[0]!.grant_origin === "preauthorization" &&
        !active.rows[0]!.preauthorization_id
      ) {
        throw new Error("Administrative entitlement state is inconsistent.");
      }
      const revoked = await db.query(
        `UPDATE entitlement_grants SET status='revoked', revoked_by=$2,
           revoked_reason=$3, revoked_at=now()
         WHERE id=$1 AND status='active' RETURNING id`,
        [grantId, actor, reason],
      );
      if (revoked.rowCount !== 1)
        throw new Error("Administrative grant changed concurrently.");
      await db.query(
        `INSERT INTO entitlement_grant_audit
           (grant_id,account_id,action,actor,reason,grant_origin)
         VALUES ($1,$2,'revoked',$3,$4,$5)`,
        [grantId, account.id, actor, reason, active.rows[0]!.grant_origin],
      );
      const restored = await db.query(
        `UPDATE accounts SET
           subscription_status=$2,
           entitlement_source=$3, entitlement_updated_at=now(),
           updated_at=now()
         WHERE id=$1 AND entitlement_source='administrative'`,
        [
          account.id,
          active.rows[0]!.previous_subscription_status,
          active.rows[0]!.previous_entitlement_source,
        ],
      );
      if (restored.rowCount !== 1)
        throw new Error("Administrative entitlement changed concurrently.");
      if (active.rows[0]!.preauthorization_id) {
        const invalidated = await db.query(
          `UPDATE entitlement_preauthorizations
           SET status='revoked',bound_account_id=NULL,revoked_by=$2,
               revoked_reason=$3,revoked_at=now()
           WHERE id=$1 AND status='consumed' RETURNING id`,
          [active.rows[0]!.preauthorization_id, actor, reason],
        );
        if (invalidated.rowCount !== 1) {
          throw new Error("Entitlement preauthorization changed concurrently.");
        }
        await db.query(
          `INSERT INTO entitlement_preauthorization_audit
             (preauthorization_id,account_id,action,actor,reason)
           VALUES ($1,$2,'revoked',$3,$4)`,
          [active.rows[0]!.preauthorization_id, account.id, actor, reason],
        );
      }
      await db.query("COMMIT");
      return { action: "revoked", entitlement: "FREE" };
    } catch (error) {
      await db.query("ROLLBACK");
      throw error;
    } finally {
      db.release();
    }
  }

  private async status(
    subject: string,
  ): Promise<AdministrativeEntitlementResult> {
    const db = await this.pool.connect();
    try {
      await db.query("BEGIN READ ONLY");
      await db.query("SET LOCAL ROLE foloo_entitlement_admin");
      const account = await accountForSubject(db, subject, false);
      assertCoherentEntitlement(account);
      await db.query("COMMIT");
      return {
        action: "status",
        entitlement: account.subscription_status === "active" ? "PRO" : "FREE",
        subscriptionStatus: account.subscription_status,
        entitlementSource: account.entitlement_source,
        trialLeadsUsed: account.trial_leads_used,
      };
    } catch (error) {
      await db.query("ROLLBACK");
      throw error;
    } finally {
      db.release();
    }
  }
}

async function accountForSubject(
  db: pg.PoolClient,
  subject: string,
  lock: boolean,
): Promise<{
  id: string;
  subscription_status: string;
  entitlement_source: string;
  trial_leads_used: number;
  stripe_customer_id: string | null;
  stripe_subscription_id: string | null;
}> {
  const result = await db.query<{
    id: string;
    subscription_status: string;
    entitlement_source: string;
    trial_leads_used: number;
    stripe_customer_id: string | null;
    stripe_subscription_id: string | null;
  }>(
    `SELECT a.id,a.subscription_status,a.entitlement_source,a.trial_leads_used,
            a.stripe_customer_id,a.stripe_subscription_id FROM app_users u
     JOIN accounts a ON a.owner_user_id=u.id AND a.deleted_at IS NULL
     WHERE u.cognito_sub=$1${lock ? " FOR UPDATE OF a" : ""}`,
    [subject],
  );
  const account = result.rows[0];
  if (!account || result.rowCount !== 1) {
    throw new Error("Verified Cognito identity has no unique Foloo account.");
  }
  return account;
}

function assertCoherentEntitlement(account: {
  subscription_status: string;
  entitlement_source: string;
  stripe_customer_id: string | null;
  stripe_subscription_id: string | null;
}): void {
  const allowed = new Set([
    "trial:trial",
    "trial_exhausted:trial",
    "active:administrative",
    "active:stripe",
    "active:legacy_active",
  ]);
  if (
    !allowed.has(
      `${account.subscription_status}:${account.entitlement_source}`,
    ) ||
    (account.entitlement_source === "stripe") !==
      Boolean(account.stripe_customer_id && account.stripe_subscription_id)
  ) {
    throw new Error("Administrative entitlement state is inconsistent.");
  }
}

function requiredText(value: string, name: string, maximum: number): string {
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > maximum) {
    throw new Error(`${name} is invalid.`);
  }
  return trimmed;
}
