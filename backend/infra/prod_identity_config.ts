/** Validates the explicit, non-secret inputs used to synthesize FolooIdentity-prod. */

export type ProdIdentityProviderConfig = Readonly<{
  domainPrefix: string;
  google: Readonly<{ enabled: boolean; clientId?: string }>;
  apple: Readonly<{
    enabled: boolean;
    servicesId?: string;
    teamId?: string;
    keyId?: string;
  }>;
  triggers: Readonly<{
    preSignUpFunctionArn?: string;
    postAuthenticationFunctionArn?: string;
  }>;
}>;

function flag(name: string, value: unknown): boolean {
  if (value === undefined || value === false || value === "false") return false;
  if (value === true || value === "true") return true;
  throw new Error(`${name} must be true or false.`);
}

function optionalText(name: string, value: unknown): string | undefined {
  if (value === undefined) return undefined;
  if (typeof value !== "string" || value.trim().length === 0)
    throw new Error(`${name} must be a non-empty string.`);
  return value.trim();
}

/** Fails closed instead of inventing public Cognito or provider identifiers. */
export function prodIdentityProviderConfig(
  context: (name: string) => unknown,
): ProdIdentityProviderConfig {
  const domainPrefix = optionalText(
    "prodCognitoDomainPrefix",
    context("prodCognitoDomainPrefix"),
  );
  if (
    !domainPrefix ||
    !/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/u.test(domainPrefix)
  ) {
    throw new Error(
      "prodCognitoDomainPrefix is required and must be a valid Cognito prefix.",
    );
  }
  const googleEnabled = flag(
    "prodGoogleIdentityProviderEnabled",
    context("prodGoogleIdentityProviderEnabled"),
  );
  const googleClientId = optionalText(
    "prodGoogleClientId",
    context("prodGoogleClientId"),
  );
  const appleEnabled = flag(
    "prodAppleIdentityProviderEnabled",
    context("prodAppleIdentityProviderEnabled"),
  );
  const apple = {
    servicesId: optionalText(
      "prodAppleServicesId",
      context("prodAppleServicesId"),
    ),
    teamId: optionalText("prodAppleTeamId", context("prodAppleTeamId")),
    keyId: optionalText("prodAppleKeyId", context("prodAppleKeyId")),
  };
  if (googleEnabled !== Boolean(googleClientId))
    throw new Error(
      "Google PROD configuration must be enabled and complete together.",
    );
  const appleComplete = Boolean(
    apple.servicesId && apple.teamId && apple.keyId,
  );
  const appleConfigured = Boolean(
    apple.servicesId || apple.teamId || apple.keyId,
  );
  if (appleEnabled !== appleComplete || (!appleEnabled && appleConfigured))
    throw new Error(
      "Apple PROD configuration must be enabled and complete together.",
    );
  const triggers = {
    preSignUpFunctionArn: optionalText(
      "prodPreSignUpFunctionArn",
      context("prodPreSignUpFunctionArn"),
    ),
    postAuthenticationFunctionArn: optionalText(
      "prodPostAuthenticationFunctionArn",
      context("prodPostAuthenticationFunctionArn"),
    ),
  };
  if (
    Boolean(triggers.preSignUpFunctionArn) !==
    Boolean(triggers.postAuthenticationFunctionArn)
  )
    throw new Error("PROD Cognito triggers must be configured as a pair.");
  return {
    domainPrefix,
    google: { enabled: googleEnabled, clientId: googleClientId },
    apple: { enabled: appleEnabled, ...apple },
    triggers,
  };
}
