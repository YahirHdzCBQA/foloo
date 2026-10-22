/**
 * Resumable Account Deletion application core for STORE-02.
 * It owns preflight, irreversible acceptance, staged erasure and minimized
 * status while keeping AWS adapters and runtime activation outside the core.
 */

import { randomBytes, randomUUID, createHash } from "node:crypto";

import { ApplicationError } from "../application/errors.js";
import { uploadLifetimeSeconds } from "../storage/media_storage.js";
import type { AccountDeletionBarrierReference } from "./account_deletion_ledger.js";
import type { AccountDeletionGuard } from "./account_deletion_guard.js";

export type DeletionLocale = "es" | "en";
export type DeletionStatus =
  | "awaiting_confirmation"
  | "requested"
  | "in_progress"
  | "blocked"
  | "completed";
export type DeletionDispatchStatus = "not_required" | "pending" | "dispatched";

export type SubscriptionSummary = Readonly<{
  status: "none" | "trial" | "trial_exhausted" | "active" | "expired";
  cancellationRequired: boolean;
  planDisplayName: string | null;
  currentPeriodEnd: Date | null;
}>;

export type AccountDeletionRecord = Readonly<{
  requestId: string;
  ownerKey: string;
  idempotencyKey: string;
  locale: DeletionLocale;
  requestedExport: boolean;
  status: DeletionStatus;
  createdAt: Date;
  expiresAt: Date;
  acceptedAt: Date | null;
  updatedAt: Date;
  completedAt: Date | null;
  receiptHash: string | null;
  receiptExpiresAt: Date | null;
  supportCode: string | null;
  barrier: AccountDeletionBarrierReference | null;
  confirmationIdempotencyKey: string | null;
  dispatchStatus: DeletionDispatchStatus;
  subscription: SubscriptionSummary;
}>;

export type AccountDeletionDispatchOutboxItem = Readonly<{
  requestId: string;
  createdAt: Date;
}>;

export interface AccountDeletionWorkflowStore {
  findCurrent(ownerKey: string): Promise<AccountDeletionRecord | null>;
  findByRequestId(requestId: string): Promise<AccountDeletionRecord | null>;
  findByReceiptHash(receiptHash: string): Promise<AccountDeletionRecord | null>;
  createPreflight(
    record: AccountDeletionRecord,
  ): Promise<AccountDeletionRecord>;
  acceptConfirmation(
    record: AccountDeletionRecord,
  ): Promise<{ record: AccountDeletionRecord; replayed: boolean }>;
  pendingDispatches(
    limit: number,
  ): Promise<AccountDeletionDispatchOutboxItem[]>;
  markDispatchCompleted(requestId: string): Promise<AccountDeletionRecord>;
  update(record: AccountDeletionRecord): Promise<AccountDeletionRecord>;
}

export interface AccountDeletionInventory {
  pendingSyncCount(ownerSubject: string): Promise<number>;
  exportAvailable(ownerSubject: string): Promise<boolean>;
}

export interface SubscriptionCancellationPort {
  summary(ownerSubject: string): Promise<SubscriptionSummary>;
  cancelRenewal(ownerSubject: string): Promise<"not_applicable" | "confirmed">;
}

export interface AccountDeletionNotifier {
  requestAccepted(input: {
    requestId: string;
    locale: DeletionLocale;
  }): Promise<void>;
  deletionCompleted(input: {
    requestId: string;
    locale: DeletionLocale;
  }): Promise<void>;
}

/** Stores only the encrypted notification address needed while deletion runs. */
export interface AccountDeletionRecipientVault {
  capture(input: {
    requestId: string;
    ownerSubject: string;
    verifiedEmail: string;
    receipt: string;
    expiresAt: Date;
  }): Promise<string>;
  recoverReceipt(requestId: string): Promise<string>;
  recoverOwnerSubject(requestId: string): Promise<string>;
}

/** Mirrors the durable barrier into PostgreSQL before destructive work starts. */
export interface AccountDeletionOperationalBarrier {
  markPending(input: {
    requestId: string;
    ownerSubject: string;
    acceptedAt: Date;
  }): Promise<void>;
}

export interface AccountDeletionDispatcher {
  dispatch(input: { requestId: string; ownerSubject: string }): Promise<void>;
}

export interface AccountDeletionExecutor {
  execute(input: {
    requestId: string;
    ownerSubject: string;
    subscription: SubscriptionSummary;
  }): Promise<void>;
  verify(input: { requestId: string; ownerSubject: string }): Promise<boolean>;
}

export interface RecentAuthenticationEvidence {
  authenticatedAt: Date | null;
  now: Date;
  maximumAge: Duration;
}

export type Duration = Readonly<{ milliseconds: number }>;

export function verifyRecentAuthentication(
  evidence: RecentAuthenticationEvidence,
): { recent: boolean; validUntil: Date | null } {
  if (!evidence.authenticatedAt) return { recent: false, validUntil: null };
  const validUntil = new Date(
    evidence.authenticatedAt.getTime() + evidence.maximumAge.milliseconds,
  );
  return {
    recent: evidence.now.getTime() <= validUntil.getTime(),
    validUntil,
  };
}

export class AccountDeletionDependencyUnavailableError extends Error {
  constructor(readonly dependency: "payments" | "deletion_executor") {
    super(`Account deletion dependency is unavailable: ${dependency}.`);
    this.name = "AccountDeletionDependencyUnavailableError";
  }
}

/** Ensures every previously-issued direct S3 PUT has expired before inventory. */
export const accountDeletionWriteQuiescenceMs =
  (uploadLifetimeSeconds + 60) * 1000;

export class AccountDeletionQuiescencePendingError extends Error {
  constructor(readonly retryAfter: Date) {
    super("Account deletion is waiting for outstanding uploads to expire.");
    this.name = "AccountDeletionQuiescencePendingError";
  }
}

export class AccountDeletionConfirmationConflictError extends ApplicationError {
  constructor() {
    super(
      "deletion_confirmation_idempotency_conflict",
      409,
      "Account deletion confirmation uses a different idempotency key.",
    );
    this.name = "AccountDeletionConfirmationConflictError";
  }
}

export class UnavailableSubscriptionCancellation implements SubscriptionCancellationPort {
  constructor(
    private readonly subscriptionStatus: SubscriptionSummary["status"] = "none",
  ) {}

  async summary(): Promise<SubscriptionSummary> {
    return {
      status: this.subscriptionStatus,
      cancellationRequired: this.subscriptionStatus === "active",
      planDisplayName: null,
      currentPeriodEnd: null,
    };
  }

  async cancelRenewal(): Promise<"not_applicable"> {
    if (this.subscriptionStatus === "active") {
      throw new AccountDeletionDependencyUnavailableError("payments");
    }
    return "not_applicable";
  }
}

type WorkflowClock = { now(): Date };

/**
 * Local-testable application service. Production activation additionally
 * requires approved HMAC/KMS, a durable store and destructive worker IAM.
 */
export class AccountDeletionWorkflow<KeyHandle> {
  private static readonly preflightLifetimeMs = 15 * 60 * 1000;
  private static readonly receiptLifetimeMs = 30 * 24 * 60 * 60 * 1000;

  constructor(
    private readonly store: AccountDeletionWorkflowStore,
    private readonly guard: AccountDeletionGuard<KeyHandle>,
    private readonly inventory: AccountDeletionInventory,
    private readonly subscriptions: SubscriptionCancellationPort,
    private readonly executor: AccountDeletionExecutor,
    private readonly notifier: AccountDeletionNotifier,
    private readonly clock: WorkflowClock = { now: () => new Date() },
    private readonly dispatcher?: AccountDeletionDispatcher,
    private readonly recipientVault?: AccountDeletionRecipientVault,
    private readonly operationalBarrier?: AccountDeletionOperationalBarrier,
  ) {}

  async preflight(input: {
    ownerSubject: string;
    ownerKey: string;
    idempotencyKey: string;
    locale: DeletionLocale;
    requestedExport: boolean;
    recentAuthentication: boolean;
  }): Promise<{
    record: AccountDeletionRecord;
    pendingSyncCount: number;
    exportAvailable: boolean;
  }> {
    this.requireRecentAuthentication(input.recentAuthentication);
    const current = await this.store.findCurrent(input.ownerKey);
    if (current && current.status !== "awaiting_confirmation") {
      throw new ApplicationError(
        "deletion_already_pending",
        409,
        "Account deletion is already pending.",
      );
    }
    if (current?.idempotencyKey === input.idempotencyKey) {
      return {
        record: current,
        pendingSyncCount: await this.inventory.pendingSyncCount(
          input.ownerSubject,
        ),
        exportAvailable: await this.inventory.exportAvailable(
          input.ownerSubject,
        ),
      };
    }
    const now = this.clock.now();
    const subscription = await this.subscriptions.summary(input.ownerSubject);
    const record = await this.store.createPreflight({
      requestId: randomUUID(),
      ownerKey: input.ownerKey,
      idempotencyKey: input.idempotencyKey,
      locale: input.locale,
      requestedExport: input.requestedExport,
      status: "awaiting_confirmation",
      createdAt: now,
      expiresAt: new Date(
        now.getTime() + AccountDeletionWorkflow.preflightLifetimeMs,
      ),
      acceptedAt: null,
      updatedAt: now,
      completedAt: null,
      receiptHash: null,
      receiptExpiresAt: null,
      supportCode: null,
      barrier: null,
      confirmationIdempotencyKey: null,
      dispatchStatus: "not_required",
      subscription,
    });
    return {
      record,
      pendingSyncCount: await this.inventory.pendingSyncCount(
        input.ownerSubject,
      ),
      exportAvailable: await this.inventory.exportAvailable(input.ownerSubject),
    };
  }

  async confirm(input: {
    requestId: string;
    ownerSubject: string;
    verifiedEmail: string;
    ownerKey: string;
    recentAuthentication: boolean;
    irreversibleAccepted: boolean;
    discardUnsyncedAccepted: boolean;
    cancelRenewalAccepted: boolean;
    confirmationIdempotencyKey: string;
  }): Promise<{ record: AccountDeletionRecord; receipt: string }> {
    this.requireRecentAuthentication(input.recentAuthentication);
    if (!input.irreversibleAccepted) {
      throw new ApplicationError(
        "irreversible_acknowledgement_required",
        400,
        "Irreversible deletion must be acknowledged.",
      );
    }
    const record = await this.store.findByRequestId(input.requestId);
    if (!record || record.ownerKey !== input.ownerKey) {
      throw new ApplicationError(
        "deletion_preflight_not_found",
        404,
        "Deletion preflight was not found.",
      );
    }
    if (record.status !== "awaiting_confirmation") {
      if (
        record.barrier &&
        this.recipientVault &&
        record.confirmationIdempotencyKey === input.confirmationIdempotencyKey
      ) {
        const receipt = await this.recipientVault.recoverReceipt(
          record.requestId,
        );
        await this.ensureDispatched(record, input.ownerSubject);
        return { record, receipt };
      }
      if (record.confirmationIdempotencyKey) {
        throw new AccountDeletionConfirmationConflictError();
      }
      throw new ApplicationError(
        "deletion_already_pending",
        409,
        "Account deletion is already pending.",
      );
    }
    const now = this.clock.now();
    if (record.expiresAt.getTime() <= now.getTime()) {
      throw new ApplicationError(
        "deletion_preflight_expired",
        410,
        "Deletion preflight expired.",
      );
    }
    const pending = await this.inventory.pendingSyncCount(input.ownerSubject);
    if (pending > 0 && !input.discardUnsyncedAccepted) {
      throw new ApplicationError(
        "unsynced_changes_acknowledgement_required",
        409,
        "Pending local changes must be synchronized or explicitly discarded.",
      );
    }
    if (
      record.subscription.cancellationRequired &&
      !input.cancelRenewalAccepted
    ) {
      throw new ApplicationError(
        "subscription_cancellation_acknowledgement_required",
        409,
        "Subscription cancellation must be acknowledged.",
      );
    }
    await this.subscriptions.cancelRenewal(input.ownerSubject);
    // The encrypted address is captured before the irreversible barrier. A
    // failed attempt can safely be retried and the orphan expires by TTL.
    const generatedReceipt = randomBytes(32).toString("base64url");
    const receipt = this.recipientVault
      ? await this.recipientVault.capture({
          requestId: record.requestId,
          ownerSubject: input.ownerSubject,
          verifiedEmail: input.verifiedEmail,
          receipt: generatedReceipt,
          expiresAt: new Date(now.getTime() + 16 * 24 * 60 * 60 * 1000),
        })
      : generatedReceipt;
    const barrier = await this.guard.acceptDeletionBarrier({
      deletionId: record.requestId,
      canonicalSubject: input.ownerSubject,
      verifiedEmail: input.verifiedEmail,
    });
    await this.operationalBarrier?.markPending({
      requestId: record.requestId,
      ownerSubject: input.ownerSubject,
      acceptedAt: now,
    });
    const acceptedResult = await this.store.acceptConfirmation({
      ...record,
      status: "requested",
      acceptedAt: now,
      updatedAt: now,
      receiptHash: receiptDigest(receipt),
      receiptExpiresAt: new Date(
        now.getTime() + AccountDeletionWorkflow.receiptLifetimeMs,
      ),
      barrier,
      confirmationIdempotencyKey: input.confirmationIdempotencyKey,
      dispatchStatus: "pending",
    });
    if (!acceptedResult.replayed) {
      await this.notifyBestEffort("request_accepted", {
        requestId: acceptedResult.record.requestId,
        locale: acceptedResult.record.locale,
      });
    }
    await this.ensureDispatched(acceptedResult.record, input.ownerSubject);
    return { record: acceptedResult.record, receipt };
  }

  async process(input: {
    requestId: string;
    ownerSubject: string;
  }): Promise<AccountDeletionRecord> {
    const record = await this.store.findByRequestId(input.requestId);
    if (!record || !record.barrier) {
      throw new ApplicationError(
        "deletion_request_not_found",
        404,
        "Deletion request was not found.",
      );
    }
    const barrier = record.barrier;
    if (record.status === "completed") return record;
    if (!record.acceptedAt) {
      throw new ApplicationError(
        "deletion_request_not_accepted",
        409,
        "Deletion request has not been accepted.",
      );
    }
    const safeAfter = new Date(
      record.acceptedAt.getTime() + accountDeletionWriteQuiescenceMs,
    );
    if (this.clock.now().getTime() < safeAfter.getTime()) {
      throw new AccountDeletionQuiescencePendingError(safeAfter);
    }
    const started = await this.store.update({
      ...record,
      status: "in_progress",
      updatedAt: this.clock.now(),
      supportCode: null,
    });
    try {
      await this.executor.execute({
        requestId: started.requestId,
        ownerSubject: input.ownerSubject,
        subscription: started.subscription,
      });
      if (
        !(await this.executor.verify({
          requestId: started.requestId,
          ownerSubject: input.ownerSubject,
        }))
      ) {
        throw new AccountDeletionDependencyUnavailableError(
          "deletion_executor",
        );
      }
      const completedAt = this.clock.now();
      await this.guard.markDeleted(barrier);
      const completed = await this.store.update({
        ...started,
        status: "completed",
        updatedAt: completedAt,
        completedAt,
      });
      await this.notifyBestEffort("deletion_completed", {
        requestId: completed.requestId,
        locale: completed.locale,
      });
      return completed;
    } catch (error) {
      await this.store.update({
        ...started,
        status: "blocked",
        updatedAt: this.clock.now(),
        supportCode:
          error instanceof AccountDeletionDependencyUnavailableError
            ? `dependency_${error.dependency}`
            : "deletion_retry_required",
      });
      throw error;
    }
  }

  async current(ownerKey: string): Promise<AccountDeletionRecord | null> {
    return this.store.findCurrent(ownerKey);
  }

  async byReceipt(receipt: string): Promise<AccountDeletionRecord | null> {
    const record = await this.store.findByReceiptHash(receiptDigest(receipt));
    if (!record?.receiptExpiresAt) return null;
    return record.receiptExpiresAt.getTime() > this.clock.now().getTime()
      ? record
      : null;
  }

  private requireRecentAuthentication(recent: boolean): void {
    if (!recent) {
      throw new ApplicationError(
        "reauthentication_required",
        428,
        "Recent authentication is required.",
      );
    }
  }

  private async ensureDispatched(
    record: AccountDeletionRecord,
    ownerSubject: string,
  ): Promise<void> {
    if (!this.dispatcher || record.dispatchStatus !== "pending") return;
    try {
      await this.dispatcher.dispatch({
        requestId: record.requestId,
        ownerSubject,
      });
      await this.store.markDispatchCompleted(record.requestId);
    } catch (error) {
      // The durable outbox remains pending. Never expose identity or payloads.
      console.warn("Account deletion dispatch remains pending.", {
        requestId: record.requestId,
        errorType: error instanceof Error ? error.name : "UnknownError",
      });
    }
  }

  private async notifyBestEffort(
    action: "request_accepted" | "deletion_completed",
    input: { requestId: string; locale: DeletionLocale },
  ): Promise<void> {
    try {
      if (action === "request_accepted") {
        await this.notifier.requestAccepted(input);
      } else {
        await this.notifier.deletionCompleted(input);
      }
    } catch (error) {
      // Notification is never the authority for irreversible deletion state.
      console.warn("Account deletion notification was not dispatched.", {
        requestId: input.requestId,
        action,
        errorType: error instanceof Error ? error.name : "UnknownError",
      });
    }
  }
}

export function receiptDigest(receipt: string): string {
  if (receipt.length < 32 || receipt.length > 512) {
    throw new ApplicationError(
      "invalid_deletion_receipt",
      400,
      "Deletion receipt is invalid.",
    );
  }
  return createHash("sha256").update(receipt, "utf8").digest("hex");
}
