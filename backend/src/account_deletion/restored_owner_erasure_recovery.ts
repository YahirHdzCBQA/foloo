/** Re-runs owner-scoped erasure after a database restore under a fresh run ID. */

import type { AccountDeletionExecutor } from "./account_deletion_workflow.js";

export class RestoredOwnerErasureRecovery {
  constructor(private readonly executor: AccountDeletionExecutor) {}

  async process(input: {
    requestId: string;
    deletionId: string;
    ownerSubject: string;
  }): Promise<void> {
    const subscription = {
      status: "none" as const,
      cancellationRequired: false,
      planDisplayName: null,
      currentPeriodEnd: null,
    };
    await this.executor.execute({
      requestId: input.requestId,
      ownerSubject: input.ownerSubject,
      subscription,
    });
    if (
      !(await this.executor.verify({
        requestId: input.requestId,
        ownerSubject: input.ownerSubject,
      }))
    ) {
      throw new Error("Restored owner erasure could not be verified.");
    }
  }
}
