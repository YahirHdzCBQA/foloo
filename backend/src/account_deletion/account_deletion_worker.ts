/** SQS worker boundary with partial-batch retry semantics and no PII logging. */

import type { SQSBatchResponse, SQSEvent } from "aws-lambda";

import type { AccountDeletionWorkflow } from "./account_deletion_workflow.js";
import type { RestoredOwnerErasureRecovery } from "./restored_owner_erasure_recovery.js";
import { parseAccountDeletionQueueMessage } from "./aws_account_deletion_adapters.js";

export function createAccountDeletionWorker<KeyHandle>(
  workflow: Pick<AccountDeletionWorkflow<KeyHandle>, "process">,
  restoreRecovery?: Pick<RestoredOwnerErasureRecovery, "process">,
) {
  return async (event: SQSEvent): Promise<SQSBatchResponse> => {
    const batchItemFailures: { itemIdentifier: string }[] = [];
    for (const record of event.Records) {
      try {
        const message = parseAccountDeletionQueueMessage(record.body);
        if (message.mode === "restore_recovery") {
          if (!restoreRecovery) {
            throw new Error("Restore erasure recovery is not configured.");
          }
          await restoreRecovery.process(message);
        } else {
          await workflow.process(message);
        }
        console.info(
          JSON.stringify({
            scope: "account_deletion_worker",
            requestId: message.requestId,
            outcome: "processed",
          }),
        );
      } catch (error) {
        console.error(
          JSON.stringify({
            scope: "account_deletion_worker",
            messageId: record.messageId,
            outcome: "retry_required",
            errorType: error instanceof Error ? error.name : "UnknownError",
          }),
        );
        batchItemFailures.push({ itemIdentifier: record.messageId });
      }
    }
    return { batchItemFailures };
  };
}
