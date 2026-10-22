/**
 * Encrypts individual web-session secrets with a dedicated AWS KMS key.
 * Encryption context binds every ciphertext to one hashed session/transaction
 * key and one purpose, preventing ciphertext substitution across attributes.
 */

import {
  DecryptCommand,
  EncryptCommand,
  type KMSClient,
} from "@aws-sdk/client-kms";

import type { TokenPurpose, WebSessionTokenCipher } from "./web_session.js";

export class KmsWebSessionTokenCipher implements WebSessionTokenCipher {
  constructor(
    private readonly client: KMSClient,
    private readonly keyId: string,
  ) {
    if (keyId.trim().length === 0) {
      throw new Error("Web session KMS key identifier is required.");
    }
  }

  async encrypt(
    plaintext: string,
    sessionKey: string,
    purpose: TokenPurpose,
  ): Promise<Uint8Array> {
    const bytes = Buffer.from(plaintext, "utf8");
    if (bytes.byteLength === 0 || bytes.byteLength > 4096) {
      throw new Error("Web session secret exceeds the KMS plaintext limit.");
    }
    const response = await this.client.send(
      new EncryptCommand({
        KeyId: this.keyId,
        Plaintext: bytes,
        EncryptionContext: encryptionContext(sessionKey, purpose),
      }),
    );
    if (!response.CiphertextBlob) {
      throw new Error("KMS did not return web session ciphertext.");
    }
    return Uint8Array.from(response.CiphertextBlob);
  }

  async decrypt(
    ciphertext: Uint8Array,
    sessionKey: string,
    purpose: TokenPurpose,
  ): Promise<string> {
    if (ciphertext.byteLength === 0) {
      throw new Error("Web session ciphertext is empty.");
    }
    const response = await this.client.send(
      new DecryptCommand({
        KeyId: this.keyId,
        CiphertextBlob: ciphertext,
        EncryptionContext: encryptionContext(sessionKey, purpose),
      }),
    );
    if (!response.Plaintext) {
      throw new Error("KMS did not return web session plaintext.");
    }
    return Buffer.from(response.Plaintext).toString("utf8");
  }
}

function encryptionContext(
  sessionKey: string,
  purpose: TokenPurpose,
): Record<string, string> {
  return {
    service: "foloo-web-session",
    record: sessionKey,
    purpose,
  };
}
