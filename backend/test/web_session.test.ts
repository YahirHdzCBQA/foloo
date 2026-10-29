/** Unit coverage for opaque, encrypted and concurrency-safe web sessions. */

import assert from "node:assert/strict";
import test from "node:test";

import type {
  CognitoTokenSet,
  CognitoWebSessionProvider,
  OAuthTransactionRecord,
  TokenPurpose,
  WebSessionIdentity,
  WebSessionRecord,
  WebSessionStore,
  WebSessionTokenCipher,
} from "../src/web_auth/web_session.js";
import {
  WebSessionCsrfError,
  WebReauthenticationError,
  WebSessionService,
  WebSessionUnauthorizedError,
  sessionKey,
  webSessionSubjectHash,
} from "../src/web_auth/web_session.js";

class MemoryStore implements WebSessionStore {
  readonly sessions = new Map<string, WebSessionRecord>();
  readonly oauth = new Map<string, OAuthTransactionRecord>();

  async createSession(record: WebSessionRecord): Promise<void> {
    if (this.sessions.has(record.key)) throw new Error("collision");
    this.sessions.set(record.key, record);
  }

  async readSession(key: string): Promise<WebSessionRecord | undefined> {
    return this.sessions.get(key);
  }

  async replaceSession(
    record: WebSessionRecord,
    expectedVersion: number,
  ): Promise<boolean> {
    if (this.sessions.get(record.key)?.version !== expectedVersion)
      return false;
    this.sessions.set(record.key, record);
    return true;
  }

  async createOAuthTransaction(record: OAuthTransactionRecord): Promise<void> {
    this.oauth.set(record.key, record);
  }

  async readOAuthTransaction(
    key: string,
  ): Promise<OAuthTransactionRecord | undefined> {
    return this.oauth.get(key);
  }

  async consumeOAuthTransaction(
    key: string,
    expectedVersion: number,
  ): Promise<boolean> {
    if (this.oauth.get(key)?.version !== expectedVersion) return false;
    this.oauth.delete(key);
    return true;
  }
}

class TestCipher implements WebSessionTokenCipher {
  async encrypt(
    plaintext: string,
    sessionKeyValue: string,
    purpose: TokenPurpose,
  ): Promise<Uint8Array> {
    return Buffer.from(`${purpose}\u0000${sessionKeyValue}\u0000${plaintext}`);
  }

  async decrypt(
    ciphertext: Uint8Array,
    sessionKeyValue: string,
    purpose: TokenPurpose,
  ): Promise<string> {
    const prefix = `${purpose}\u0000${sessionKeyValue}\u0000`;
    const decoded = Buffer.from(ciphertext).toString("utf8");
    assert.ok(decoded.startsWith(prefix));
    return decoded.slice(prefix.length);
  }
}

class TestCognito implements CognitoWebSessionProvider {
  refreshCount = 0;
  readonly revoked: string[] = [];

  async refresh(refreshToken: string): Promise<CognitoTokenSet> {
    this.refreshCount += 1;
    return tokens(`access-${this.refreshCount}-${refreshToken}`, refreshToken);
  }

  async revoke(refreshToken: string): Promise<void> {
    this.revoked.push(refreshToken);
  }

  async identity(): Promise<WebSessionIdentity> {
    return {
      sub: "synthetic-subject-a",
      email: "qa@example.invalid",
      emailVerified: true,
    };
  }

  googleAuthorizationUrl(input: {
    state: string;
    codeChallenge: string;
  }): string {
    return `https://example.test/authorize?state=${input.state}&challenge=${input.codeChallenge}`;
  }

  async exchangeAuthorizationCode(): Promise<CognitoTokenSet> {
    return {
      ...tokens("google-access-token", "google-refresh-token"),
      refreshToken: "google-refresh-token",
    };
  }
}

const clock = { now: Date.parse("2026-10-22T12:00:00Z") };
const now = () => new Date(clock.now);
const policy = {
  absoluteDurationMs: 12 * 60 * 60 * 1000,
  idleDurationMs: 30 * 60 * 1000,
  refreshSkewMs: 60 * 1000,
  oauthTransactionDurationMs: 10 * 60 * 1000,
};

function tokens(accessToken: string, refreshToken?: string): CognitoTokenSet {
  return {
    accessToken: accessToken.padEnd(24, "x"),
    refreshToken,
    subject: "synthetic-subject-a",
    accessExpiresAtMs: clock.now + 60 * 60 * 1000,
    authenticationTimeMs: clock.now - 1000,
  };
}

test("AUT-18 SRP bootstrap stores no raw opaque id and restores a session", async () => {
  const store = new MemoryStore();
  const cognito = new TestCognito();
  const service = new WebSessionService(
    store,
    new TestCipher(),
    cognito,
    policy,
    now,
  );

  const created = await service.bootstrapWithRefreshToken(
    "refresh-token-synthetic",
  );
  assert.equal(store.sessions.has(created.sessionId), false);
  assert.ok(store.sessions.has(sessionKey(created.sessionId)));
  assert.equal(
    JSON.stringify([...store.sessions.values()]).includes(created.sessionId),
    false,
  );
  const restored = await service.restore(created.sessionId);
  assert.equal(restored.csrfToken, created.csrfToken);
  assert.deepEqual(restored.identity, {
    sub: "synthetic-subject-a",
    email: "qa@example.invalid",
    emailVerified: true,
  });
  assert.equal(cognito.refreshCount, 1);
});

test("AUT-18 QA allowlist rejects SRP and Google without persisting sessions", async () => {
  const store = new MemoryStore();
  const cognito = new TestCognito();
  const service = new WebSessionService(
    store,
    new TestCipher(),
    cognito,
    policy,
    now,
    { allowedSubjectHashes: new Set([webSessionSubjectHash("other-subject")]) },
  );
  await assert.rejects(
    service.bootstrapWithRefreshToken("refresh-token-synthetic"),
    WebSessionUnauthorizedError,
  );
  const started = await service.beginGoogleAuthorization();
  const state = new URL(started.authorizationUrl).searchParams.get("state");
  assert.ok(state);
  await assert.rejects(
    service.completeGoogleAuthorization(
      started.transactionId,
      state,
      "authorization-code-synthetic",
    ),
    WebSessionUnauthorizedError,
  );
  assert.equal(store.sessions.size, 0);
  assert.deepEqual(cognito.revoked, [
    "refresh-token-synthetic",
    "google-refresh-token",
  ]);
});

test("AUT-18 removing a QA subject immediately blocks an existing session", async () => {
  const store = new MemoryStore();
  const cognito = new TestCognito();
  const allowed = new Set([webSessionSubjectHash("synthetic-subject-a")]);
  const service = new WebSessionService(
    store,
    new TestCipher(),
    cognito,
    policy,
    now,
    { allowedSubjectHashes: allowed },
  );
  const created = await service.bootstrapWithRefreshToken(
    "refresh-token-synthetic",
  );
  allowed.clear();
  await assert.rejects(
    service.restore(created.sessionId),
    WebSessionUnauthorizedError,
  );
});

test("AUT-18 CSRF, refresh rotation, logout and revocation are enforced", async () => {
  const store = new MemoryStore();
  const cognito = new TestCognito();
  const service = new WebSessionService(
    store,
    new TestCipher(),
    cognito,
    policy,
    now,
  );
  const created = await service.bootstrapWithRefreshToken(
    "refresh-token-synthetic",
  );

  await assert.rejects(
    service.restore(created.sessionId, { csrfToken: "invalid-csrf-token" }),
    WebSessionCsrfError,
  );
  await service.restore(created.sessionId, {
    csrfToken: created.csrfToken,
    forceRefresh: true,
  });
  assert.equal(cognito.refreshCount, 2);
  await service.logout(created.sessionId, created.csrfToken);
  assert.deepEqual(cognito.revoked, ["refresh-token-synthetic"]);
  await assert.rejects(
    service.restore(created.sessionId),
    WebSessionUnauthorizedError,
  );
});

test("AUT-10 restored Cognito identity cannot switch the session subject", async () => {
  const store = new MemoryStore();
  const cognito = new TestCognito();
  const service = new WebSessionService(
    store,
    new TestCipher(),
    cognito,
    policy,
    now,
  );
  const created = await service.bootstrapWithRefreshToken(
    "refresh-token-synthetic",
  );
  cognito.identity = async () => ({
    sub: "different-synthetic-subject",
    email: "other@example.invalid",
    emailVerified: true,
  });
  await assert.rejects(
    service.restore(created.sessionId),
    WebSessionUnauthorizedError,
  );
});

test("AUT-18 idle expiry and session isolation are owner-independent", async () => {
  const store = new MemoryStore();
  const cognito = new TestCognito();
  const service = new WebSessionService(
    store,
    new TestCipher(),
    cognito,
    policy,
    now,
  );
  const first = await service.bootstrapWithRefreshToken("refresh-token-first");
  const second = await service.bootstrapWithRefreshToken(
    "refresh-token-second",
  );
  assert.notEqual(first.sessionId, second.sessionId);

  clock.now += policy.idleDurationMs;
  await assert.rejects(
    service.restore(first.sessionId),
    WebSessionUnauthorizedError,
  );
  assert.equal(
    store.sessions.get(sessionKey(first.sessionId))?.state,
    "expired",
  );
  assert.equal(
    store.sessions.get(sessionKey(second.sessionId))?.state,
    "active",
  );
  clock.now = Date.parse("2026-10-22T12:00:00Z");
});

test("AUT-18 Google PKCE transaction is single-use", async () => {
  const store = new MemoryStore();
  const cognito = new TestCognito();
  const service = new WebSessionService(
    store,
    new TestCipher(),
    cognito,
    policy,
    now,
  );
  const started = await service.beginGoogleAuthorization();
  const state = new URL(started.authorizationUrl).searchParams.get("state");
  assert.ok(state);
  await assert.rejects(
    service.completeGoogleAuthorization(
      started.transactionId,
      "invalid-oauth-state",
      "authorization-code-synthetic",
    ),
  );
  const completed = await service.completeGoogleAuthorization(
    started.transactionId,
    state,
    "authorization-code-synthetic",
  );
  assert.ok(completed.sessionId);
  await assert.rejects(
    service.completeGoogleAuthorization(
      started.transactionId,
      state,
      "authorization-code-synthetic",
    ),
  );
});

test("AUT-04 Google cancellation validates state and consumes the transaction", async () => {
  const store = new MemoryStore();
  const cognito = new TestCognito();
  const service = new WebSessionService(
    store,
    new TestCipher(),
    cognito,
    policy,
    now,
  );
  const started = await service.beginGoogleAuthorization();
  const state = new URL(started.authorizationUrl).searchParams.get("state");
  assert.ok(state);

  await assert.rejects(
    service.cancelGoogleAuthorization(
      started.transactionId,
      "invalid-oauth-state",
    ),
  );
  await service.cancelGoogleAuthorization(started.transactionId, state);
  await assert.rejects(
    service.cancelGoogleAuthorization(started.transactionId, state),
  );
  assert.equal(store.sessions.size, 0);
  assert.equal(cognito.refreshCount, 0);
  assert.deepEqual(cognito.revoked, []);
});

test("AUT-18 concurrent refreshes converge through conditional versions", async () => {
  const store = new MemoryStore();
  const cognito = new TestCognito();
  const service = new WebSessionService(
    store,
    new TestCipher(),
    cognito,
    policy,
    now,
  );
  const created = await service.bootstrapWithRefreshToken(
    "refresh-token-concurrent",
  );
  const [first, second] = await Promise.all([
    service.restore(created.sessionId, {
      csrfToken: created.csrfToken,
      forceRefresh: true,
    }),
    service.restore(created.sessionId, {
      csrfToken: created.csrfToken,
      forceRefresh: true,
    }),
  ]);
  assert.ok(first.accessToken);
  assert.ok(second.accessToken);
  assert.equal(store.sessions.get(sessionKey(created.sessionId))?.version, 3);
});

// WEB-02 / AUT-18: new interactive evidence is bound to a single-use intent.
class ReauthCognito extends TestCognito {
  result: CognitoTokenSet | null = null;
  fail = false;
  override async identity(): Promise<WebSessionIdentity> {
    return {
      ...(await super.identity()),
      sub: this.result?.subject ?? "synthetic-subject-a",
    };
  }
  async verifyNativeResult(): Promise<CognitoTokenSet> {
    if (this.fail) throw new Error("provider unavailable");
    return this.result!;
  }
  override async exchangeAuthorizationCode(): Promise<CognitoTokenSet> {
    return this.result!;
  }
}
function reauthFixture() {
  clock.now = Date.parse("2026-10-22T12:00:00Z");
  const store = new MemoryStore(),
    cognito = new ReauthCognito();
  const service = new WebSessionService(
    store,
    new TestCipher(),
    cognito,
    policy,
    now,
  );
  return { store, cognito, service };
}
test("AUT-18 native reauth preserves session identity, CSRF and absolute expiry; intent cannot replay", async () => {
  const f = reauthFixture();
  const original = await f.service.bootstrapWithRefreshToken(
    "original-refresh-token",
  );
  const prior = f.store.sessions.get(sessionKey(original.sessionId))!;
  const intent = await f.service.beginReauthentication(
    original.sessionId,
    original.csrfToken,
    "srp",
  );
  clock.now += 2000;
  f.cognito.result = {
    ...tokens("new-interactive-access-token", "new-interactive-refresh-token"),
    authenticationTimeMs: clock.now,
  };
  const result = await f.service.completeNativeReauthentication(
    original.sessionId,
    original.csrfToken,
    intent.transactionId,
    "new-interactive-access-token",
  );
  assert.equal(result.identity.sub, "synthetic-subject-a");
  assert.equal(result.csrfToken, original.csrfToken);
  assert.equal(result.expiresAt.getTime(), prior.absoluteExpiresAtMs);
  assert.equal(f.store.sessions.size, 1);
  assert.deepEqual(
    f.store.sessions.get(sessionKey(original.sessionId))!.encryptedRefreshToken,
    prior.encryptedRefreshToken,
  );
  await assert.rejects(
    f.service.completeNativeReauthentication(
      original.sessionId,
      original.csrfToken,
      intent.transactionId,
      "new-interactive-access-token",
    ),
  );
});
for (const mode of [
  "other-account",
  "old-auth-time",
  "expired-token",
  "future-auth-time",
  "provider-failure",
] as const) {
  test(`AUT-18 ${mode} rejects without changing original session`, async () => {
    const f = reauthFixture();
    const original = await f.service.bootstrapWithRefreshToken(
      "original-refresh-token",
    );
    const intent = await f.service.beginReauthentication(
      original.sessionId,
      original.csrfToken,
      "srp",
    );
    const before = JSON.stringify(
      f.store.sessions.get(sessionKey(original.sessionId)),
    );
    clock.now += 2000;
    f.cognito.result = {
      ...tokens("interactive-access-token", "interactive-refresh-token"),
      authenticationTimeMs: clock.now,
    };
    if (mode === "other-account")
      f.cognito.result = { ...f.cognito.result, subject: "other-account" };
    if (mode === "old-auth-time")
      f.cognito.result = {
        ...f.cognito.result,
        authenticationTimeMs: clock.now - 10000,
      };
    if (mode === "expired-token")
      f.cognito.result = {
        ...f.cognito.result,
        accessExpiresAtMs: clock.now - 1,
      };
    if (mode === "future-auth-time")
      f.cognito.result = {
        ...f.cognito.result,
        authenticationTimeMs: clock.now + 1000,
      };
    if (mode === "provider-failure") f.cognito.fail = true;
    await assert.rejects(
      f.service.completeNativeReauthentication(
        original.sessionId,
        original.csrfToken,
        intent.transactionId,
        "interactive-access-token",
      ),
    );
    assert.deepEqual(
      JSON.stringify(f.store.sessions.get(sessionKey(original.sessionId))),
      before,
    );
    assert.equal(f.store.sessions.size, 1);
  });
}
test("AUT-18 native reauth requires original session and CSRF", async () => {
  const f = reauthFixture();
  const original = await f.service.bootstrapWithRefreshToken(
    "original-refresh-token",
  );
  await assert.rejects(
    f.service.beginReauthentication(
      original.sessionId,
      "invalid-csrf-token",
      "srp",
    ),
    WebSessionCsrfError,
  );
  await assert.rejects(
    f.service.beginReauthentication(
      "unknown-session-identifier",
      original.csrfToken,
      "srp",
    ),
    WebSessionUnauthorizedError,
  );
  clock.now += policy.idleDurationMs + 1;
  await assert.rejects(
    f.service.beginReauthentication(
      original.sessionId,
      original.csrfToken,
      "srp",
    ),
    WebSessionUnauthorizedError,
  );
  assert.equal(f.store.oauth.size, 0);
});
for (const mismatch of [false, true])
  test(`AUT-18 Google reauth is bound to original identity (mismatch=${mismatch})`, async () => {
    const f = reauthFixture();
    const original = await f.service.bootstrapWithRefreshToken(
      "original-refresh-token",
    );
    const intent = await f.service.beginReauthentication(
      original.sessionId,
      original.csrfToken,
      "google",
    );
    const state = new URL(intent.authorizationUrl!).searchParams.get("state")!;
    const before = JSON.stringify(
      f.store.sessions.get(sessionKey(original.sessionId)),
    );
    clock.now += 2000;
    f.cognito.result = {
      ...tokens("google-new-access-token", "google-new-refresh-token"),
      authenticationTimeMs: clock.now,
      subject: mismatch ? "different-subject" : "synthetic-subject-a",
    };
    const complete = () =>
      f.service.completeGoogleAuthorization(
        intent.transactionId,
        state,
        "synthetic-authorization-code",
        original.sessionId,
      );
    if (mismatch) {
      await assert.rejects(complete(), WebReauthenticationError);
      assert.deepEqual(
        JSON.stringify(f.store.sessions.get(sessionKey(original.sessionId))),
        before,
      );
    } else {
      const result = await complete();
      assert.equal(result.sessionId, original.sessionId);
      assert.equal(result.reauthenticated, true);
    }
    assert.equal(f.store.sessions.size, 1);
  });

test("AUT-18 intents cannot cross sessions or survive logout; refresh is not interactive evidence", async () => {
  const f = reauthFixture();
  const first = await f.service.bootstrapWithRefreshToken(
      "original-refresh-token",
    ),
    second = await f.service.bootstrapWithRefreshToken("second-refresh-token");
  const intent = await f.service.beginReauthentication(
    first.sessionId,
    first.csrfToken,
    "srp",
  );
  clock.now += 2000;
  f.cognito.result = {
    ...tokens("new-access-token", "new-refresh-token"),
    authenticationTimeMs: clock.now,
  };
  await assert.rejects(
    f.service.completeNativeReauthentication(
      second.sessionId,
      second.csrfToken,
      intent.transactionId,
      "new-access-token",
    ),
  );
  await f.service.logout(first.sessionId, first.csrfToken);
  await assert.rejects(
    f.service.completeNativeReauthentication(
      first.sessionId,
      first.csrfToken,
      intent.transactionId,
      "new-access-token",
    ),
  );
});

test("AUT-18 a later refresh cannot retain step-up freshness from native reauthentication", async () => {
  const f = reauthFixture();
  const original = await f.service.bootstrapWithRefreshToken(
    "original-refresh-token",
  );
  const originalAuth = original.authenticationTime.getTime();
  const intent = await f.service.beginReauthentication(
    original.sessionId,
    original.csrfToken,
    "srp",
  );
  clock.now += 2000;
  f.cognito.result = {
    ...tokens("new-interactive-access-token"),
    authenticationTimeMs: clock.now,
  };
  await f.service.completeNativeReauthentication(
    original.sessionId,
    original.csrfToken,
    intent.transactionId,
    "new-interactive-access-token",
  );
  f.cognito.refresh = async () => ({
    ...tokens("refreshed-original-access-token"),
    authenticationTimeMs: originalAuth,
  });
  const restored = await f.service.restore(original.sessionId, {
    csrfToken: original.csrfToken,
    forceRefresh: true,
  });
  assert.equal(restored.authenticationTime.getTime(), originalAuth);
});
