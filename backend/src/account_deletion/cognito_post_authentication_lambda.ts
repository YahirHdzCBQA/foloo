/**
 * Disabled-by-default Cognito PostAuthentication protection.
 * This is the first common verified-email boundary for native and federated
 * users and runs before Foloo permits backend access or workspace provisioning.
 */

import type { PostAuthenticationTriggerHandler } from "aws-lambda";
import { SQSClient } from "@aws-sdk/client-sqs";

import { CognitoAccountAccessProtection } from "./cognito_account_access.js";
import { createCognitoAccountDeletionGuard } from "./cognito_guard_factory.js";
import { validateCognitoGuardTriggerContext } from "./cognito_trigger_context.js";
import {
  enqueueAfterVerifiedAuthentication,
  enqueueAutomaticEntitlementEvaluation,
} from "../entitlements/automatic_entitlement_enqueue.js";

export const handler: PostAuthenticationTriggerHandler = async (event) => {
  const deletionGuardEnabled =
    process.env.FOLOO_ACCOUNT_DELETION_REGISTRATION_GUARD_ENABLED === "true";
  const entitlementEnqueueEnabled =
    process.env.FOLOO_ENTITLEMENT_AUTOMATIC_ENQUEUE_ENABLED === "true";
  if (!deletionGuardEnabled && !entitlementEnqueueEnabled) return event;
  validateCognitoGuardTriggerContext(event, "post-authentication");
  const attributes = event.request.userAttributes;
  if (deletionGuardEnabled) {
    await new CognitoAccountAccessProtection(
      createCognitoAccountDeletionGuard(),
    ).assertPostAuthentication({
      subject: attributes.sub,
      email: attributes.email,
      emailVerified: attributes.email_verified === "true",
    });
  }
  if (entitlementEnqueueEnabled) {
    await enqueueAfterVerifiedAuthentication(
      attributes,
      async (subject) =>
        await enqueueAutomaticEntitlementEvaluation(
          new SQSClient({}),
          requiredEnvironment("FOLOO_ENTITLEMENT_AUTOMATIC_QUEUE_URL"),
          subject,
        ),
      () => {
        // Login must remain available; the message excludes identity details.
        console.error("automatic_entitlement_enqueue_failed");
      },
    );
  }
  return event;
};

function requiredEnvironment(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}
