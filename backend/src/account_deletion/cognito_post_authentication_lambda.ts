/**
 * Disabled-by-default Cognito PostAuthentication protection.
 * This is the first common verified-email boundary for native and federated
 * users and runs before Foloo permits backend access or workspace provisioning.
 */

import type { PostAuthenticationTriggerHandler } from "aws-lambda";

import { CognitoAccountAccessProtection } from "./cognito_account_access.js";
import { createCognitoAccountDeletionGuard } from "./cognito_guard_factory.js";

export const handler: PostAuthenticationTriggerHandler = async (event) => {
  if (
    process.env.FOLOO_ACCOUNT_DELETION_REGISTRATION_GUARD_ENABLED !== "true"
  ) {
    return event;
  }
  const attributes = event.request.userAttributes;
  await new CognitoAccountAccessProtection(
    createCognitoAccountDeletionGuard(),
  ).assertPostAuthentication({
    subject: attributes.sub,
    email: attributes.email,
    emailVerified: attributes.email_verified === "true",
  });
  return event;
};
