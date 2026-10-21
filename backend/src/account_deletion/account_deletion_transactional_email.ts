/**
 * Account Deletion transactional email boundary.
 * Recipients are envelope-encrypted and short-lived; SES never depends on the
 * seller OAuth connection used by follow-up email (INF-19, RNF-09).
 */

import {
  DeleteItemCommand,
  GetItemCommand,
  PutItemCommand,
  type DynamoDBClient,
} from "@aws-sdk/client-dynamodb";
import {
  DecryptCommand,
  EncryptCommand,
  type KMSClient,
} from "@aws-sdk/client-kms";
import { InvokeCommand, type LambdaClient } from "@aws-sdk/client-lambda";

import type {
  AccountDeletionNotifier,
  AccountDeletionRecipientVault,
  DeletionLocale,
} from "./account_deletion_workflow.js";

const contextKey = "foloo-account-deletion-request";

export class DynamoKmsDeletionRecipientVault implements AccountDeletionRecipientVault {
  constructor(
    private readonly dynamo: DynamoDBClient,
    private readonly kms: KMSClient,
    private readonly tableName: string,
    private readonly encryptionKeyId: string,
  ) {}

  async capture(input: {
    requestId: string;
    verifiedEmail: string;
    receipt: string;
    expiresAt: Date;
  }): Promise<void> {
    assertRequestId(input.requestId);
    const email = input.verifiedEmail.trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/u.test(email)) {
      throw new Error("Verified notification address is invalid.");
    }
    const encrypted = await this.kms.send(
      new EncryptCommand({
        KeyId: this.encryptionKeyId,
        Plaintext: Buffer.from(
          JSON.stringify({ email, receipt: input.receipt }),
          "utf8",
        ),
        EncryptionContext: { [contextKey]: input.requestId },
      }),
    );
    if (!encrypted.CiphertextBlob)
      throw new Error("KMS returned no ciphertext.");
    await this.dynamo.send(
      new PutItemCommand({
        TableName: this.tableName,
        Item: {
          pk: { S: recipientKey(input.requestId) },
          entity_type: { S: "notification_recipient" },
          ciphertext: {
            B: new Uint8Array(encrypted.CiphertextBlob),
          },
          expires_at: {
            N: String(Math.ceil(input.expiresAt.getTime() / 1000)),
          },
        },
      }),
    );
  }

  async reveal(requestId: string): Promise<string> {
    return (await this.revealSecrets(requestId)).email;
  }

  async recoverReceipt(requestId: string): Promise<string> {
    return (await this.revealSecrets(requestId)).receipt;
  }

  private async revealSecrets(
    requestId: string,
  ): Promise<{ email: string; receipt: string }> {
    const result = await this.dynamo.send(
      new GetItemCommand({
        TableName: this.tableName,
        Key: { pk: { S: recipientKey(requestId) } },
        ConsistentRead: true,
      }),
    );
    const ciphertext = result.Item?.ciphertext?.B;
    const expiresAt = Number(result.Item?.expires_at?.N ?? "0");
    if (!ciphertext || expiresAt <= Math.floor(Date.now() / 1000)) {
      throw new Error(
        "Account deletion notification recipient is unavailable.",
      );
    }
    const decrypted = await this.kms.send(
      new DecryptCommand({
        KeyId: this.encryptionKeyId,
        CiphertextBlob: ciphertext,
        EncryptionContext: { [contextKey]: requestId },
      }),
    );
    if (!decrypted.Plaintext) throw new Error("KMS returned no plaintext.");
    const value = JSON.parse(
      Buffer.from(decrypted.Plaintext).toString("utf8"),
    ) as Partial<{ email: string; receipt: string }>;
    if (
      typeof value.email !== "string" ||
      typeof value.receipt !== "string" ||
      value.receipt.length < 32
    ) {
      throw new Error("Decrypted notification secrets are invalid.");
    }
    return { email: value.email, receipt: value.receipt };
  }

  async purge(requestId: string): Promise<void> {
    await this.dynamo.send(
      new DeleteItemCommand({
        TableName: this.tableName,
        Key: { pk: { S: recipientKey(requestId) } },
      }),
    );
  }
}

export class LambdaAccountDeletionNotifier implements AccountDeletionNotifier {
  constructor(
    private readonly lambda: LambdaClient,
    private readonly functionName: string,
  ) {}

  requestAccepted(input: { requestId: string; locale: DeletionLocale }) {
    return this.invoke("request_accepted", input);
  }

  deletionCompleted(input: { requestId: string; locale: DeletionLocale }) {
    return this.invoke("deletion_completed", input);
  }

  private async invoke(
    action: "request_accepted" | "deletion_completed",
    input: { requestId: string; locale: DeletionLocale },
  ): Promise<void> {
    const result = await this.lambda.send(
      new InvokeCommand({
        FunctionName: this.functionName,
        // Lambda's asynchronous queue supplies two retries and the configured
        // DLQ without blocking deletion progress on a transient SES outage.
        InvocationType: "Event",
        Payload: Buffer.from(JSON.stringify({ action, ...input })),
      }),
    );
    if (result.FunctionError)
      throw new Error("Transactional email provider failed.");
  }
}

function recipientKey(requestId: string): string {
  assertRequestId(requestId);
  return `RECIPIENT#${requestId}`;
}

function assertRequestId(requestId: string): void {
  if (!/^[0-9a-f-]{36}$/iu.test(requestId))
    throw new Error("Invalid request id.");
}
