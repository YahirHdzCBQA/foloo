/**
 * Prepared Cognito PreSignUp guard for registration blockers.
 * CDK creates it disabled but deliberately does not attach it to the existing
 * User Pool until canonicalization and trigger ownership are approved.
 */

import type { PreSignUpTriggerHandler } from "aws-lambda";
import { CognitoAccountAccessProtection } from "./cognito_account_access.js";
import { createCognitoAccountDeletionGuard } from "./cognito_guard_factory.js";

export const handler: PreSignUpTriggerHandler = async (event) => {
  if (
    process.env.FOLOO_ACCOUNT_DELETION_REGISTRATION_GUARD_ENABLED !== "true"
  ) {
    return event;
  }
  // Native signup cannot prove mailbox ownership yet. It proceeds through the
  // existing confirmation flow and is guarded at PostAuthentication instead.
  if (event.triggerSource !== "PreSignUp_ExternalProvider") return event;
  const attributes = event.request.userAttributes;
  // Some external IdP mappings establish email_verified only after Cognito
  // creates the linked user. Do not reject that legitimate first hop; the
  // mandatory PostAuthentication guard still runs before Foloo access.
  if (attributes.email_verified !== "true") return event;
  await new CognitoAccountAccessProtection(
    createCognitoAccountDeletionGuard(),
  ).assertFederatedRegistration({
    email: attributes.email,
    emailVerified: attributes.email_verified === "true",
  });
  return event;
};
