/**
 * Owns opaque Foloo web sessions independently from Cognito credentials.
 * Cognito remains the identity authority; this boundary only encrypts tokens,
 * enforces session lifetime/idle limits and serializes refresh concurrency.
 */

import { createHash, randomBytes, timingSafeEqual } from "node:crypto";

import { webQaSubjectHash } from "../auth/web_qa_identity.js";

export type WebSessionState = "active" | "revoked" | "expired";
export type TokenPurpose = "refresh" | "access" | "csrf" | "pkce";

export type WebSessionRecord = Readonly<{
  key: string;
  subjectHash: string;
  encryptedRefreshToken: Uint8Array;
  encryptedAccessToken: Uint8Array;
  encryptedCsrfToken: Uint8Array;
  csrfHash: string;
  accessExpiresAtMs: number;
  authenticationTimeMs: number;
  createdAtMs: number;
  lastSeenAtMs: number;
  absoluteExpiresAtMs: number;
  expiresAtEpochSeconds: number;
  version: number;
  state: WebSessionState;
}>;

export type OAuthTransactionRecord = Readonly<{
  key: string;
  stateHash: string;
  encryptedVerifier: Uint8Array;
  createdAtMs: number;
  expiresAtMs: number;
  expiresAtEpochSeconds: number;
  version: number;
}>;

export interface WebSessionStore {
  createSession(record: WebSessionRecord): Promise<void>;
  readSession(key: string): Promise<WebSessionRecord | undefined>;
  replaceSession(
    record: WebSessionRecord,
    expectedVersion: number,
  ): Promise<boolean>;
  createOAuthTransaction(record: OAuthTransactionRecord): Promise<void>;
  readOAuthTransaction(
    key: string,
  ): Promise<OAuthTransactionRecord | undefined>;
  consumeOAuthTransaction(
    key: string,
    expectedVersion: number,
  ): Promise<boolean>;
}

export interface WebSessionTokenCipher {
  encrypt(
    plaintext: string,
    sessionKey: string,
    purpose: TokenPurpose,
  ): Promise<Uint8Array>;
  decrypt(
    ciphertext: Uint8Array,
    sessionKey: string,
    purpose: TokenPurpose,
  ): Promise<string>;
}

export type CognitoTokenSet = Readonly<{
  accessToken: string;
  refreshToken?: string;
  subject: string;
  accessExpiresAtMs: number;
  authenticationTimeMs: number;
}>;

/** Identity attributes read authoritatively from Cognito for UI restoration. */
export type WebSessionIdentity = Readonly<{
  sub: string;
  email: string | null;
  emailVerified: boolean | null;
}>;

export interface CognitoWebSessionProvider {
  refresh(refreshToken: string): Promise<CognitoTokenSet>;
  revoke(refreshToken: string): Promise<void>;
  identity(accessToken: string): Promise<WebSessionIdentity>;
  googleAuthorizationUrl(input: {
    state: string;
    codeChallenge: string;
  }): string;
  exchangeAuthorizationCode(
    code: string,
    codeVerifier: string,
  ): Promise<CognitoTokenSet>;
}

export type WebSessionPolicy = Readonly<{
  absoluteDurationMs: number;
  idleDurationMs: number;
  refreshSkewMs: number;
  oauthTransactionDurationMs: number;
}>;

export type WebSessionAccessPolicy = Readonly<{
  allowedSubjectHashes: ReadonlySet<string>;
}>;

export type SessionCredentials = Readonly<{
  sessionId: string;
  csrfToken: string;
  expiresAt: Date;
  idleExpiresAt: Date;
  authenticationTime: Date;
}>;

export type AuthorizedWebSession = Readonly<{
  accessToken: string;
  identity: WebSessionIdentity;
  csrfToken: string;
  expiresAt: Date;
  idleExpiresAt: Date;
  authenticationTime: Date;
}>;

export type GoogleAuthorization = Readonly<{
  transactionId: string;
  authorizationUrl: string;
}>;

export class WebSessionUnavailableError extends Error {
  constructor() {
    super("Web session is unavailable.");
    this.name = "WebSessionUnavailableError";
  }
}

export class WebSessionUnauthorizedError extends Error {
  constructor() {
    super("Web session is not authenticated.");
    this.name = "WebSessionUnauthorizedError";
  }
}

export class WebSessionCsrfError extends Error {
  constructor() {
    super("Web session CSRF validation failed.");
    this.name = "WebSessionCsrfError";
  }
}

export class WebSessionConcurrencyError extends Error {
  constructor() {
    super("Web session changed concurrently.");
    this.name = "WebSessionConcurrencyError";
  }
}

export class OAuthTransactionError extends Error {
  constructor() {
    super("OAuth transaction is invalid or expired.");
    this.name = "OAuthTransactionError";
  }
}

/**
 * Creates, restores, refreshes and revokes encrypted server-side sessions.
 * The raw opaque identifier is returned once and never persisted by the store.
 */
export class WebSessionService {
  constructor(
    private readonly store: WebSessionStore,
    private readonly cipher: WebSessionTokenCipher,
    private readonly cognito: CognitoWebSessionProvider,
    private readonly policy: WebSessionPolicy,
    private readonly now: () => Date = () => new Date(),
    private readonly accessPolicy?: WebSessionAccessPolicy,
  ) {
    assertPolicy(policy);
  }

  async bootstrapWithRefreshToken(
    submittedRefreshToken: string,
  ): Promise<SessionCredentials> {
    assertOpaqueSecret(submittedRefreshToken, "refresh token");
    const tokens = await this.cognito.refresh(submittedRefreshToken);
    const refreshToken = tokens.refreshToken ?? submittedRefreshToken;
    try {
      return await this.createSession(tokens, refreshToken);
    } catch (error) {
      if (error instanceof WebSessionUnauthorizedError) {
        await this.cognito.revoke(refreshToken);
      }
      throw error;
    }
  }

  async restore(
    sessionId: string,
    options: { csrfToken?: string; forceRefresh?: boolean } = {},
  ): Promise<AuthorizedWebSession> {
    const key = sessionKey(sessionId);
    for (let attempt = 0; attempt < 3; attempt += 1) {
      const record = await this.store.readSession(key);
      if (!record || record.state !== "active") {
        throw new WebSessionUnauthorizedError();
      }
      this.assertSubjectAllowed(record.subjectHash);
      const nowMs = this.now().getTime();
      if (isExpired(record, nowMs, this.policy.idleDurationMs)) {
        await this.expire(record);
        throw new WebSessionUnauthorizedError();
      }
      if (options.csrfToken !== undefined) {
        assertCsrf(options.csrfToken, record.csrfHash);
      }

      const mustRefresh =
        options.forceRefresh === true ||
        record.accessExpiresAtMs <= nowMs + this.policy.refreshSkewMs;
      let accessToken: string;
      let next = record;
      if (mustRefresh) {
        const refreshToken = await this.cipher.decrypt(
          record.encryptedRefreshToken,
          key,
          "refresh",
        );
        let tokens: CognitoTokenSet;
        try {
          tokens = await this.cognito.refresh(refreshToken);
        } catch (error) {
          const winner = await this.store.readSession(key);
          if (winner && winner.version !== record.version) continue;
          throw error;
        }
        const rotatedRefreshToken = tokens.refreshToken ?? refreshToken;
        if (webSessionSubjectHash(tokens.subject) !== record.subjectHash) {
          throw new WebSessionUnauthorizedError();
        }
        accessToken = tokens.accessToken;
        next = {
          ...record,
          encryptedRefreshToken: await this.cipher.encrypt(
            rotatedRefreshToken,
            key,
            "refresh",
          ),
          encryptedAccessToken: await this.cipher.encrypt(
            accessToken,
            key,
            "access",
          ),
          accessExpiresAtMs: tokens.accessExpiresAtMs,
          authenticationTimeMs: tokens.authenticationTimeMs,
        };
      } else {
        accessToken = await this.cipher.decrypt(
          record.encryptedAccessToken,
          key,
          "access",
        );
      }

      const updated: WebSessionRecord = {
        ...next,
        lastSeenAtMs: nowMs,
        version: record.version + 1,
      };
      if (await this.store.replaceSession(updated, record.version)) {
        const identity = await this.cognito.identity(accessToken);
        if (webSessionSubjectHash(identity.sub) !== updated.subjectHash) {
          throw new WebSessionUnauthorizedError();
        }
        return this.authorized(updated, accessToken, identity);
      }
    }
    throw new WebSessionConcurrencyError();
  }

  async logout(sessionId: string, csrfToken: string): Promise<void> {
    const key = sessionKey(sessionId);
    const record = await this.store.readSession(key);
    if (!record || record.state !== "active") return;
    assertCsrf(csrfToken, record.csrfHash);
    const refreshToken = await this.cipher.decrypt(
      record.encryptedRefreshToken,
      key,
      "refresh",
    );
    const revoked: WebSessionRecord = {
      ...record,
      state: "revoked",
      version: record.version + 1,
      lastSeenAtMs: this.now().getTime(),
    };
    if (!(await this.store.replaceSession(revoked, record.version))) {
      throw new WebSessionConcurrencyError();
    }
    await this.cognito.revoke(refreshToken);
  }

  async beginGoogleAuthorization(): Promise<GoogleAuthorization> {
    const transactionId = opaqueToken();
    const key = oauthTransactionKey(transactionId);
    const state = opaqueToken();
    const verifier = opaqueToken();
    const nowMs = this.now().getTime();
    const expiresAtMs = nowMs + this.policy.oauthTransactionDurationMs;
    await this.store.createOAuthTransaction({
      key,
      stateHash: digest(state),
      encryptedVerifier: await this.cipher.encrypt(verifier, key, "pkce"),
      createdAtMs: nowMs,
      expiresAtMs,
      expiresAtEpochSeconds: Math.ceil(expiresAtMs / 1000),
      version: 1,
    });
    return {
      transactionId,
      authorizationUrl: this.cognito.googleAuthorizationUrl({
        state,
        codeChallenge: digest(verifier),
      }),
    };
  }

  async completeGoogleAuthorization(
    transactionId: string,
    state: string,
    code: string,
  ): Promise<SessionCredentials> {
    assertOpaqueSecret(code, "authorization code");
    const key = oauthTransactionKey(transactionId);
    const transaction = await this.store.readOAuthTransaction(key);
    const nowMs = this.now().getTime();
    if (
      !transaction ||
      transaction.expiresAtMs <= nowMs ||
      !safeEqual(transaction.stateHash, digest(state))
    ) {
      throw new OAuthTransactionError();
    }
    const verifier = await this.cipher.decrypt(
      transaction.encryptedVerifier,
      key,
      "pkce",
    );
    const tokens = await this.cognito.exchangeAuthorizationCode(code, verifier);
    if (!tokens.refreshToken) throw new OAuthTransactionError();
    if (!(await this.store.consumeOAuthTransaction(key, transaction.version))) {
      await this.cognito.revoke(tokens.refreshToken);
      throw new OAuthTransactionError();
    }
    try {
      return await this.createSession(tokens, tokens.refreshToken);
    } catch (error) {
      if (error instanceof WebSessionUnauthorizedError) {
        await this.cognito.revoke(tokens.refreshToken);
      }
      throw error;
    }
  }

  /**
   * Consumes a provider-cancelled OAuth transaction only after validating its
   * state. No provider error details cross this boundary or create a session.
   */
  async cancelGoogleAuthorization(
    transactionId: string,
    state: string,
  ): Promise<void> {
    const key = oauthTransactionKey(transactionId);
    const transaction = await this.store.readOAuthTransaction(key);
    const nowMs = this.now().getTime();
    if (
      !transaction ||
      transaction.expiresAtMs <= nowMs ||
      !safeEqual(transaction.stateHash, digest(state)) ||
      !(await this.store.consumeOAuthTransaction(key, transaction.version))
    ) {
      throw new OAuthTransactionError();
    }
  }

  private async createSession(
    tokens: CognitoTokenSet,
    refreshToken: string,
  ): Promise<SessionCredentials> {
    validateTokenSet(tokens);
    this.assertSubjectAllowed(webSessionSubjectHash(tokens.subject));
    const sessionId = opaqueToken();
    const key = sessionKey(sessionId);
    const csrfToken = opaqueToken();
    const nowMs = this.now().getTime();
    const absoluteExpiresAtMs = nowMs + this.policy.absoluteDurationMs;
    const record: WebSessionRecord = {
      key,
      subjectHash: webSessionSubjectHash(tokens.subject),
      encryptedRefreshToken: await this.cipher.encrypt(
        refreshToken,
        key,
        "refresh",
      ),
      encryptedAccessToken: await this.cipher.encrypt(
        tokens.accessToken,
        key,
        "access",
      ),
      encryptedCsrfToken: await this.cipher.encrypt(csrfToken, key, "csrf"),
      csrfHash: digest(csrfToken),
      accessExpiresAtMs: tokens.accessExpiresAtMs,
      authenticationTimeMs: tokens.authenticationTimeMs,
      createdAtMs: nowMs,
      lastSeenAtMs: nowMs,
      absoluteExpiresAtMs,
      expiresAtEpochSeconds: Math.ceil(absoluteExpiresAtMs / 1000),
      version: 1,
      state: "active",
    };
    await this.store.createSession(record);
    return {
      sessionId,
      csrfToken,
      expiresAt: new Date(absoluteExpiresAtMs),
      idleExpiresAt: new Date(nowMs + this.policy.idleDurationMs),
      authenticationTime: new Date(tokens.authenticationTimeMs),
    };
  }

  private assertSubjectAllowed(value: string): void {
    if (
      this.accessPolicy &&
      !this.accessPolicy.allowedSubjectHashes.has(value)
    ) {
      throw new WebSessionUnauthorizedError();
    }
  }

  private async authorized(
    record: WebSessionRecord,
    accessToken: string,
    identity: WebSessionIdentity,
  ): Promise<AuthorizedWebSession> {
    return {
      accessToken,
      identity,
      csrfToken: await this.cipher.decrypt(
        record.encryptedCsrfToken,
        record.key,
        "csrf",
      ),
      expiresAt: new Date(record.absoluteExpiresAtMs),
      idleExpiresAt: new Date(record.lastSeenAtMs + this.policy.idleDurationMs),
      authenticationTime: new Date(record.authenticationTimeMs),
    };
  }

  private async expire(record: WebSessionRecord): Promise<void> {
    await this.store.replaceSession(
      { ...record, state: "expired", version: record.version + 1 },
      record.version,
    );
  }
}

export function sessionKey(sessionId: string): string {
  assertOpaqueSecret(sessionId, "session identifier");
  return `SESSION#${digest(sessionId)}`;
}

export function oauthTransactionKey(transactionId: string): string {
  assertOpaqueSecret(transactionId, "OAuth transaction identifier");
  return `OAUTH#${digest(transactionId)}`;
}

export function digest(value: string): string {
  return createHash("sha256").update(value, "utf8").digest("base64url");
}

export function webSessionSubjectHash(subject: string): string {
  try {
    return webQaSubjectHash(subject);
  } catch {
    throw new WebSessionUnauthorizedError();
  }
}

function opaqueToken(): string {
  return randomBytes(32).toString("base64url");
}

function assertOpaqueSecret(value: string, label: string): void {
  if (
    value.length < 16 ||
    value.length > 8192 ||
    /[\p{Cc}\p{Z}]/u.test(value)
  ) {
    throw new Error(`${label} is invalid.`);
  }
}

function assertPolicy(policy: WebSessionPolicy): void {
  for (const value of Object.values(policy)) {
    if (!Number.isSafeInteger(value) || value <= 0) {
      throw new Error("Web session policy is invalid.");
    }
  }
  if (policy.idleDurationMs > policy.absoluteDurationMs) {
    throw new Error("Idle duration cannot exceed absolute duration.");
  }
}

function validateTokenSet(tokens: CognitoTokenSet): void {
  if (
    tokens.accessToken.length < 16 ||
    tokens.subject.length === 0 ||
    !Number.isSafeInteger(tokens.accessExpiresAtMs) ||
    !Number.isSafeInteger(tokens.authenticationTimeMs) ||
    tokens.accessExpiresAtMs <= tokens.authenticationTimeMs
  ) {
    throw new WebSessionUnauthorizedError();
  }
}

function isExpired(
  record: WebSessionRecord,
  nowMs: number,
  idleDurationMs: number,
): boolean {
  return (
    record.absoluteExpiresAtMs <= nowMs ||
    record.lastSeenAtMs + idleDurationMs <= nowMs
  );
}

function assertCsrf(value: string, expectedHash: string): void {
  if (!safeEqual(digest(value), expectedHash)) {
    throw new WebSessionCsrfError();
  }
}

function safeEqual(left: string, right: string): boolean {
  const leftBytes = Buffer.from(left);
  const rightBytes = Buffer.from(right);
  return (
    leftBytes.length === rightBytes.length &&
    timingSafeEqual(leftBytes, rightBytes)
  );
}
