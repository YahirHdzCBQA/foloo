/**
 * Builds a domain-separated selector for a verified entitlement email.
 * Production delegates HMAC generation to KMS; raw email and key material are
 * never persisted or returned by this boundary (MON-21, RNF-09).
 */

import { GenerateMacCommand, type KMSClient } from "@aws-sdk/client-kms";

import {
  canonicalizeVerifiedEmail,
  EMAIL_CANONICALIZATION_POLICY,
} from "../account_deletion/pseudonymous_identity.js";

export const ENTITLEMENT_PREAUTHORIZATION_KEY_VERSION = "v1";

export type EntitlementPreauthorizationSelector = Readonly<{
  keyVersion: string;
  canonicalizationPolicy: typeof EMAIL_CANONICALIZATION_POLICY;
  digest: string;
}>;

export interface VerifiedEmailSelector {
  select(verifiedEmail: string): Promise<EntitlementPreauthorizationSelector>;
}

export class KmsVerifiedEmailSelector implements VerifiedEmailSelector {
  constructor(
    private readonly client: Pick<KMSClient, "send">,
    private readonly keyId: string,
    private readonly keyVersion = ENTITLEMENT_PREAUTHORIZATION_KEY_VERSION,
  ) {
    if (!keyId.trim()) throw new Error("Entitlement HMAC key is required.");
    if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/u.test(keyVersion)) {
      throw new Error("Entitlement HMAC key version is invalid.");
    }
  }

  async select(
    verifiedEmail: string,
  ): Promise<EntitlementPreauthorizationSelector> {
    const canonical = canonicalizeVerifiedEmail(verifiedEmail);
    const message = new TextEncoder().encode(
      [
        "foloo",
        "fl021",
        "entitlement-preauthorization",
        EMAIL_CANONICALIZATION_POLICY,
        this.keyVersion,
        canonical,
      ].join("\u0000"),
    );
    const result = await this.client.send(
      new GenerateMacCommand({
        KeyId: this.keyId,
        MacAlgorithm: "HMAC_SHA_256",
        Message: message,
      }),
    );
    if (!result.Mac || result.Mac.byteLength !== 32) {
      throw new Error("Entitlement HMAC generation failed.");
    }
    return Object.freeze({
      keyVersion: this.keyVersion,
      canonicalizationPolicy: EMAIL_CANONICALIZATION_POLICY,
      digest: Buffer.from(result.Mac).toString("base64url"),
    });
  }
}
