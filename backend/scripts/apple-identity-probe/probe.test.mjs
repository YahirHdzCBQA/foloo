/** AUT-10 / AUT-22 / E-01: isolated Apple identity probe, synthetic keys only. */
import assert from 'node:assert/strict';
import { generateKeyPairSync, sign } from 'node:crypto';
import test from 'node:test';
import { callbackUrl, createProbe } from './probe.mjs';

const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const jwk = { ...publicKey.export({ format: 'jwk' }), kid: 'fixture' };
const owner = { poolId: 'fixture-pool', sub: 'test-owner' };
const profile = {
  ...owner,
  identities: [{ providerName: 'SignInWithApple', userId: 'AppleSubject' }],
};
const encode = (data) => Buffer.from(JSON.stringify(data)).toString('base64url');

function fixture({ claims = {}, header = {}, credential = true, failure = false } = {}) {
  let time = 1_800_000_000_000;
  let calls = 0;
  const probe = createProbe({
    approvedOwner: owner, cognitoProfile: profile, now: () => time,
    resolveKey: async (kid) => kid === jwk.kid ? jwk : undefined,
    exchange: async (input) => {
      calls += 1;
      assert.deepEqual(input, {
        client_id: 'com.foloo.signin', redirect_uri: callbackUrl,
        grant_type: 'authorization_code', code: 'fixture-code',
      });
      if (failure) throw new Error('fixture-sensitive-error');
      const payload = {
        iss: 'https://appleid.apple.com', aud: 'com.foloo.signin',
        exp: time / 1000 + 60, nonce: params.get('nonce'), sub: 'AppleSubject',
        ...claims,
      };
      const data = `${encode({ alg: 'RS256', kid: 'fixture', ...header })}.${encode(payload)}`;
      const signature = sign('RSA-SHA256', Buffer.from(data), privateKey).toString('base64url');
      return {
        id_token: `${data}.${signature}`,
        refresh_token: credential ? 'fixture-sensitive-token' : undefined,
      };
    },
  });
  const params = new URL(probe.authorizationUrl).searchParams;
  const post = (body = new URLSearchParams({ state: params.get('state'), code: 'fixture-code' })) =>
    probe.complete({ method: 'POST', contentType: 'application/x-www-form-urlencoded', body: body.toString() });
  return { probe, params, post, calls: () => calls, expire: () => { time += 300_000; } };
}

test('AUT-10 verifies same subject and reports only booleans and status', async () => {
  const { params, post } = fixture();
  assert.equal(params.get('redirect_uri'), callbackUrl);
  assert.notEqual(params.get('state'), params.get('nonce'));
  assert.deepEqual(await post(), { status: 'verified', identityMatches: true, credentialReceived: true });
});

test('AUT-10 preserves exact subject matching and distinguishes missing credential', async () => {
  assert.deepEqual(await fixture({ claims: { sub: 'applesubject' }, credential: false }).post(), {
    status: 'verified', identityMatches: false, credentialReceived: false,
  });
});

for (const claims of [{ iss: 'https://example.invalid' }, { aud: 'different-client' },
  { exp: 1_800_000_000 }, { nonce: 'different-nonce' }]) {
  test(`AUT-22 rejects invalid ${Object.keys(claims)[0]}`, async () => {
    assert.deepEqual(await fixture({ claims }).post(), { status: 'invalid_token' });
  });
}

for (const header of [{ alg: 'none' }, { kid: 'unknown' }]) {
  test(`AUT-22 rejects unsupported ${Object.keys(header)[0]}`, async () => {
    assert.deepEqual(await fixture({ header }).post(), { status: 'verification_failed' });
  });
}

test('AUT-22 rejects signatures made with a different key', async () => {
  const { publicKey: other } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const probe = createProbe({
    approvedOwner: owner, cognitoProfile: profile,
    resolveKey: async () => ({ ...other.export({ format: 'jwk' }), kid: 'fixture' }),
    exchange: async () => {
      const data = `${encode({ alg: 'RS256', kid: 'fixture' })}.${encode({})}`;
      return { id_token: `${data}.${sign('RSA-SHA256', Buffer.from(data), privateKey).toString('base64url')}` };
    },
  });
  const state = new URL(probe.authorizationUrl).searchParams.get('state');
  assert.deepEqual(await probe.complete({
    method: 'POST', contentType: 'application/x-www-form-urlencoded',
    body: new URLSearchParams({ state, code: 'fixture-code' }).toString(),
  }), { status: 'verification_failed' });
});

test('AUT-22 rejects wrong/duplicate state and expired attempts before exchange', async () => {
  const { post, params, calls, expire } = fixture();
  assert.deepEqual(await post('state=incorrect&code=fixture-code'), { status: 'invalid_callback' });
  assert.deepEqual(await post(`state=${params.get('state')}&state=other&code=fixture-code`), { status: 'invalid_callback' });
  expire();
  assert.deepEqual(await post(), { status: 'closed' });
  assert.equal(calls(), 0);
});

test('AUT-22 consumes state before a concurrent callback or failed exchange', async () => {
  const { post, calls } = fixture({ failure: true });
  assert.deepEqual(await Promise.all([post(), post()]), [
    { status: 'verification_failed' }, { status: 'closed' },
  ]);
  assert.equal(calls(), 1);
});

test('AUT-10 rejects an owner outside the approved pool/subject binding', () => {
  for (const changed of [{ poolId: 'other' }, { sub: 'other' }, { identities: [] }]) {
    assert.throws(() => createProbe({
      approvedOwner: owner, cognitoProfile: { ...profile, ...changed },
    }), /Unapproved Cognito test identity/);
  }
});

test('AUT-22 rejects other methods and oversized forms without consuming state', async () => {
  const { probe, post, calls } = fixture();
  assert.deepEqual(await probe.complete({ method: 'GET' }), { status: 'invalid_callback' });
  assert.deepEqual(await post('x'.repeat(8193)), { status: 'invalid_callback' });
  assert.equal(calls(), 0);
  assert.equal((await post()).status, 'verified');
});

test('AUT-22 handles cancellation without exchanging or reopening the attempt', async () => {
  const { post, params, calls } = fixture();
  assert.deepEqual(await post(new URLSearchParams({
    state: params.get('state'), error: 'user_cancelled_authorize',
  })), { status: 'cancelled' });
  assert.deepEqual(await post(), { status: 'closed' });
  assert.equal(calls(), 0);
});

test('D-21 transport sends a signed form once to Apple and refuses redirects', async () => {
  const { createAppleAdapters } = await import('./apple-adapters.mjs');
  const requests = [];
  const adapters = createAppleAdapters({
    signClientSecret: async () => 'fixture-client-secret',
    fetchRequest: async (url, options) => {
      requests.push({ url, options });
      return Response.json(url.pathname === '/auth/keys'
        ? { keys: [jwk] } : { id_token: 'fixture-identity-token' });
    },
  });
  assert.deepEqual(await adapters.exchange({ code: 'fixture-code' }), { id_token: 'fixture-identity-token' });
  assert.deepEqual(await adapters.resolveKey(jwk.kid), jwk);
  assert.deepEqual(requests.map(({ url }) => url.href), [
    'https://appleid.apple.com/auth/token', 'https://appleid.apple.com/auth/keys',
  ]);
  assert.ok(requests.every(({ options }) => options.redirect === 'error'));
  assert.equal(requests[0].options.method, 'POST');
  assert.equal(requests[0].options.body.get('client_secret'), 'fixture-client-secret');
});

test('D-21 transport rejects oversized responses and ambiguous JWKS keys', async () => {
  const { createAppleAdapters } = await import('./apple-adapters.mjs');
  const adapters = createAppleAdapters({
    signClientSecret: async () => 'fixture-client-secret',
    fetchRequest: async (url) => url.pathname === '/auth/keys'
      ? Response.json({ keys: [jwk, jwk] })
      : new Response('x'.repeat(65_537)),
  });
  await assert.rejects(adapters.exchange({ code: 'fixture-code' }), /too large/);
  assert.equal(await adapters.resolveKey(jwk.kid), undefined);
});
