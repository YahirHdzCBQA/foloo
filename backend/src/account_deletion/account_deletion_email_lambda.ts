/** SES-only Account Deletion notification Lambda; independent from sender OAuth. */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { KMSClient } from "@aws-sdk/client-kms";
import { SESv2Client, SendEmailCommand } from "@aws-sdk/client-sesv2";

import {
  accountDeletionCompletedEmail,
  accountDeletionRequestEmail,
} from "./account_deletion_email.js";
import { DynamoKmsDeletionRecipientVault } from "./account_deletion_transactional_email.js";
import type { DeletionLocale } from "./account_deletion_workflow.js";

type Command = {
  action: "request_accepted" | "deletion_completed";
  requestId: string;
  locale: DeletionLocale;
};

const dynamo = new DynamoDBClient({});
const kms = new KMSClient({});
const ses = new SESv2Client({});

export async function handler(command: Command): Promise<{ sent: true }> {
  if (process.env.FOLOO_ACCOUNT_DELETION_ENABLED !== "true") {
    throw new Error("Account deletion email is disabled.");
  }
  if (process.env.ACCOUNT_DELETION_SES_IDENTITY_VERIFIED !== "true") {
    throw new Error("SES identity verification has not been approved.");
  }
  const tableName = required("ACCOUNT_DELETION_TABLE_NAME");
  const keyId = required("ACCOUNT_DELETION_RECIPIENT_KEY_ARN");
  const fromAddress = required("ACCOUNT_DELETION_FROM_ADDRESS");
  const supportAddress = required("ACCOUNT_DELETION_SUPPORT_ADDRESS");
  const vault = new DynamoKmsDeletionRecipientVault(
    dynamo,
    kms,
    tableName,
    keyId,
  );
  const recipient = await vault.reveal(command.requestId);
  const content =
    command.action === "request_accepted"
      ? accountDeletionRequestEmail(command.locale, supportAddress)
      : accountDeletionCompletedEmail(command.locale, supportAddress);
  await ses.send(
    new SendEmailCommand({
      FromEmailAddress: fromAddress,
      Destination: { ToAddresses: [recipient] },
      ReplyToAddresses: [supportAddress],
      Content: {
        Simple: {
          Subject: { Data: content.subject, Charset: "UTF-8" },
          Body: {
            Text: { Data: content.plainBody, Charset: "UTF-8" },
            Html: { Data: content.htmlBody, Charset: "UTF-8" },
          },
        },
      },
    }),
  );
  if (command.action === "deletion_completed")
    await vault.purge(command.requestId);
  return { sent: true };
}

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required.`);
  return value;
}
