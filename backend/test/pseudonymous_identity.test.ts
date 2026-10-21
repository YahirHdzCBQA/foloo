/** Unit coverage for the isolated INF-20/RNF-09 identity primitives. */

import assert from "node:assert/strict";
import test from "node:test";

import {
  canonicalizeVerifiedEmail,
  EMAIL_CANONICALIZATION_POLICY,
  InvalidCanonicalEmailError,
  InvalidCanonicalSubjectError,
  InvalidHmacKeyVersionError,
  InvalidHmacOutputError,
  NodeHmacSha256Generator,
  PseudonymousEmailIdentifierService,
  PseudonymousSubjectIdentifierService,
  SUBJECT_IDENTITY_POLICY,
  type HmacSha256KeyProvider,
} from "../src/account_deletion/pseudonymous_identity.js";

class FixtureKeyProvider implements HmacSha256KeyProvider<Uint8Array> {
  readonly requestedVersions: string[] = [];

  constructor(private readonly keys: ReadonlyMap<string, Uint8Array>) {}

  async getKey(keyVersion: string): Promise<Uint8Array> {
    this.requestedVersions.push(keyVersion);
    const key = this.keys.get(keyVersion);
    if (!key) throw new Error("Fixture key version is unavailable.");
    return key;
  }
}

const fixtureKeys = new Map<string, Uint8Array>([
  ["v1", new Uint8Array(32).fill(0x11)],
  ["v2", new Uint8Array(32).fill(0x22)],
]);

test("RNF-09 local engine matches a public HMAC-SHA-256 test vector", async () => {
  const mac = await new NodeHmacSha256Generator().generate(
    new TextEncoder().encode("Jefe"),
    new TextEncoder().encode("what do ya want for nothing?"),
  );
  assert.equal(
    Buffer.from(mac).toString("hex"),
    "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843",
  );
});

test("INF-20 canonicalizes accidental whitespace and case consistently", () => {
  assert.equal(
    canonicalizeVerifiedEmail("  Synthetic.User@EXAMPLE.TEST  "),
    "synthetic.user@example.test",
  );
  assert.equal(
    canonicalizeVerifiedEmail("SYNTHETIC.USER@example.test"),
    canonicalizeVerifiedEmail("synthetic.user@EXAMPLE.TEST"),
  );
});

test("INF-20 normalizes Unicode without inventing provider alias rules", () => {
  assert.equal(
    canonicalizeVerifiedEmail("TE\u0301ST@BÜCHER.TEST"),
    "tést@xn--bcher-kva.test",
  );
  assert.notEqual(
    canonicalizeVerifiedEmail("synthetic+qa@example.test"),
    canonicalizeVerifiedEmail("synthetic@example.test"),
  );
  assert.notEqual(
    canonicalizeVerifiedEmail("synthetic.user@example.test"),
    canonicalizeVerifiedEmail("syntheticuser@example.test"),
  );
});

test("INF-20 rejects values outside the explicit provisional policy", () => {
  for (const value of [
    "",
    "not-an-email",
    "two@@example.test",
    "white space@example.test",
    ".leading@example.test",
    "trailing.@example.test",
    "double..dot@example.test",
    '"quoted"@example.test',
    "user@-example.test",
    "user@example-.test",
    "user@example.test.",
  ]) {
    assert.throws(
      () => canonicalizeVerifiedEmail(value),
      InvalidCanonicalEmailError,
      value,
    );
  }
});

test("RNF-09 generates a deterministic HMAC identifier with fake keys", async () => {
  const keys = new FixtureKeyProvider(fixtureKeys);
  const service = new PseudonymousEmailIdentifierService(
    keys,
    new NodeHmacSha256Generator(),
  );

  const first = await service.identify("Case@Test.Example", "v1");
  const equivalent = await service.identify(" case@test.example ", "v1");
  const different = await service.identify("other@test.example", "v1");

  assert.deepEqual(first, equivalent);
  assert.notEqual(first.digest, different.digest);
  assert.equal(first.algorithm, "HMAC-SHA-256");
  assert.equal(first.canonicalizationPolicy, EMAIL_CANONICALIZATION_POLICY);
  assert.equal(first.keyVersion, "v1");
  assert.match(first.digest, /^[A-Za-z0-9_-]{43}$/u);
  assert.deepEqual(keys.requestedVersions, ["v1", "v1", "v1"]);
});

test("RNF-09 separates key versions and preserves dots and plus suffixes", async () => {
  const service = new PseudonymousEmailIdentifierService(
    new FixtureKeyProvider(fixtureKeys),
    new NodeHmacSha256Generator(),
  );

  const v1 = await service.identify("fixture.user+one@example.test", "v1");
  const v2 = await service.identify("fixture.user+one@example.test", "v2");
  const noPlus = await service.identify("fixture.user@example.test", "v1");
  const noDot = await service.identify("fixtureuser+one@example.test", "v1");

  assert.notEqual(v1.digest, v2.digest);
  assert.notEqual(v1.digest, noPlus.digest);
  assert.notEqual(v1.digest, noDot.digest);
});

test("RNF-09 rejects invalid versions before requesting a key", async () => {
  const keys = new FixtureKeyProvider(fixtureKeys);
  const service = new PseudonymousEmailIdentifierService(
    keys,
    new NodeHmacSha256Generator(),
  );

  await assert.rejects(
    service.identify("fixture@example.test", "../../secret"),
    InvalidHmacKeyVersionError,
  );
  assert.deepEqual(keys.requestedVersions, []);
});

test("RNF-09 rejects a generator that is not a SHA-256-length MAC", async () => {
  const service = new PseudonymousEmailIdentifierService(
    new FixtureKeyProvider(fixtureKeys),
    { generate: async () => new Uint8Array(31) },
  );

  await assert.rejects(
    service.identify("fixture@example.test", "v1"),
    InvalidHmacOutputError,
  );
});

test("INF-21 pseudonymizes canonical subjects without email-domain overlap", async () => {
  const keys = new FixtureKeyProvider(fixtureKeys);
  const hmac = new NodeHmacSha256Generator();
  const subjects = new PseudonymousSubjectIdentifierService(keys, hmac);
  const emails = new PseudonymousEmailIdentifierService(keys, hmac);
  const syntheticSubject = "00000000-0000-4000-8000-000000000001";

  const subject = await subjects.identify(syntheticSubject, "v1");
  const email = await emails.identify("subject@example.test", "v1");

  assert.equal(subject.identityPolicy, SUBJECT_IDENTITY_POLICY);
  assert.notEqual(subject.digest, email.digest);
  assert.equal(subject.keyVersion, "v1");
});

test("INF-21 preserves exact subject identity and rejects ambiguous input", async () => {
  const subjects = new PseudonymousSubjectIdentifierService(
    new FixtureKeyProvider(fixtureKeys),
    new NodeHmacSha256Generator(),
  );
  const lower = await subjects.identify("synthetic-subject", "v1");
  const upper = await subjects.identify("Synthetic-Subject", "v1");

  assert.notEqual(lower.digest, upper.digest);
  await assert.rejects(
    subjects.identify(" synthetic-subject ", "v1"),
    InvalidCanonicalSubjectError,
  );
  await assert.rejects(
    subjects.identify("", "v1"),
    InvalidCanonicalSubjectError,
  );
});
