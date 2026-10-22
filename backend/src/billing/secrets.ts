/** Reads raw Stripe secrets from Secrets Manager; never logs secret material. */
import {
  GetSecretValueCommand,
  SecretsManagerClient,
} from "@aws-sdk/client-secrets-manager";
import { ApplicationError } from "../application/errors.js";
const client = new SecretsManagerClient({});
export const billingNotConfigured = () =>
  new ApplicationError(
    "billing_not_configured",
    503,
    "Billing is not configured.",
  );
/** Each Lambda container caches successful reads only; failures remain retryable. */
export function createBillingSecretReader(
  read = async (id: string) =>
    (await client.send(new GetSecretValueCommand({ SecretId: id })))
      .SecretString,
  now = Date.now,
) {
  const cache = new Map<string, { value: string; expires: number }>();
  return async (id: string | undefined): Promise<string> => {
    if (!id) throw billingNotConfigured();
    const cached = cache.get(id);
    if (cached && cached.expires > now()) return cached.value;
    try {
      const value = await read(id);
      if (!value) throw billingNotConfigured();
      cache.set(id, { value, expires: now() + 300_000 });
      return value;
    } catch {
      throw billingNotConfigured();
    }
  };
}
// SecretId accepts an exact name or complete ARN. CDK passes names, never partial ARNs.
export const readBillingSecret = createBillingSecretReader();
