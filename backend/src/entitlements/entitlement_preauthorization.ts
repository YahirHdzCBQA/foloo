/**
 * Owns private PRO preauthorization lifecycle and automatic consumption.
 * Every mutation is serialized in PostgreSQL and preserves commercial
 * entitlements, historical trial use, and account ownership (MON-01, MON-21).
 */

import type pg from "pg";

import type {
  EntitlementPreauthorizationSelector,
  VerifiedEmailSelector,
} from "./preauthorization_selector.js";

export type PreauthorizationCommand =
  | { action: "preauthorization-status"; email: string }
  | {
      action: "preauthorize" | "revoke-preauthorization";
      email: string;
      actor: string;
      reason: string;
    };

export type PreauthorizationResult = Readonly<{
  action: "preauthorization-status" | "preauthorized" | "revoked" | "unchanged";
  status: "absent" | "active" | "consumed" | "revoked";
}>;

export type AutomaticEntitlementResult = Readonly<{
  outcome:
    | "granted"
    | "unchanged"
    | "not-preauthorized"
    | "revoked"
    | "account-deletion-pending"
    | "commercial-conflict"
    | "administrative-conflict";
}>;

export class AccountProvisioningPendingError extends Error {
  constructor() {
    super("Verified identity has not completed account provisioning.");
    this.name = "AccountProvisioningPendingError";
  }
}

export class EntitlementPreauthorizationService {
  constructor(
    private readonly pool: pg.Pool,
    private readonly selectors: VerifiedEmailSelector,
  ) {}

  async execute(
    command: PreauthorizationCommand,
  ): Promise<PreauthorizationResult> {
    const selector = await this.selectors.select(command.email);
    if (command.action === "preauthorization-status") {
      return this.status(selector);
    }
    const actor = requiredText(command.actor, "actor", 160);
    const reason = requiredText(command.reason, "reason", 500);
    return command.action === "preauthorize"
      ? this.preauthorize(selector, actor, reason)
      : this.revoke(selector, actor, reason);
  }

  async consumeVerifiedIdentity(input: {
    subject: string;
    verifiedEmail: string;
  }): Promise<AutomaticEntitlementResult> {
    const subject = requiredText(input.subject, "subject", 2048);
    const selector = await this.selectors.select(input.verifiedEmail);
    const db = await this.pool.connect();
    try {
      await db.query("BEGIN");
      await db.query("SET LOCAL ROLE foloo_entitlement_admin");
      const observed = await selectPreauthorization(db, selector, false);
      if (!observed) {
        await db.query("COMMIT");
        return { outcome: "not-preauthorized" };
      }
      if (observed.status === "revoked") {
        await db.query("COMMIT");
        return { outcome: "revoked" };
      }

      // Account deletion locks the account before touching preauthorizations.
      // Match that order to avoid lock inversion with the deletion transaction.
      const account = await accountForSubject(db, subject);
      if (!account) throw new AccountProvisioningPendingError();
      const preauthorization = await selectPreauthorization(db, selector, true);
      if (!preauthorization) {
        await db.query("COMMIT");
        return { outcome: "not-preauthorized" };
      }
      if (preauthorization.status === "revoked") {
        await db.query("COMMIT");
        return { outcome: "revoked" };
      }

      assertCoherentAccount(account);
      if (account.deletion_pending_at !== null) {
        await db.query("COMMIT");
        return { outcome: "account-deletion-pending" };
      }

      if (preauthorization.status === "consumed") {
        const sameAccount = preauthorization.bound_account_id === account.id;
        const sameGrant = await activeAutomaticGrant(
          db,
          account.id,
          preauthorization.id,
        );
        if (
          sameAccount &&
          sameGrant &&
          account.entitlement_source === "administrative"
        ) {
          await db.query("COMMIT");
          return { outcome: "unchanged" };
        }
        throw new Error(
          "Consumed entitlement preauthorization is inconsistent.",
        );
      }

      if (
        account.entitlement_source === "stripe" ||
        account.entitlement_source === "legacy_active" ||
        account.stripe_customer_id !== null ||
        account.stripe_subscription_id !== null
      ) {
        await recordException(
          db,
          preauthorization.id,
          account.id,
          "commercial_entitlement_present",
        );
        await db.query("COMMIT");
        return { outcome: "commercial-conflict" };
      }
      if (account.entitlement_source === "administrative") {
        await recordException(
          db,
          preauthorization.id,
          account.id,
          "administrative_entitlement_present",
        );
        await db.query("COMMIT");
        return { outcome: "administrative-conflict" };
      }
      if (
        account.entitlement_source !== "trial" ||
        !["trial", "trial_exhausted"].includes(account.subscription_status)
      ) {
        throw new Error("Automatic entitlement state is inconsistent.");
      }

      const inserted = await db.query<{ id: string }>(
        `INSERT INTO entitlement_grants
           (account_id,source,status,grant_origin,preauthorization_id,
            granted_by,reason,previous_subscription_status,
            previous_entitlement_source)
         VALUES ($1,'administrative','active','preauthorization',$2,
           'system:cognito-post-authentication',
           'Verified email matched an active FL-021 preauthorization',$3,$4)
         RETURNING id`,
        [
          account.id,
          preauthorization.id,
          account.subscription_status,
          account.entitlement_source,
        ],
      );
      const grantId = inserted.rows[0]?.id;
      if (!grantId)
        throw new Error("Automatic entitlement grant was not persisted.");
      const accountUpdate = await db.query(
        `UPDATE accounts SET subscription_status='active',
           entitlement_source='administrative', entitlement_updated_at=now(),
           updated_at=now()
         WHERE id=$1 AND entitlement_source='trial'
           AND subscription_status=$2
           AND stripe_customer_id IS NULL AND stripe_subscription_id IS NULL
         RETURNING id`,
        [account.id, account.subscription_status],
      );
      if (accountUpdate.rowCount !== 1) {
        throw new Error("Automatic entitlement changed concurrently.");
      }
      const consumed = await db.query(
        `UPDATE entitlement_preauthorizations
         SET status='consumed',bound_account_id=$2,consumed_at=now(),
             last_exception_code=NULL,last_exception_at=NULL
         WHERE id=$1 AND status='active' RETURNING id`,
        [preauthorization.id, account.id],
      );
      if (consumed.rowCount !== 1) {
        throw new Error("Entitlement preauthorization changed concurrently.");
      }
      await db.query(
        `INSERT INTO entitlement_grant_audit
           (grant_id,account_id,action,actor,reason,grant_origin)
         VALUES ($1,$2,'granted','system:cognito-post-authentication',
          'Verified email matched an active FL-021 preauthorization',
          'preauthorization')`,
        [grantId, account.id],
      );
      await db.query(
        `INSERT INTO entitlement_preauthorization_audit
           (preauthorization_id,account_id,action,actor,reason)
         VALUES ($1,$2,'consumed','system:cognito-post-authentication',
          'Verified identity consumed the approved preauthorization')`,
        [preauthorization.id, account.id],
      );
      await db.query("COMMIT");
      return { outcome: "granted" };
    } catch (error) {
      await db.query("ROLLBACK");
      throw error;
    } finally {
      db.release();
    }
  }

  private async status(
    selector: EntitlementPreauthorizationSelector,
  ): Promise<PreauthorizationResult> {
    const db = await this.pool.connect();
    try {
      await db.query("BEGIN READ ONLY");
      await db.query("SET LOCAL ROLE foloo_entitlement_admin");
      const current = await selectPreauthorization(db, selector, false);
      await db.query("COMMIT");
      return {
        action: "preauthorization-status",
        status: current?.status ?? "absent",
      };
    } catch (error) {
      await db.query("ROLLBACK");
      throw error;
    } finally {
      db.release();
    }
  }

  private async preauthorize(
    selector: EntitlementPreauthorizationSelector,
    actor: string,
    reason: string,
  ): Promise<PreauthorizationResult> {
    const db = await this.pool.connect();
    try {
      await db.query("BEGIN");
      await db.query("SET LOCAL ROLE foloo_entitlement_admin");
      const current = await selectPreauthorization(db, selector, true);
      if (current) {
        if (current.status === "revoked") {
          const reauthorized = await db.query(
            `UPDATE entitlement_preauthorizations
             SET status='active',authorized_by=$2,authorization_reason=$3,
                 bound_account_id=NULL,consumed_at=NULL,revoked_by=NULL,
                 revoked_reason=NULL,revoked_at=NULL,
                 last_exception_code=NULL,last_exception_at=NULL
             WHERE id=$1 AND status='revoked' RETURNING id`,
            [current.id, actor, reason],
          );
          if (reauthorized.rowCount !== 1) {
            throw new Error(
              "Entitlement preauthorization changed concurrently.",
            );
          }
          await db.query(
            `INSERT INTO entitlement_preauthorization_audit
               (preauthorization_id,action,actor,reason)
             VALUES ($1,'preauthorized',$2,$3)`,
            [current.id, actor, reason],
          );
          await db.query("COMMIT");
          return { action: "preauthorized", status: "active" };
        }
        await db.query("COMMIT");
        return { action: "unchanged", status: current.status };
      }
      const inserted = await db.query<{ id: string }>(
        `INSERT INTO entitlement_preauthorizations
           (key_version,canonicalization_policy,email_digest,status,
            authorized_by,authorization_reason)
         VALUES ($1,$2,$3,'active',$4,$5) RETURNING id`,
        [
          selector.keyVersion,
          selector.canonicalizationPolicy,
          selector.digest,
          actor,
          reason,
        ],
      );
      const id = inserted.rows[0]?.id;
      if (!id)
        throw new Error("Entitlement preauthorization was not persisted.");
      await db.query(
        `INSERT INTO entitlement_preauthorization_audit
           (preauthorization_id,action,actor,reason)
         VALUES ($1,'preauthorized',$2,$3)`,
        [id, actor, reason],
      );
      await db.query("COMMIT");
      return { action: "preauthorized", status: "active" };
    } catch (error) {
      await db.query("ROLLBACK");
      throw error;
    } finally {
      db.release();
    }
  }

  private async revoke(
    selector: EntitlementPreauthorizationSelector,
    actor: string,
    reason: string,
  ): Promise<PreauthorizationResult> {
    const db = await this.pool.connect();
    try {
      await db.query("BEGIN");
      await db.query("SET LOCAL ROLE foloo_entitlement_admin");
      const current = await selectPreauthorization(db, selector, true);
      if (!current || current.status === "revoked") {
        await db.query("COMMIT");
        return {
          action: "unchanged",
          status: current?.status ?? "absent",
        };
      }
      if (current.bound_account_id) {
        await revokeAutomaticGrant(
          db,
          current.bound_account_id,
          current.id,
          actor,
          reason,
        );
      }
      const revoked = await db.query(
        `UPDATE entitlement_preauthorizations
         SET status='revoked',bound_account_id=NULL,revoked_by=$2,
             revoked_reason=$3,revoked_at=now()
         WHERE id=$1 AND status IN ('active','consumed') RETURNING id`,
        [current.id, actor, reason],
      );
      if (revoked.rowCount !== 1) {
        throw new Error("Entitlement preauthorization changed concurrently.");
      }
      await db.query(
        `INSERT INTO entitlement_preauthorization_audit
           (preauthorization_id,account_id,action,actor,reason)
         VALUES ($1,$2,'revoked',$3,$4)`,
        [current.id, current.bound_account_id, actor, reason],
      );
      await db.query("COMMIT");
      return { action: "revoked", status: "revoked" };
    } catch (error) {
      await db.query("ROLLBACK");
      throw error;
    } finally {
      db.release();
    }
  }
}

type PreauthorizationRow = Readonly<{
  id: string;
  status: "active" | "consumed" | "revoked";
  bound_account_id: string | null;
}>;

async function selectPreauthorization(
  db: pg.PoolClient,
  selector: EntitlementPreauthorizationSelector,
  lock: boolean,
): Promise<PreauthorizationRow | undefined> {
  const result = await db.query<PreauthorizationRow>(
    `SELECT id,status,bound_account_id FROM entitlement_preauthorizations
     WHERE key_version=$1 AND email_digest=$2${lock ? " FOR UPDATE" : ""}`,
    [selector.keyVersion, selector.digest],
  );
  if ((result.rowCount ?? 0) > 1) {
    throw new Error("Entitlement preauthorization is ambiguous.");
  }
  return result.rows[0];
}

type AccountRow = Readonly<{
  id: string;
  subscription_status: string;
  entitlement_source: string;
  stripe_customer_id: string | null;
  stripe_subscription_id: string | null;
  deletion_pending_at: Date | null;
}>;

async function accountForSubject(
  db: pg.PoolClient,
  subject: string,
): Promise<AccountRow | undefined> {
  const result = await db.query<AccountRow>(
    `SELECT a.id,a.subscription_status,a.entitlement_source,
            a.stripe_customer_id,a.stripe_subscription_id,
            u.deletion_pending_at
     FROM app_users u
     JOIN accounts a ON a.owner_user_id=u.id AND a.deleted_at IS NULL
     WHERE u.cognito_sub=$1 FOR UPDATE OF a`,
    [subject],
  );
  if ((result.rowCount ?? 0) > 1) {
    throw new Error(
      "Verified Cognito identity has an ambiguous Foloo account.",
    );
  }
  return result.rows[0];
}

async function activeAutomaticGrant(
  db: pg.PoolClient,
  accountId: string,
  preauthorizationId: string,
): Promise<boolean> {
  const result = await db.query(
    `SELECT id FROM entitlement_grants
     WHERE account_id=$1 AND preauthorization_id=$2
       AND grant_origin='preauthorization' AND status='active'`,
    [accountId, preauthorizationId],
  );
  return result.rowCount === 1;
}

async function recordException(
  db: pg.PoolClient,
  preauthorizationId: string,
  accountId: string,
  code: string,
): Promise<void> {
  await db.query(
    `WITH changed AS (
       UPDATE entitlement_preauthorizations
       SET last_exception_code=$3,last_exception_at=now()
       WHERE id=$1 AND status='active'
         AND last_exception_code IS DISTINCT FROM $3
       RETURNING id
     )
     INSERT INTO entitlement_preauthorization_audit
       (preauthorization_id,account_id,action,actor,reason,exception_code)
     SELECT id,$2,'exception','system:cognito-post-authentication',
       'Automatic grant preserved an existing entitlement',$3
     FROM changed`,
    [preauthorizationId, accountId, code],
  );
}

async function revokeAutomaticGrant(
  db: pg.PoolClient,
  accountId: string,
  preauthorizationId: string,
  actor: string,
  reason: string,
): Promise<void> {
  const grant = await db.query<{
    id: string;
    previous_subscription_status: "trial" | "trial_exhausted";
    previous_entitlement_source: "trial";
  }>(
    `SELECT id,previous_subscription_status,previous_entitlement_source
     FROM entitlement_grants
     WHERE account_id=$1 AND preauthorization_id=$2
       AND grant_origin='preauthorization' AND status='active'
     FOR UPDATE`,
    [accountId, preauthorizationId],
  );
  const row = grant.rows[0];
  if (!row) return;
  const revoked = await db.query(
    `UPDATE entitlement_grants SET status='revoked',revoked_by=$2,
       revoked_reason=$3,revoked_at=now()
     WHERE id=$1 AND status='active' RETURNING id`,
    [row.id, actor, reason],
  );
  if (revoked.rowCount !== 1) {
    throw new Error("Automatic entitlement grant changed concurrently.");
  }
  const account = await db.query<{ entitlement_source: string }>(
    `SELECT entitlement_source FROM accounts WHERE id=$1 FOR UPDATE`,
    [accountId],
  );
  if (account.rows[0]?.entitlement_source === "administrative") {
    const restored = await db.query(
      `UPDATE accounts SET subscription_status=$2,entitlement_source=$3,
         entitlement_updated_at=now(),updated_at=now()
       WHERE id=$1 AND entitlement_source='administrative' RETURNING id`,
      [
        accountId,
        row.previous_subscription_status,
        row.previous_entitlement_source,
      ],
    );
    if (restored.rowCount !== 1) {
      throw new Error("Automatic entitlement changed concurrently.");
    }
  }
  await db.query(
    `INSERT INTO entitlement_grant_audit
       (grant_id,account_id,action,actor,reason,grant_origin)
     VALUES ($1,$2,'revoked',$3,$4,'preauthorization')`,
    [row.id, accountId, actor, reason],
  );
}

function assertCoherentAccount(account: AccountRow): void {
  const state = `${account.subscription_status}:${account.entitlement_source}`;
  const allowed = new Set([
    "trial:trial",
    "trial_exhausted:trial",
    "active:administrative",
    "active:stripe",
    "active:legacy_active",
  ]);
  if (
    !allowed.has(state) ||
    (account.entitlement_source === "stripe") !==
      Boolean(account.stripe_customer_id && account.stripe_subscription_id)
  ) {
    throw new Error("Automatic entitlement state is inconsistent.");
  }
}

function requiredText(value: string, name: string, maximum: number): string {
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > maximum)
    throw new Error(`${name} is invalid.`);
  return trimmed;
}
