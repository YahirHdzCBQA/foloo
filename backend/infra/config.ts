/** Central AWS environment configuration for isolated DEV and PROD stacks. */

export type EnvironmentName = "dev" | "prod";

export type EnvironmentConfig = {
  name: EnvironmentName;
  billingEnabled: boolean;
  region: "us-east-1";
  userPoolId: string;
  appClientId: string;
  databaseName: string;
  databaseBackupRetentionDays: number;
  databaseDeletionProtection: boolean;
  vpcCidr: string;
  sesIdentityName: string;
  manageSesIdentity: boolean;
  webAuth: {
    callbackUrls: readonly string[];
    bffCallbackUrl: string;
    logoutUrls: readonly string[];
    allowedOrigins: readonly string[];
    cognitoDomain: string;
    successRedirectPath: string;
    sessionPolicy: {
      absoluteDurationSeconds: number;
      idleDurationSeconds: number;
    };
  };
  stripeSecretName?: string;
  stripeWebhookSecretName?: string;
  stripePriceId?: string;
  billingSuccessUrl?: string;
  billingCancelUrl?: string;
  billingPortalReturnUrl?: string;
};

export function environmentConfig(
  name: string,
  env: NodeJS.ProcessEnv = process.env,
): EnvironmentConfig {
  if (name !== "dev" && name !== "prod")
    throw new Error(`Environment ${name} has no approved configuration.`);
  if (env.BILLING_ENABLED && !["true", "false"].includes(env.BILLING_ENABLED))
    throw new Error("BILLING_ENABLED must be true or false.");
  if (name === "prod") return productionEnvironmentConfig(env);
  const config: EnvironmentConfig = {
    name: "dev",
    region: "us-east-1",
    userPoolId: "us-east-1_QVm3dWe4O",
    appClientId: "6jong3atp2crqcsde6g215ant8",
    databaseName: "foloo",
    // DEV remains aligned with its deployed Free Tier-compatible setting.
    databaseBackupRetentionDays: 1,
    databaseDeletionProtection: false,
    vpcCidr: "10.42.0.0/16",
    sesIdentityName: "foloo.io",
    manageSesIdentity: true,
    webAuth: {
      callbackUrls: [
        "https://foloo.io/auth/callback",
        "https://foloo.io/api/auth/google/callback",
      ],
      bffCallbackUrl: "https://foloo.io/api/auth/google/callback",
      logoutUrls: ["https://foloo.io/login"],
      allowedOrigins: ["https://foloo.io"],
      cognitoDomain: "us-east-1qvm3dwe4o.auth.us-east-1.amazoncognito.com",
      successRedirectPath: "/dashboard",
      // FOL-AUTH-02 provisional DEV defaults; Security must approve activation.
      sessionPolicy: {
        absoluteDurationSeconds: 12 * 60 * 60,
        idleDurationSeconds: 30 * 60,
      },
    },
    billingEnabled: env.BILLING_ENABLED !== "false",
    stripeSecretName: "foloo/dev/stripe-api-key",
    stripeWebhookSecretName: "foloo/dev/stripe-webhook-signing",
    // Stripe test mode: "Foloo" yearly, 89 USD / 1,780 MXN (D-02); env overrides.
    stripePriceId: env.STRIPE_PRICE_ID ?? "price_1UVXnvCp0Un1sf9u7wMePBtt",
    billingSuccessUrl:
      env.BILLING_SUCCESS_URL ?? "https://foloo.io/dashboard?billing=success",
    billingCancelUrl:
      env.BILLING_CANCEL_URL ?? "https://foloo.io/dashboard?billing=cancel",
    billingPortalReturnUrl:
      env.BILLING_PORTAL_RETURN_URL ?? "https://foloo.io/dashboard",
  };
  validateBillingConfig(config);
  return config;
}

function productionEnvironmentConfig(
  env: NodeJS.ProcessEnv,
): EnvironmentConfig {
  const required = {
    FOLOO_PROD_COGNITO_USER_POOL_ID: env.FOLOO_PROD_COGNITO_USER_POOL_ID,
    FOLOO_PROD_COGNITO_APP_CLIENT_ID: env.FOLOO_PROD_COGNITO_APP_CLIENT_ID,
    FOLOO_PROD_COGNITO_DOMAIN: env.FOLOO_PROD_COGNITO_DOMAIN,
  };
  const missing = Object.entries(required)
    .filter(([, value]) => !value?.trim())
    .map(([key]) => key);
  if (missing.length > 0) {
    throw new Error(
      `PROD requires explicit public Cognito configuration: ${missing.join(", ")}.`,
    );
  }
  const userPoolId = required.FOLOO_PROD_COGNITO_USER_POOL_ID!.trim();
  const appClientId = required.FOLOO_PROD_COGNITO_APP_CLIENT_ID!.trim();
  const cognitoDomain = required.FOLOO_PROD_COGNITO_DOMAIN!.trim();
  if (!/^us-east-1_[A-Za-z0-9]+$/u.test(userPoolId)) {
    throw new Error("FOLOO_PROD_COGNITO_USER_POOL_ID is invalid.");
  }
  if (!/^[a-z0-9]{20,128}$/u.test(appClientId)) {
    throw new Error("FOLOO_PROD_COGNITO_APP_CLIENT_ID is invalid.");
  }
  if (
    cognitoDomain.includes("://") ||
    cognitoDomain.includes("/") ||
    !cognitoDomain.endsWith(".auth.us-east-1.amazoncognito.com")
  ) {
    throw new Error("FOLOO_PROD_COGNITO_DOMAIN is invalid.");
  }
  if (
    userPoolId === "us-east-1_QVm3dWe4O" ||
    appClientId === "6jong3atp2crqcsde6g215ant8" ||
    cognitoDomain === "us-east-1qvm3dwe4o.auth.us-east-1.amazoncognito.com"
  ) {
    throw new Error("PROD must not reuse known DEV Cognito identifiers.");
  }
  if (env.BILLING_ENABLED === "true") {
    throw new Error(
      "Billing and public payments are outside the PROD V1 scope.",
    );
  }
  return {
    name: "prod",
    region: "us-east-1",
    userPoolId,
    appClientId,
    databaseName: "foloo",
    databaseBackupRetentionDays: 15,
    databaseDeletionProtection: true,
    vpcCidr: "10.43.0.0/16",
    sesIdentityName: "foloo.io",
    manageSesIdentity: false,
    webAuth: {
      callbackUrls: [
        "https://foloo.io/auth/callback",
        "https://foloo.io/api/auth/google/callback",
      ],
      bffCallbackUrl: "https://foloo.io/api/auth/google/callback",
      logoutUrls: ["https://foloo.io/login"],
      allowedOrigins: ["https://foloo.io"],
      cognitoDomain,
      successRedirectPath: "/dashboard",
      sessionPolicy: {
        absoluteDurationSeconds: 12 * 60 * 60,
        idleDurationSeconds: 30 * 60,
      },
    },
    billingEnabled: false,
  };
}

/** Builds the backend configuration from Cognito resources owned by FolooIdentity-prod. */
export function managedProductionEnvironmentConfig(identity: {
  userPoolId: string;
  appClientId: string;
  cognitoDomain: string;
}): EnvironmentConfig {
  const baseline = productionEnvironmentConfig({
    BILLING_ENABLED: "false",
    FOLOO_PROD_COGNITO_USER_POOL_ID: "us-east-1_ProdManaged",
    FOLOO_PROD_COGNITO_APP_CLIENT_ID: "abcdefghijklmnopqrstuvwx",
    FOLOO_PROD_COGNITO_DOMAIN:
      "foloo-prod-managed.auth.us-east-1.amazoncognito.com",
  });
  return {
    ...baseline,
    userPoolId: identity.userPoolId,
    appClientId: identity.appClientId,
    webAuth: { ...baseline.webAuth, cognitoDomain: identity.cognitoDomain },
  };
}

export function validateBillingConfig(config: EnvironmentConfig) {
  if (!config.billingEnabled) return;
  const required = {
    STRIPE_PRICE_ID: config.stripePriceId,
    BILLING_SUCCESS_URL: config.billingSuccessUrl,
    BILLING_CANCEL_URL: config.billingCancelUrl,
    BILLING_PORTAL_RETURN_URL: config.billingPortalReturnUrl,
    stripeSecretName: config.stripeSecretName,
    stripeWebhookSecretName: config.stripeWebhookSecretName,
  };
  const missing = Object.entries(required)
    .filter(([, value]) => !value?.trim())
    .map(([key]) => key);
  if (missing.length)
    throw new Error(
      `Billing enabled: missing ${missing.join(", ")}. Supply values or explicitly set BILLING_ENABLED=false.`,
    );
}

/** Allows the temporary unlimited switch only in an explicitly selected DEV stack. */
export function unlimitedQaModeForEnvironment(
  environment: string,
  rawValue: unknown,
): boolean {
  const enabled = rawValue === true || rawValue === "true";
  if (enabled && environment !== "dev") {
    throw new Error("FOLOO unlimited QA mode is restricted to DEV.");
  }
  return enabled;
}

/** Enables the private administrative entitlement boundary when selected. */
export function administrativeEntitlementForEnvironment(
  environment: string,
  rawValue: unknown,
): boolean {
  const enabled = rawValue === true || rawValue === "true";
  if (enabled && environment !== "dev" && environment !== "prod") {
    throw new Error("Administrative entitlements require DEV or PROD.");
  }
  return enabled;
}

export type AutomaticEntitlementConfig = Readonly<{
  enabled: boolean;
  enqueueEnabled: boolean;
  workerEnabled: boolean;
}>;

/** Separates passive resources, login enqueueing, and queue consumption. */
export function automaticEntitlementConfigForEnvironment(
  environment: string,
  rawEnabled: unknown,
  rawEnqueueEnabled: unknown,
  rawWorkerEnabled: unknown,
): AutomaticEntitlementConfig {
  const enabled = rawEnabled === true || rawEnabled === "true";
  const enqueueEnabled =
    rawEnqueueEnabled === true || rawEnqueueEnabled === "true";
  const workerEnabled =
    rawWorkerEnabled === true || rawWorkerEnabled === "true";
  if (
    (enabled || enqueueEnabled || workerEnabled) &&
    environment !== "dev" &&
    environment !== "prod"
  ) {
    throw new Error("Automatic entitlements require DEV or PROD.");
  }
  if ((enqueueEnabled || workerEnabled) && !enabled) {
    throw new Error(
      "Automatic entitlement processing requires its passive boundary.",
    );
  }
  return { enabled, enqueueEnabled, workerEnabled };
}

/** Enables STORE-02D transactional email only through an explicit opt-in. */
export function accountDeletionSesNotificationsForEnvironment(
  environment: string,
  rawValue: unknown,
): boolean {
  const enabled = rawValue === true || rawValue === "true";
  if (enabled && environment !== "dev" && environment !== "prod") {
    throw new Error("Account Deletion SES requires DEV or PROD.");
  }
  return enabled;
}

export type WebSessionQaConfig = Readonly<{
  normalAccessEnabled?: boolean;
  enabled: boolean;
  subjectHashes: readonly string[];
}>;

export type CognitoFederatedProviderConfig = Readonly<{
  allowedProviderNames: readonly ("Google" | "SignInWithApple" | "Microsoft")[];
}>;

export type CognitoAppleIdentityProviderConfig = Readonly<{
  enabled: boolean;
  servicesId: "com.foloo.signin";
  teamId: "PU238KF2F9";
  keyId: "6LK763G44F";
  privateKeySecretArn?: string;
}>;

/**
 * Keeps the Apple IdP absent by default and requires an environment-local ARN.
 * The secret value itself must never be passed through CDK context or env.
 */
export function cognitoAppleIdentityProviderConfigForEnvironment(
  environment: string,
  rawEnabled: unknown,
  rawPrivateKeySecretArn: unknown,
): CognitoAppleIdentityProviderConfig {
  const enabled = activationFlag(
    "cognitoAppleIdentityProviderEnabled",
    rawEnabled,
  );
  if (enabled && environment !== "dev" && environment !== "prod") {
    throw new Error("Apple identity provider requires DEV or PROD.");
  }
  if (!enabled) {
    if (rawPrivateKeySecretArn !== undefined) {
      throw new Error(
        "Apple private-key secret must not be configured while the IdP is disabled.",
      );
    }
    return {
      enabled: false,
      servicesId: "com.foloo.signin",
      teamId: "PU238KF2F9",
      keyId: "6LK763G44F",
    };
  }
  if (
    typeof rawPrivateKeySecretArn !== "string" ||
    !new RegExp(
      `^arn:aws:secretsmanager:us-east-1:\\d{12}:secret:foloo/${environment}/cognito/apple-private-key-[A-Za-z0-9]{6}$`,
      "u",
    ).test(rawPrivateKeySecretArn)
  ) {
    throw new Error(
      `Apple identity provider requires the dedicated complete ${environment.toUpperCase()} secret ARN.`,
    );
  }
  return {
    enabled: true,
    servicesId: "com.foloo.signin",
    teamId: "PU238KF2F9",
    keyId: "6LK763G44F",
    privateKeySecretArn: rawPrivateKeySecretArn,
  };
}

/**
 * Keeps Registration Guards aligned with externally verified Cognito IdPs.
 * Google is the baseline; Apple requires explicit validated configuration.
 * Microsoft remains outside the published V1 in PROD (AUT-17).
 */
export function cognitoFederatedProviderConfigForEnvironment(
  environment: string,
  rawAppleEnabled: unknown,
  rawMicrosoftEnabled: unknown,
): CognitoFederatedProviderConfig {
  const appleEnabled = activationFlag(
    "cognitoAppleSignInEnabled",
    rawAppleEnabled,
  );
  const microsoftEnabled = activationFlag(
    "cognitoMicrosoftSignInEnabled",
    rawMicrosoftEnabled,
  );
  if (microsoftEnabled && environment === "prod") {
    throw new Error("Microsoft sign-in is outside the published V1.");
  }
  if (
    (appleEnabled || microsoftEnabled) &&
    environment !== "dev" &&
    environment !== "prod"
  ) {
    throw new Error("Federated providers require DEV or PROD.");
  }
  return {
    allowedProviderNames: [
      "Google",
      ...(appleEnabled ? (["SignInWithApple"] as const) : []),
      ...(microsoftEnabled ? (["Microsoft"] as const) : []),
    ],
  };
}

export type AccountDeletionQaConfig = Readonly<{
  /** Legacy field: QA exception only; no implicit normal admission. */
  enabled: boolean;
  runtimeEnabled?: boolean;
  normalAccessEnabled?: boolean;
  intakeEnabled: boolean;
  registrationGuardEnabled: boolean;
  outboxRecoveryEnabled: boolean;
  restoreReconcilerEnabled: boolean;
  recoverySchedulerEnabled: boolean;
  workerEnabled: boolean;
  workerEventSourceEnabled: boolean;
  finalizerEnabled: boolean;
  subjectHashes: readonly string[];
}>;

/** Allows destructive deletion QA only for exactly one synthetic DEV identity. */
export function accountDeletionQaConfigForEnvironment(
  environment: string,
  rawEnabled: unknown,
  rawIntakeEnabled: unknown,
  rawSubjectHashes: unknown,
  rawRegistrationGuardEnabled?: unknown,
  rawOutboxRecoveryEnabled?: unknown,
  rawRestoreReconcilerEnabled?: unknown,
  rawRecoverySchedulerEnabled?: unknown,
  rawWorkerEnabled?: unknown,
  rawFinalizerEnabled?: unknown,
  rawWorkerEventSourceEnabled?: unknown,
  rawRuntimeEnabled?: unknown,
  rawNormalAccessEnabled?: unknown,
): AccountDeletionQaConfig {
  const enabled = activationFlag("accountDeletionQaEnabled", rawEnabled);
  // Omitted runtime flag preserves old QA deployments during code migration.
  const runtimeEnabled =
    rawRuntimeEnabled === undefined
      ? enabled
      : activationFlag("accountDeletionRuntimeEnabled", rawRuntimeEnabled);
  const normalAccessEnabled = activationFlag(
    "accountDeletionNormalAccessEnabled",
    rawNormalAccessEnabled,
  );
  if (enabled && normalAccessEnabled)
    throw new Error("Choose normal admission or QA, not both.");
  if ((enabled || normalAccessEnabled) && !runtimeEnabled)
    throw new Error("Deletion admission requires runtime.");
  const intakeEnabled = activationFlag(
    "accountDeletionQaIntakeEnabled",
    rawIntakeEnabled,
  );
  const registrationGuardEnabled = activationFlag(
    "accountDeletionRegistrationGuardEnabled",
    rawRegistrationGuardEnabled,
  );
  const outboxRecoveryEnabled = activationFlag(
    "accountDeletionOutboxRecoveryEnabled",
    rawOutboxRecoveryEnabled,
  );
  const restoreReconcilerEnabled = activationFlag(
    "accountDeletionRestoreReconcilerEnabled",
    rawRestoreReconcilerEnabled,
  );
  const recoverySchedulerEnabled = activationFlag(
    "accountDeletionRecoverySchedulerEnabled",
    rawRecoverySchedulerEnabled,
  );
  const workerEnabled = activationFlag(
    "accountDeletionWorkerEnabled",
    rawWorkerEnabled,
  );
  const finalizerEnabled = activationFlag(
    "accountDeletionFinalizerEnabled",
    rawFinalizerEnabled,
  );
  const workerEventSourceEnabled = activationFlag(
    "accountDeletionWorkerEventSourceEnabled",
    rawWorkerEventSourceEnabled,
  );
  const controls = {
    enabled,
    runtimeEnabled,
    normalAccessEnabled,
    intakeEnabled,
    registrationGuardEnabled,
    outboxRecoveryEnabled,
    restoreReconcilerEnabled,
    recoverySchedulerEnabled,
    workerEnabled,
    workerEventSourceEnabled,
    finalizerEnabled,
  };
  const subjectHashes =
    typeof rawSubjectHashes === "string" && rawSubjectHashes.trim().length > 0
      ? rawSubjectHashes.split(",").map((value) => value.trim())
      : [];
  if (enabled && environment !== "dev") {
    throw new Error("Account Deletion destructive QA is restricted to DEV.");
  }
  if (subjectHashes.some((value) => !/^[A-Za-z0-9_-]{43}$/u.test(value))) {
    throw new Error("Account Deletion QA subject hash is invalid.");
  }
  if (new Set(subjectHashes).size !== subjectHashes.length) {
    throw new Error("Account Deletion QA subject hashes must be unique.");
  }
  if (enabled && subjectHashes.length !== 1) {
    throw new Error(
      "Account Deletion destructive QA requires exactly one identity.",
    );
  }
  if (rawRuntimeEnabled !== undefined && !enabled && subjectHashes.length > 0) {
    throw new Error(
      "Disabled deletion QA must not retain subject authorizations.",
    );
  }
  if (subjectHashes.length > 1) {
    throw new Error(
      "Account Deletion destructive QA permits exactly one prepared identity.",
    );
  }
  if (subjectHashes.length > 0 && environment !== "dev") {
    throw new Error("Account Deletion QA identity preparation is DEV-only.");
  }
  if (intakeEnabled && !runtimeEnabled) {
    throw new Error(
      "Account Deletion intake requires the protected runtime to be enabled.",
    );
  }
  if (
    intakeEnabled &&
    (!workerEnabled || !finalizerEnabled || !outboxRecoveryEnabled)
  ) {
    throw new Error(
      "Account Deletion intake requires worker, finalizer, and outbox recovery.",
    );
  }
  if (workerEnabled && !runtimeEnabled) {
    throw new Error("Account Deletion worker requires runtime to be enabled.");
  }
  if (workerEventSourceEnabled && !workerEnabled) {
    throw new Error(
      "Account Deletion worker event source requires worker to be enabled.",
    );
  }
  if (workerEnabled && !finalizerEnabled) {
    throw new Error(
      "Account Deletion worker requires finalizer to be enabled.",
    );
  }
  if (finalizerEnabled && !workerEnabled) {
    throw new Error(
      "Account Deletion finalizer requires worker to be enabled.",
    );
  }
  if (outboxRecoveryEnabled && !workerEnabled) {
    throw new Error(
      "Account Deletion outbox recovery requires worker to be enabled.",
    );
  }
  if (recoverySchedulerEnabled && !outboxRecoveryEnabled) {
    throw new Error(
      "Account Deletion recovery scheduler requires outbox recovery to be enabled.",
    );
  }
  if (restoreReconcilerEnabled && !workerEnabled) {
    throw new Error(
      "Account Deletion restore reconciler requires worker to be enabled.",
    );
  }
  return { ...controls, subjectHashes };
}

function activationFlag(name: string, rawValue: unknown): boolean {
  if (rawValue === undefined || rawValue === false || rawValue === "false") {
    return false;
  }
  if (rawValue === true || rawValue === "true") return true;
  throw new Error(`${name} must be true or false.`);
}

/** Keeps QA pseudonymous while allowing explicitly selected normal access. */
export function webSessionQaConfigForEnvironment(
  environment: string,
  rawEnabled: unknown,
  rawSubjectHashes: unknown,
  rawNormalAccessEnabled: unknown = false,
): WebSessionQaConfig {
  const normalAccessEnabled = activationFlag(
    "webSessionNormalAccessEnabled",
    rawNormalAccessEnabled,
  );
  if (normalAccessEnabled && environment !== "dev" && environment !== "prod")
    throw new Error("Normal web access requires DEV or PROD.");
  const enabled = rawEnabled === true || rawEnabled === "true";
  if (enabled && environment !== "dev") {
    throw new Error("Web-session QA is restricted to DEV.");
  }
  const subjectHashes =
    typeof rawSubjectHashes === "string" && rawSubjectHashes.trim().length > 0
      ? rawSubjectHashes.split(",").map((value) => value.trim())
      : [];
  if (subjectHashes.some((value) => !/^[A-Za-z0-9_-]{43}$/u.test(value))) {
    throw new Error("Web-session QA subject hashes are invalid.");
  }
  if (new Set(subjectHashes).size !== subjectHashes.length) {
    throw new Error("Web-session QA subject hashes must be unique.");
  }
  if (enabled && subjectHashes.length === 0) {
    throw new Error("Web-session QA requires at least one subject hash.");
  }
  if (normalAccessEnabled && enabled)
    throw new Error("Choose normal or QA web admission, not both.");
  return {
    enabled: enabled || normalAccessEnabled,
    subjectHashes,
    ...(normalAccessEnabled ? { normalAccessEnabled: true } : {}),
  };
}
