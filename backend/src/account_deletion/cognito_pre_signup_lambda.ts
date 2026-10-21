/**
 * Prepared Cognito PreSignUp guard for registration blockers.
 * CDK creates it disabled but deliberately does not attach it to the existing
 * User Pool until canonicalization and trigger ownership are approved.
 */

import type { PreSignUpTriggerHandler } from "aws-lambda";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { KMSClient } from "@aws-sdk/client-kms";

import { AccountDeletionGuard } from "./account_deletion_guard.js";
import {
  ConfiguredKmsHmacKeyProvider,
  KmsHmacSha256Generator,
} from "./aws_account_deletion_adapters.js";
import { DynamoAccountDeletionLedger } from "./dynamodb_account_deletion_ledger.js";
import {
  PseudonymousEmailIdentifierService,
  PseudonymousSubjectIdentifierService,
} from "./pseudonymous_identity.js";

export const handler: PreSignUpTriggerHandler = async (event) => {
  if (
    process.env.FOLOO_ACCOUNT_DELETION_REGISTRATION_GUARD_ENABLED !== "true"
  ) {
    return event;
  }
  const email = event.request.userAttributes.email;
  const verified = event.request.userAttributes.email_verified === "true";
  // Federated aliases provide verified evidence. Native email/password signup
  // needs an approved post-verification reservation design before activation.
  if (!email || !verified) {
    throw new Error(
      "Registration protection requires verified email evidence.",
    );
  }
  const tableName = required("ACCOUNT_DELETION_TABLE_NAME");
  const keyArn = required("ACCOUNT_DELETION_HMAC_KEY_ARN");
  const version = required("ACCOUNT_DELETION_HMAC_KEY_VERSION");
  const keys = new ConfiguredKmsHmacKeyProvider({ [version]: keyArn });
  const hmac = new KmsHmacSha256Generator(new KMSClient({}));
  const guard = new AccountDeletionGuard(
    new DynamoAccountDeletionLedger(new DynamoDBClient({}), tableName),
    new PseudonymousEmailIdentifierService(keys, hmac),
    new PseudonymousSubjectIdentifierService(keys, hmac),
    { writeVersion: version, readVersions: [version] },
  );
  const decision = await guard.evaluateRegistration(email);
  if (decision.state !== "active") {
    throw new Error("Registration is temporarily unavailable.");
  }
  return event;
};

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required.`);
  return value;
}
