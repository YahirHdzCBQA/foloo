/** Builds the Cognito Account Deletion guard from scoped AWS configuration. */

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

export function createCognitoAccountDeletionGuard() {
  const tableName = required("ACCOUNT_DELETION_TABLE_NAME");
  const keyArn = required("ACCOUNT_DELETION_HMAC_KEY_ARN");
  const writeVersion = required("ACCOUNT_DELETION_HMAC_KEY_VERSION");
  const readVersions = parseReadVersions(
    process.env.ACCOUNT_DELETION_HMAC_READ_VERSIONS,
    writeVersion,
  );
  const keys = new ConfiguredKmsHmacKeyProvider(
    Object.fromEntries(readVersions.map((version) => [version, keyArn])),
  );
  const hmac = new KmsHmacSha256Generator(new KMSClient({}));
  return new AccountDeletionGuard(
    new DynamoAccountDeletionLedger(new DynamoDBClient({}), tableName),
    new PseudonymousEmailIdentifierService(keys, hmac),
    new PseudonymousSubjectIdentifierService(keys, hmac),
    { writeVersion, readVersions },
  );
}

function parseReadVersions(value: string | undefined, writeVersion: string) {
  const versions = (value ?? writeVersion)
    .split(",")
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
  return [...new Set([writeVersion, ...versions])];
}

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required.`);
  return value;
}
