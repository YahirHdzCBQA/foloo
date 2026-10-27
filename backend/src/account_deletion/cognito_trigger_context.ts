/** Validates Cognito trigger provenance before Account Deletion guard work. */

type CognitoTriggerContext = Readonly<{
  userPoolId: string;
  triggerSource: string;
  userName: string;
  callerContext?: Readonly<{ clientId?: string }>;
  request: Readonly<{ userAttributes: Readonly<Record<string, string>> }>;
}>;

export type CognitoGuardTriggerKind = "pre-sign-up" | "post-authentication";

export type ValidatedCognitoTriggerContext = Readonly<{
  provider: "COGNITO" | string;
}>;

/**
 * Rejects trigger spoofing and unsupported identity providers without exposing
 * subject, email, client ID or pool details in errors (AUT-18, RNF-09).
 */
export function validateCognitoGuardTriggerContext(
  event: CognitoTriggerContext,
  kind: CognitoGuardTriggerKind,
  environment: NodeJS.ProcessEnv = process.env,
): ValidatedCognitoTriggerContext {
  const expectedPoolId = required(environment, "COGNITO_USER_POOL_ID");
  const allowedClientIds = requiredSet(
    environment,
    "COGNITO_ALLOWED_APP_CLIENT_IDS",
  );
  const allowedFederatedProviders = requiredSet(
    environment,
    "COGNITO_ALLOWED_FEDERATED_PROVIDERS",
  );
  if (event.userPoolId !== expectedPoolId) deny();
  const clientId = event.callerContext?.clientId;
  if (!clientId || !allowedClientIds.has(clientId)) deny();

  if (kind === "pre-sign-up") {
    if (
      event.triggerSource !== "PreSignUp_SignUp" &&
      event.triggerSource !== "PreSignUp_ExternalProvider"
    ) {
      deny();
    }
    if (event.triggerSource === "PreSignUp_SignUp") {
      if (federatedProvider(event)) deny();
      return { provider: "COGNITO" };
    }
    const provider = federatedProvider(event);
    if (!provider || !allowedFederatedProviders.has(provider)) deny();
    return { provider };
  }

  if (event.triggerSource !== "PostAuthentication_Authentication") deny();
  const provider = federatedProvider(event);
  if (provider && !allowedFederatedProviders.has(provider)) deny();
  return { provider: provider ?? "COGNITO" };
}

function federatedProvider(event: CognitoTriggerContext): string | undefined {
  const identities = event.request.userAttributes.identities;
  if (identities) {
    try {
      const parsed: unknown = JSON.parse(identities);
      if (!Array.isArray(parsed) || parsed.length !== 1) deny();
      const identity = parsed[0];
      if (!identity || typeof identity !== "object") deny();
      const provider = Reflect.get(identity, "providerName");
      if (typeof provider !== "string" || provider.trim().length === 0) deny();
      return provider;
    } catch {
      deny();
    }
  }
  if (event.triggerSource === "PreSignUp_ExternalProvider") {
    const separator = event.userName.indexOf("_");
    if (separator <= 0) deny();
    return event.userName.slice(0, separator);
  }
  return undefined;
}

function required(environment: NodeJS.ProcessEnv, name: string): string {
  const value = environment[name]?.trim();
  if (!value) throw new Error("Cognito guard configuration is incomplete.");
  return value;
}

function requiredSet(
  environment: NodeJS.ProcessEnv,
  name: string,
): ReadonlySet<string> {
  const values = required(environment, name)
    .split(",")
    .map((value) => value.trim())
    .filter((value) => value.length > 0);
  if (values.length === 0 || new Set(values).size !== values.length) {
    throw new Error("Cognito guard configuration is incomplete.");
  }
  return new Set(values);
}

function deny(): never {
  throw new Error("Cognito authentication context is not permitted.");
}
