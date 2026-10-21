/** In-memory workflow persistence used only by synthetic local tests. */

import type {
  AccountDeletionRecord,
  AccountDeletionWorkflowStore,
} from "./account_deletion_workflow.js";

export class InMemoryAccountDeletionWorkflowStore implements AccountDeletionWorkflowStore {
  private readonly records = new Map<string, AccountDeletionRecord>();

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
}
