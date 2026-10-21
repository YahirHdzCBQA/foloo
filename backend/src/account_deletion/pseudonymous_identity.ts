/** Isolated pseudonymous-identity primitives for future Account Deletion.
 *
 * This module has no persistence, AWS, Cognito, logging or request-flow
 * integration. INF-20/RNF-09 require Security approval before runtime use.
 */

import { createHmac } from "node:crypto";
import { domainToASCII } from "node:url";

declare const canonicalEmailBrand: unique symbol;

/** Email accepted and transformed by the provisional canonicalization policy. */
export type CanonicalEmail = string & {
  readonly [canonicalEmailBrand]: true;
};

export const EMAIL_CANONICALIZATION_POLICY = "foloo-email-v1-provisional";
export const SUBJECT_IDENTITY_POLICY = "foloo-cognito-sub-v1";
export const PSEUDONYMOUS_IDENTIFIER_ALGORITHM = "HMAC-SHA-256";

const localPartPattern = /^[\p{L}\p{M}\p{N}.!#$%&'*+/=?^_`{|}~-]+$/u;
const keyVersionPattern = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/u;

export class InvalidCanonicalEmailError extends Error {
  constructor() {
    super("Email cannot be canonicalized by the active policy.");
    this.name = "InvalidCanonicalEmailError";
  }
}

export class InvalidHmacKeyVersionError extends Error {
  constructor() {
    super("HMAC key version is invalid.");
    this.name = "InvalidHmacKeyVersionError";
  }
}

export class InvalidHmacOutputError extends Error {
  constructor() {
    super("HMAC-SHA-256 generator returned an invalid result.");
    this.name = "InvalidHmacOutputError";
  }
}

/**
 * Applies the provisional identity-comparison policy to a verified email.
 *
 * Verification is a caller-owned precondition: this function validates syntax
 * but cannot prove mailbox ownership. It intentionally preserves dots and
 * plus suffixes and applies no provider-specific alias rules.
 */
export function canonicalizeVerifiedEmail(value: string): CanonicalEmail {
  const normalized = value.trim().normalize("NFC");
  const separator = normalized.indexOf("@");
  if (
    normalized.length === 0 ||
    separator <= 0 ||
    separator !== normalized.lastIndexOf("@") ||
    /[\p{Cc}\p{Cf}\p{Z}]/u.test(normalized)
  ) {
    throw new InvalidCanonicalEmailError();
  }

  const sourceLocal = normalized.slice(0, separator);
  const sourceDomain = normalized.slice(separator + 1);
  const local = sourceLocal.toLowerCase().normalize("NFC");
  const domain = domainToASCII(sourceDomain).toLowerCase();

  if (
    !localPartPattern.test(local) ||
    local.startsWith(".") ||
    local.endsWith(".") ||
    local.includes("..") ||
    Buffer.byteLength(local, "utf8") > 64 ||
    !validAsciiDomain(domain)
  ) {
    throw new InvalidCanonicalEmailError();
  }

  const canonical = `${local}@${domain}`;
  if (Buffer.byteLength(canonical, "utf8") > 254) {
    throw new InvalidCanonicalEmailError();
  }
  return canonical as CanonicalEmail;
}

function validAsciiDomain(domain: string): boolean {
  if (domain.length === 0 || domain.length > 253 || domain.endsWith(".")) {
    return false;
  }
  return domain
    .split(".")
    .every(
      (label) =>
        label.length > 0 &&
        label.length <= 63 &&
        /^[a-z0-9-]+$/u.test(label) &&
        !label.startsWith("-") &&
        !label.endsWith("-"),
    );
}

/** Retrieves a versioned key handle without defining where key material lives. */
export interface HmacSha256KeyProvider<KeyHandle> {
  getKey(keyVersion: string): Promise<KeyHandle>;
}

/** Generates a MAC; a future adapter can delegate this operation to AWS KMS. */
export interface HmacSha256Generator<KeyHandle> {
  generate(key: KeyHandle, message: Uint8Array): Promise<Uint8Array>;
}

/** Local engine for unit tests and offline adapters with injected fake keys. */
export class NodeHmacSha256Generator implements HmacSha256Generator<Uint8Array> {
  async generate(key: Uint8Array, message: Uint8Array): Promise<Uint8Array> {
    return createHmac("sha256", key).update(message).digest();
  }
}

export type PseudonymousEmailIdentifier = Readonly<{
  algorithm: typeof PSEUDONYMOUS_IDENTIFIER_ALGORITHM;
  canonicalizationPolicy: typeof EMAIL_CANONICALIZATION_POLICY;
  keyVersion: string;
  digest: string;
}>;

export type PseudonymousSubjectIdentifier = Readonly<{
  algorithm: typeof PSEUDONYMOUS_IDENTIFIER_ALGORITHM;
  identityPolicy: typeof SUBJECT_IDENTITY_POLICY;
  keyVersion: string;
  digest: string;
}>;

/**
 * Produces a domain-separated, versioned registration identifier.
 *
 * The result is data for a future ledger, not an owner key or authorization
 * decision. The canonical email and key are never retained by this service.
 */
export class PseudonymousEmailIdentifierService<KeyHandle> {
  constructor(
    private readonly keys: HmacSha256KeyProvider<KeyHandle>,
    private readonly hmac: HmacSha256Generator<KeyHandle>,
  ) {}

  async identify(
    verifiedEmail: string,
    keyVersion: string,
  ): Promise<PseudonymousEmailIdentifier> {
    if (!keyVersionPattern.test(keyVersion)) {
      throw new InvalidHmacKeyVersionError();
    }
    const canonical = canonicalizeVerifiedEmail(verifiedEmail);
    const message = new TextEncoder().encode(
      [
        "foloo",
        "account-deletion",
        "registration-email",
        EMAIL_CANONICALIZATION_POLICY,
        keyVersion,
        canonical,
      ].join("\u0000"),
    );
    const key = await this.keys.getKey(keyVersion);
    const mac = await this.hmac.generate(key, message);
    if (mac.byteLength !== 32) throw new InvalidHmacOutputError();

    return Object.freeze({
      algorithm: PSEUDONYMOUS_IDENTIFIER_ALGORITHM,
      canonicalizationPolicy: EMAIL_CANONICALIZATION_POLICY,
      keyVersion,
      digest: Buffer.from(mac).toString("base64url"),
    });
  }
}

/**
 * Produces a durable, domain-separated identifier for Cognito's canonical sub.
 *
 * The subject is intentionally not case-folded or otherwise canonicalized:
 * callers must supply the exact verified claim used for owner isolation.
 */
export class PseudonymousSubjectIdentifierService<KeyHandle> {
  constructor(
    private readonly keys: HmacSha256KeyProvider<KeyHandle>,
    private readonly hmac: HmacSha256Generator<KeyHandle>,
  ) {}

  async identify(
    canonicalSubject: string,
    keyVersion: string,
  ): Promise<PseudonymousSubjectIdentifier> {
    if (!keyVersionPattern.test(keyVersion)) {
      throw new InvalidHmacKeyVersionError();
    }
    if (
      canonicalSubject.length === 0 ||
      canonicalSubject !== canonicalSubject.trim() ||
      Buffer.byteLength(canonicalSubject, "utf8") > 2048 ||
      /[\p{Cc}\p{Cf}\p{Z}]/u.test(canonicalSubject)
    ) {
      throw new InvalidCanonicalSubjectError();
    }
    const message = new TextEncoder().encode(
      [
        "foloo",
        "account-deletion",
        "cognito-subject",
        SUBJECT_IDENTITY_POLICY,
        keyVersion,
        canonicalSubject,
      ].join("\u0000"),
    );
    const key = await this.keys.getKey(keyVersion);
    const mac = await this.hmac.generate(key, message);
    if (mac.byteLength !== 32) throw new InvalidHmacOutputError();

    return Object.freeze({
      algorithm: PSEUDONYMOUS_IDENTIFIER_ALGORITHM,
      identityPolicy: SUBJECT_IDENTITY_POLICY,
      keyVersion,
      digest: Buffer.from(mac).toString("base64url"),
    });
  }
}

export class InvalidCanonicalSubjectError extends Error {
  constructor() {
    super("Canonical subject is invalid.");
    this.name = "InvalidCanonicalSubjectError";
  }
}
