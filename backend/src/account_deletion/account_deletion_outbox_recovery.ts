/**
 * Replays durable Account Deletion dispatch intents after transient failures.
 * The workflow store owns atomic outbox completion; SQS and worker processing
 * remain idempotent for the narrow send/mark failure window (INF-17, RNF-10).
 */

import type {
  AccountDeletionDispatcher,
  AccountDeletionRecipientVault,
  AccountDeletionWorkflowStore,
} from "./account_deletion_workflow.js";

export type AccountDeletionOutboxRecoveryResult = Readonly<{
  inspected: number;
  dispatched: number;
  failed: number;
}>;

/** Recovers pending dispatches without exposing owner identity in the outbox. */
export class AccountDeletionOutboxRecovery {
  constructor(
    private readonly store: AccountDeletionWorkflowStore,
    private readonly dispatcher: AccountDeletionDispatcher,
    private readonly recipientVault: AccountDeletionRecipientVault,
  ) {}

  async recover(limit = 25): Promise<AccountDeletionOutboxRecoveryResult> {
    const pending = await this.store.pendingDispatches(limit);
    let dispatched = 0;
    let failed = 0;
    for (const item of pending) {
      try {
        const ownerSubject = await this.recipientVault.recoverOwnerSubject(
          item.requestId,
        );
        await this.dispatcher.dispatch({
          requestId: item.requestId,
          ownerSubject,
        });
        await this.store.markDispatchCompleted(item.requestId);
        dispatched += 1;
      } catch (error) {
        failed += 1;
        console.warn("Account deletion outbox recovery failed.", {
          requestId: item.requestId,
          errorType: error instanceof Error ? error.name : "UnknownError",
        });
      }
    }
    return { inspected: pending.length, dispatched, failed };
  }
}
