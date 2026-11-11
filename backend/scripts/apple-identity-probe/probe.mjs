/** One-shot D-21 / AUT-10 probe. The host supplies trusted Cognito and Apple adapters. */
import { createPublicKey, randomBytes, verify } from 'node:crypto';

const issuer = 'https://appleid.apple.com';
const clientId = 'com.foloo.signin';
export const callbackUrl = 'https://apple-probe.foloo.io/d21/apple/callback';
const lifetimeMs = 5 * 60 * 1000;
const randomChallenge = () => randomBytes(32).toString('base64url');
const bounded = (value) => typeof value === 'string' && value.length > 0 && value.length <= 4096;

/** Bind a single browser attempt to a preapproved, server-verified test owner. */
export function createProbe({
  approvedOwner, cognitoProfile, exchange, resolveKey, now = Date.now,
}) {
  const { poolId, sub } = approvedOwner;
  const identities = cognitoProfile.identities.filter(
    ({ providerName }) => providerName === 'SignInWithApple',
  );
  if (!bounded(poolId) || !bounded(sub) || poolId !== cognitoProfile.poolId ||
      sub !== cognitoProfile.sub || identities.length !== 1 ||
      !bounded(identities[0].userId)) {
    throw new Error('Unapproved Cognito test identity');
  }

  const expectedSubject = identities[0].userId;
  const state = randomChallenge();
  const nonce = randomChallenge();
  const deadline = now() + lifetimeMs;
  let consumed = false;

  const authorization = new URL('/auth/authorize', issuer);
  authorization.search = new URLSearchParams({
    client_id: clientId, redirect_uri: callbackUrl, response_type: 'code',
    response_mode: 'form_post', state, nonce,
  }).toString();

  return {
    authorizationUrl: authorization.href,
    async complete({ method, contentType, body }) {
      if (consumed || now() >= deadline) return { status: 'closed' };
      if (method !== 'POST' ||
          contentType?.split(';')[0].trim().toLowerCase() !== 'application/x-www-form-urlencoded' ||
          typeof body !== 'string' || Buffer.byteLength(body) > 8192) {
        return { status: 'invalid_callback' };
      }

      const form = new URLSearchParams(body);
      if (form.getAll('state').length !== 1 || form.get('state') !== state) {
        return { status: 'invalid_callback' };
      }

      // Consume synchronously before the first await, including on cancellation.
      consumed = true;
      if (form.getAll('error').length === 1 &&
          form.get('error') === 'user_cancelled_authorize' && !form.has('code')) {
        return { status: 'cancelled' };
      }
      const code = form.get('code');
      if (form.has('error') || form.getAll('code').length !== 1 || !bounded(code)) {
        return { status: 'invalid_callback' };
      }

      try {
        const response = await exchange({
          client_id: clientId, redirect_uri: callbackUrl,
          grant_type: 'authorization_code', code,
        });
        const claims = await verifyIdentityToken(response.id_token, resolveKey);
        if (now() >= deadline) return { status: 'closed' };
        if (claims.iss !== issuer || claims.aud !== clientId ||
            !Number.isSafeInteger(claims.exp) || claims.exp * 1000 <= now() ||
            claims.nonce !== nonce || !bounded(claims.sub)) {
          return { status: 'invalid_token' };
        }
        return {
          status: 'verified',
          identityMatches: claims.sub === expectedSubject,
          credentialReceived: bounded(response.refresh_token) || bounded(response.access_token),
        };
      } catch {
        return { status: 'verification_failed' };
      }
    },
  };
}

async function verifyIdentityToken(token, resolveKey) {
  if (typeof token !== 'string' || token.length > 16384) throw new Error();
  const parts = token.split('.');
  if (parts.length !== 3 || parts.some((part) => !/^[\w-]+$/.test(part))) {
    throw new Error();
  }
  const [headerPart, payloadPart, signature] = parts;
  const header = JSON.parse(Buffer.from(headerPart, 'base64url'));
  if (header.alg !== 'RS256' || !bounded(header.kid) || header.crit !== undefined) {
    throw new Error();
  }
  // Resolve only from trusted Apple JWKS; token headers cannot select a URL.
  const jwk = await resolveKey(header.kid);
  if (jwk?.kid !== header.kid || jwk.kty !== 'RSA' ||
      (jwk.alg !== undefined && jwk.alg !== 'RS256') ||
      (jwk.use !== undefined && jwk.use !== 'sig')) {
    throw new Error();
  }
  const valid = verify(
    'RSA-SHA256', Buffer.from(`${headerPart}.${payloadPart}`),
    createPublicKey({ key: jwk, format: 'jwk' }), Buffer.from(signature, 'base64url'),
  );
  if (!valid) throw new Error();
  return JSON.parse(Buffer.from(payloadPart, 'base64url'));
}
