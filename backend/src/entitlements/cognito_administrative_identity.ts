/** Validates native or approved federated Cognito identities for private grants.
 * Email lookup never becomes account ownership: the validated parent `sub`
 * remains the only key passed to PostgreSQL (AUT-10, MON-21).
 */

import type { UserType } from "@aws-sdk/client-cognito-identity-provider";

export function verifiedAdministrativeIdentity(
  user: UserType,
  expectedEmail: string,
) {
  const attributes = new Map(
    user.Attributes?.map((attribute) => [attribute.Name, attribute.Value]),
  );
  const subject = attributes.get("sub");
  const email = attributes.get("email")?.trim().toLowerCase();
  const nativeIdentity = user.UserStatus === "CONFIRMED";
  const federatedIdentity =
    user.UserStatus === "EXTERNAL_PROVIDER" &&
    supportedFederatedIdentity(attributes.get("identities"));
  if (
    user.Enabled !== true ||
    (!nativeIdentity && !federatedIdentity) ||
    attributes.get("email_verified") !== "true" ||
    email !== expectedEmail.trim().toLowerCase() ||
    !subject
  ) {
    throw new Error("Administrative identity is not enabled and verified.");
  }
  return { subject, emailVerified: true as const };
}

function supportedFederatedIdentity(raw: string | undefined): boolean {
  if (!raw) return false;
  try {
    const identities = JSON.parse(raw) as unknown;
    if (!Array.isArray(identities) || identities.length !== 1) return false;
    const provider = (identities[0] as { providerName?: unknown }).providerName;
    return provider === "Google" || provider === "SignInWithApple";
  } catch {
    return false;
  }
}
