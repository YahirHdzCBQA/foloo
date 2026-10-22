/** Central AWS environment configuration; PROD stays undefined until approved. */

export type EnvironmentConfig = {
  name: "dev";
  billingEnabled: boolean;
  region: "us-east-1";
  userPoolId: string;
  appClientId: string;
  databaseName: string;
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
  if (name !== "dev")
    throw new Error(`Environment ${name} has no approved configuration.`);
  if (env.BILLING_ENABLED && !["true", "false"].includes(env.BILLING_ENABLED))
    throw new Error("BILLING_ENABLED must be true or false.");
  const config: EnvironmentConfig = {
    name: "dev",
    region: "us-east-1",
    userPoolId: "us-east-1_QVm3dWe4O",
    appClientId: "6jong3atp2crqcsde6g215ant8",
    databaseName: "foloo",
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
    // Stripe test mode: "Foloo Pro (prueba)" 99 USD/month; env overrides.
    stripePriceId: env.STRIPE_PRICE_ID ?? "price_1UTTLKCp0Un1sf9uyTk4w9NN",
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

export type WebSessionQaConfig = Readonly<{
  enabled: boolean;
  subjectHashes: readonly string[];
}>;

/** Keeps real web-session activation DEV-only and restricted to pseudonymous QA subjects. */
export function webSessionQaConfigForEnvironment(
  environment: string,
  rawEnabled: unknown,
  rawSubjectHashes: unknown,
): WebSessionQaConfig {
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
  return { enabled, subjectHashes };
}
