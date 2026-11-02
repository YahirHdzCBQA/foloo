/** In-memory workflow persistence used only by synthetic local tests. */

import type {
  AccountDeletionDispatchOutboxItem,
  AccountDeletionRecord,
  AccountDeletionWorkflowStore,
} from "./account_deletion_workflow.js";
import { AccountDeletionConfirmationConflictError } from "./account_deletion_workflow.js";

export class InMemoryAccountDeletionWorkflowStore implements AccountDeletionWorkflowStore {
  private readonly records = new Map<string, AccountDeletionRecord>();
  private readonly outbox = new Map<
    string,
    AccountDeletionDispatchOutboxItem
  >();
  private readonly operationalActions = new Map<string, Date | null>();

  async findCurrent(ownerKey: string): Promise<AccountDeletionRecord | null> {
    return (
      [...this.records.values()]
        .filter((item) => item.ownerKey === ownerKey)
        .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())[0] ??
      null
    );
  }

  async findByRequestId(
    requestId: string,
  ): Promise<AccountDeletionRecord | null> {
    return this.records.get(requestId) ?? null;
  }

  async findByReceiptHash(
    receiptHash: string,
  ): Promise<AccountDeletionRecord | null> {
    return (
      [...this.records.values()].find(
        (item) => item.receiptHash === receiptHash,
      ) ?? null
    );
  }

  async createPreflight(
    record: AccountDeletionRecord,
  ): Promise<AccountDeletionRecord> {
    const current = await this.findCurrent(record.ownerKey);
    if (current?.idempotencyKey === record.idempotencyKey) return current;
    this.records.set(record.requestId, record);
    return record;
  }

  async update(record: AccountDeletionRecord): Promise<AccountDeletionRecord> {
    if (!this.records.has(record.requestId)) {
      throw new Error("Synthetic workflow record does not exist.");
    }
    this.records.set(record.requestId, record);
    return record;
  }

  async acceptConfirmation(
    record: AccountDeletionRecord,
  ): Promise<{ record: AccountDeletionRecord; replayed: boolean }> {
    const current = this.records.get(record.requestId);
    if (!current) throw new Error("Synthetic workflow record does not exist.");
    if (current.status !== "awaiting_confirmation") {
      if (
        current.confirmationIdempotencyKey === record.confirmationIdempotencyKey
      ) {
        return { record: current, replayed: true };
      }
      throw new AccountDeletionConfirmationConflictError();
    }
    this.records.set(record.requestId, record);
    this.outbox.set(record.requestId, {
      requestId: record.requestId,
      createdAt: record.acceptedAt ?? record.updatedAt,
    });
    return { record, replayed: false };
  }

  async pendingDispatches(
    limit: number,
  ): Promise<AccountDeletionDispatchOutboxItem[]> {
    return [...this.outbox.values()]
      .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime())
      .slice(0, limit);
  }

  async activeRequests(limit: number): Promise<AccountDeletionRecord[]> {
    return [...this.records.values()]
      .filter(
        (record) => record.acceptedAt !== null && record.status !== "completed",
      )
      .sort(
        (left, right) =>
          left.acceptedAt!.getTime() - right.acceptedAt!.getTime(),
      )
      .slice(0, limit);
  }

  async claimOperationalAction(input: {
    requestId: string;
    action: string;
    now: Date;
    leaseUntil?: Date;
  }): Promise<boolean> {
    const key = `${input.requestId}:${input.action}`;
    const current = this.operationalActions.get(key);
    if (current !== undefined && (current === null || current > input.now)) {
      return false;
    }
    this.operationalActions.set(key, input.leaseUntil ?? null);
    return true;
  }

  async markDispatchCompleted(
    requestId: string,
  ): Promise<AccountDeletionRecord> {
    const current = this.records.get(requestId);
    if (!current) throw new Error("Synthetic workflow record does not exist.");
    if (current.dispatchStatus === "dispatched") return current;
    const updated = { ...current, dispatchStatus: "dispatched" as const };
    this.records.set(requestId, updated);
    this.outbox.delete(requestId);
    return updated;
  }
}
