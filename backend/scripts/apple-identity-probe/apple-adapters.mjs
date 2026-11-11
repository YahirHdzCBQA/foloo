/** D-21: bounded Apple transport for the isolated probe. The signer stays outside it. */
const appleOrigin = 'https://appleid.apple.com';

export function createAppleAdapters({ signClientSecret, fetchRequest = fetch }) {
  async function readJson(path, options = {}) {
    const response = await fetchRequest(new URL(path, appleOrigin), {
      ...options,
      redirect: 'error',
      signal: AbortSignal.timeout(5000),
    });
    if (!response.ok || !response.body) {
      await response.body?.cancel();
      throw new Error('Apple request failed');
    }
    const reader = response.body.getReader();
    const chunks = [];
    let size = 0;
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > 65536) throw new Error('Apple response too large');
        chunks.push(value);
      }
      return JSON.parse(Buffer.concat(chunks).toString('utf8'));
    } finally {
      await reader.cancel().catch(() => {});
      reader.releaseLock();
    }
  }

  return {
    async exchange(fields) {
      const clientSecret = await signClientSecret();
      return readJson('/auth/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ ...fields, client_secret: clientSecret }),
      });
    },
    async resolveKey(kid) {
      const { keys } = await readJson('/auth/keys');
      const matches = keys.filter((key) => key.kid === kid);
      return matches.length === 1 ? matches[0] : undefined;
    },
  };
}
