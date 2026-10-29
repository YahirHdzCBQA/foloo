/** AUT-18/AUT-19: explicit self-service admission, independent of runtime and QA.
 * This gate never replaces JWT validation, owner binding, freshness or workflow
 * acknowledgements. Normal admission remains off unless explicitly configured.
 */
import { ApplicationError, unauthorized } from "../application/errors.js";
import { createAccountDeletionQaAccessGuard } from "./account_deletion_qa_access.js";

export interface AccountDeletionAdmissionGuard {
  assertAllowed(authenticatedSubject: string): void;
}

export function createAccountDeletionAdmissionGuard(config: {
  environment: string;
  normalAccessEnabled: boolean;
  qaEnabled: boolean;
  qaAllowedSubjectHashes: ReadonlySet<string>;
}): AccountDeletionAdmissionGuard {
  // Production policy remains blocked by D-13; a flag is not legal approval.
  if (
    (config.normalAccessEnabled || config.qaEnabled) &&
    config.environment !== "dev"
  ) {
    throw new Error(
      "Account deletion admission is restricted to approved DEV preparation.",
    );
  }
  if (config.normalAccessEnabled && config.qaEnabled) {
    throw new Error(
      "Choose normal admission or the QA exception explicitly, not both.",
    );
  }
  if (!config.qaEnabled && config.qaAllowedSubjectHashes.size !== 0) {
    throw new Error(
      "Disabled deletion QA must not retain subject authorizations.",
    );
  }
  const qa = config.qaEnabled
    ? createAccountDeletionQaAccessGuard({
        environment: config.environment,
        enabled: true,
        allowedSubjectHashes: config.qaAllowedSubjectHashes,
      })
    : null;
  return {
    assertAllowed(subject) {
      if (
        typeof subject !== "string" ||
        subject.trim().length === 0 ||
        subject.length > 2048
      )
        throw unauthorized();
      if (qa) return qa.assertAllowed(subject);
      if (config.normalAccessEnabled) return;
      throw new ApplicationError(
        "account_deletion_admission_disabled",
        403,
        "Account deletion admission is not enabled.",
      );
    },
  };
}
