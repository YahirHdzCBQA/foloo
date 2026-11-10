/**
 * Enqueues a Cognito owner for asynchronous entitlement evaluation.
 * Login remains available when the private queue is transiently unavailable;
 * a later authentication safely retries the idempotent evaluation (MON-21).
 */

import { randomUUID } from "node:crypto";

import { SendMessageCommand, type SQSClient } from "@aws-sdk/client-sqs";

export type AutomaticEntitlementMessage = Readonly<{
  version: 1;
  requestId: string;
  subject: string;
}>;

/** Keeps authentication available while declining unverified identities. */
export async function enqueueAfterVerifiedAuthentication(
  attributes: Readonly<Record<string, string>>,
  enqueue: (subject: string) => Promise<void>,
  onFailure: () => void = () => {},
): Promise<void> {
  if (attributes.email_verified !== "true" || !attributes.sub) return;
  try {
    await enqueue(attributes.sub);
  } catch {
    onFailure();
  }
}

export async function enqueueAutomaticEntitlementEvaluation(
  client: Pick<SQSClient, "send">,
  queueUrl: string,
  subject: string,
): Promise<void> {
  const normalizedSubject = subject.trim();
  if (!/^[A-Za-z0-9_-]{1,128}$/u.test(normalizedSubject)) {
    throw new Error("Automatic entitlement subject is invalid.");
  }
  if (!queueUrl.trim())
    throw new Error("Automatic entitlement queue is missing.");
  const message: AutomaticEntitlementMessage = {
    version: 1,
    requestId: randomUUID(),
    subject: normalizedSubject,
  };
  await client.send(
    new SendMessageCommand({
      QueueUrl: queueUrl,
      MessageBody: JSON.stringify(message),
    }),
  );
}

export function parseAutomaticEntitlementMessage(
  body: string,
): AutomaticEntitlementMessage {
  const value: unknown = JSON.parse(body);
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Automatic entitlement message is invalid.");
  }
  const message = value as Record<string, unknown>;
  if (
    Object.keys(message).some(
      (key) => !["version", "requestId", "subject"].includes(key),
    ) ||
    message.version !== 1 ||
    typeof message.requestId !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu.test(
      message.requestId,
    ) ||
    typeof message.subject !== "string" ||
    !/^[A-Za-z0-9_-]{1,128}$/u.test(message.subject)
  ) {
    throw new Error("Automatic entitlement message is invalid.");
  }
  return message as AutomaticEntitlementMessage;
}
