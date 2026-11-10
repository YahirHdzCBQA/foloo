/** Validates native or approved federated Cognito identities for private grants.
 * Email lookup never becomes account ownership: the validated parent `sub`
 * remains the only key passed to PostgreSQL (AUT-10, MON-21).
 */

import {
  ListUsersCommand,
  type CognitoIdentityProviderClient,
  type UserType,
} from "@aws-sdk/client-cognito-identity-provider";

export async function lookupVerifiedAdministrativeIdentity(
  client: Pick<CognitoIdentityProviderClient, "send">,
  userPoolId: string,
  candidateEmail: string,
) {
  const email = administrativeEmail(candidateEmail);
  const users = await client.send(
    new ListUsersCommand({
      UserPoolId: userPoolId,
      Filter: `email = "${email.replaceAll("\\", "\\\\")}"`,
      Limit: 2,
    }),
  );
  if (users.Users?.length !== 1) {
    throw new Error("Administrative identity is missing or ambiguous.");
  }
  return verifiedAdministrativeIdentity(users.Users[0]!, email);
}

/** Resolves an authenticated owner without trusting any client-provided email. */
export async function lookupVerifiedAdministrativeIdentityBySubject(
  client: Pick<CognitoIdentityProviderClient, "send">,
  userPoolId: string,
  subject: string,
) {
  const normalizedSubject = administrativeSubject(subject);
  const users = await client.send(
    new ListUsersCommand({
      UserPoolId: userPoolId,
      Filter: `sub = "${normalizedSubject}"`,
      Limit: 2,
    }),
  );
  if (users.Users?.length !== 1) {
    throw new Error("Administrative identity is missing or ambiguous.");
  }
  return verifiedAdministrativeIdentity(users.Users[0]!);
}

export function verifiedAdministrativeIdentity(
  user: UserType,
  expectedEmail?: string,
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
    !email ||
    (expectedEmail !== undefined &&
      email !== expectedEmail.trim().toLowerCase()) ||
    !subject
  ) {
    throw new Error("Administrative identity is not enabled and verified.");
  }
  return { subject, email, emailVerified: true as const };
}

function administrativeSubject(value: string): string {
  const normalized = value.trim();
  if (!/^[A-Za-z0-9_-]{1,128}$/u.test(normalized)) {
    throw new Error("Administrative entitlement subject is invalid.");
  }
  return normalized;
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

function administrativeEmail(value: string): string {
  const normalized = value.trim().toLowerCase();
  if (!/^[^\s@"]+@[^\s@"]+$/u.test(normalized)) {
    throw new Error("Administrative entitlement email is invalid.");
  }
  return normalized;
}
