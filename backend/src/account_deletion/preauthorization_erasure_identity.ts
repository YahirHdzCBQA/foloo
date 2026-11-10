/**
 * Resolves the deletion owner through the private Cognito boundary and derives
 * every configured FL-021 preauthorization selector without exposing email.
 * This boundary must complete before owner data or Cognito identity is erased.
 */

import { InvokeCommand, type LambdaClient } from "@aws-sdk/client-lambda";
import type { KMSClient } from "@aws-sdk/client-kms";

import {
  KmsVerifiedEmailSelector,
  type EntitlementPreauthorizationSelector,
} from "../entitlements/preauthorization_selector.js";

export type EntitlementHmacKey = Readonly<{
  keyArn: string;
  keyVersion: string;
}>;

export interface DeletionPreauthorizationIdentity {
  selectorsForOwner(
    ownerSubject: string,
  ): Promise<readonly EntitlementPreauthorizationSelector[]>;
}

/** Uses only a server-verified Cognito identity and KMS-backed HMAC keys. */
export class LambdaKmsDeletionPreauthorizationIdentity implements DeletionPreauthorizationIdentity {
  private readonly selectors: readonly KmsVerifiedEmailSelector[];

  constructor(
    private readonly lambda: Pick<LambdaClient, "send">,
    private readonly resolverFunctionName: string,
    kms: Pick<KMSClient, "send">,
    keys: readonly EntitlementHmacKey[],
  ) {
    if (!resolverFunctionName.trim() || keys.length === 0 || keys.length > 16) {
      throw new Error("Account deletion identity configuration is invalid.");
    }
    if (new Set(keys.map((key) => key.keyVersion)).size !== keys.length) {
      throw new Error("Account deletion HMAC key versions must be unique.");
    }
    this.selectors = keys.map(
      ({ keyArn, keyVersion }) =>
        new KmsVerifiedEmailSelector(kms, keyArn, keyVersion),
    );
  }

  async selectorsForOwner(
    ownerSubject: string,
  ): Promise<readonly EntitlementPreauthorizationSelector[]> {
    try {
      const response = await this.lambda.send(
        new InvokeCommand({
          FunctionName: this.resolverFunctionName,
          InvocationType: "RequestResponse",
          Payload: Buffer.from(JSON.stringify({ subject: ownerSubject })),
        }),
      );
      if (response.FunctionError || !response.Payload) throw new Error();
      const identity = JSON.parse(
        Buffer.from(response.Payload).toString("utf8"),
      ) as {
        ok?: boolean;
        subject?: unknown;
        email?: unknown;
        emailVerified?: unknown;
      };
      if (
        identity.ok !== true ||
        identity.subject !== ownerSubject ||
        identity.emailVerified !== true ||
        typeof identity.email !== "string"
      ) {
        throw new Error();
      }
      const verifiedEmail = identity.email;
      return await Promise.all(
        this.selectors.map((selector) => selector.select(verifiedEmail)),
      );
    } catch {
      // The worker records the failed stage without persisting identity data.
      throw new Error("Account deletion identity verification failed.");
    }
  }
}

export function entitlementHmacKeysFromEnvironment(
  currentKeyArn: string,
  currentKeyVersion: string,
  previousKeysJson: string | undefined,
): readonly EntitlementHmacKey[] {
  let previous: unknown = [];
  if (previousKeysJson?.trim()) {
    try {
      previous = JSON.parse(previousKeysJson);
    } catch {
      throw new Error(
        "Previous entitlement HMAC key configuration is invalid.",
      );
    }
  }
  if (!Array.isArray(previous)) {
    throw new Error("Previous entitlement HMAC key configuration is invalid.");
  }
  const keys: EntitlementHmacKey[] = [
    { keyArn: currentKeyArn, keyVersion: currentKeyVersion },
  ];
  for (const entry of previous) {
    if (
      typeof entry !== "object" ||
      entry === null ||
      typeof (entry as { keyArn?: unknown }).keyArn !== "string" ||
      typeof (entry as { keyVersion?: unknown }).keyVersion !== "string"
    ) {
      throw new Error(
        "Previous entitlement HMAC key configuration is invalid.",
      );
    }
    keys.push({
      keyArn: (entry as { keyArn: string }).keyArn,
      keyVersion: (entry as { keyVersion: string }).keyVersion,
    });
  }
  return keys;
}
