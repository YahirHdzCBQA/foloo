/** AWS CDK entry point for explicitly selected Foloo environments. */

import * as cdk from "aws-cdk-lib";

import {
  environmentConfig,
  managedProductionEnvironmentConfig,
  administrativeEntitlementForEnvironment,
  automaticEntitlementConfigForEnvironment,
  accountDeletionQaConfigForEnvironment,
  accountDeletionSesNotificationsForEnvironment,
  cognitoAppleIdentityProviderConfigForEnvironment,
  cognitoFederatedProviderConfigForEnvironment,
  unlimitedQaModeForEnvironment,
  webSessionQaConfigForEnvironment,
} from "./config.js";
import { FolooBackendStack } from "./foloo_backend_stack.js";
import { FolooIdentityStack } from "./foloo_identity_stack.js";
import { prodIdentityProviderConfig } from "./prod_identity_config.js";

const app = new cdk.App();
const environment = app.node.tryGetContext("environment");
const environmentName = typeof environment === "string" ? environment : "dev";
const stackEnvironment = process.env.CDK_DEFAULT_ACCOUNT
  ? { account: process.env.CDK_DEFAULT_ACCOUNT, region: "us-east-1" }
  : { region: "us-east-1" };
const prodIdentity =
  environmentName === "prod"
    ? new FolooIdentityStack(app, "FolooIdentity-prod", {
        providers: prodIdentityProviderConfig((name) =>
          app.node.tryGetContext(name),
        ),
        env: stackEnvironment,
        terminationProtection: true,
        description: "Foloo PROD retained Cognito, secrets and deletion keys",
      })
    : undefined;
const config = prodIdentity
  ? managedProductionEnvironmentConfig({
      userPoolId: prodIdentity.userPool.userPoolId,
      appClientId: prodIdentity.mobileClient.userPoolClientId,
      cognitoDomain: prodIdentity.cognitoDomain,
    })
  : environmentConfig(environmentName);
const unlimitedQaMode = unlimitedQaModeForEnvironment(
  config.name,
  app.node.tryGetContext("unlimitedQaMode"),
);
const administrativeEntitlementEnabled =
  administrativeEntitlementForEnvironment(
    config.name,
    app.node.tryGetContext("administrativeEntitlementEnabled"),
  );
const automaticEntitlement = automaticEntitlementConfigForEnvironment(
  config.name,
  app.node.tryGetContext("automaticEntitlementEnabled"),
  app.node.tryGetContext("automaticEntitlementEnqueueEnabled"),
  app.node.tryGetContext("automaticEntitlementWorkerEnabled"),
);
const webSessionQa = webSessionQaConfigForEnvironment(
  config.name,
  app.node.tryGetContext("webSessionQaEnabled"),
  app.node.tryGetContext("webSessionQaSubjectHashes"),
  app.node.tryGetContext("webSessionNormalAccessEnabled"),
);
const cognitoFederatedProviders = prodIdentity
  ? {
      allowedProviderNames: [
        ...(app.node.tryGetContext("prodGoogleIdentityProviderEnabled") ===
          true ||
        app.node.tryGetContext("prodGoogleIdentityProviderEnabled") === "true"
          ? (["Google"] as const)
          : []),
        ...(app.node.tryGetContext("prodAppleIdentityProviderEnabled") ===
          true ||
        app.node.tryGetContext("prodAppleIdentityProviderEnabled") === "true"
          ? (["SignInWithApple"] as const)
          : []),
      ],
    }
  : cognitoFederatedProviderConfigForEnvironment(
      config.name,
      app.node.tryGetContext("cognitoAppleSignInEnabled"),
      app.node.tryGetContext("cognitoMicrosoftSignInEnabled"),
    );
const cognitoAppleIdentityProvider = prodIdentity
  ? {
      enabled: false,
      servicesId: "com.foloo.signin" as const,
      teamId: "PU238KF2F9" as const,
      keyId: "6LK763G44F" as const,
    }
  : cognitoAppleIdentityProviderConfigForEnvironment(
      config.name,
      app.node.tryGetContext("cognitoAppleIdentityProviderEnabled"),
      app.node.tryGetContext("cognitoApplePrivateKeySecretArn"),
    );
const accountDeletionQa = accountDeletionQaConfigForEnvironment(
  config.name,
  app.node.tryGetContext("accountDeletionQaEnabled"),
  app.node.tryGetContext("accountDeletionQaIntakeEnabled"),
  app.node.tryGetContext("accountDeletionQaSubjectHashes"),
  app.node.tryGetContext("accountDeletionRegistrationGuardEnabled"),
  app.node.tryGetContext("accountDeletionOutboxRecoveryEnabled"),
  app.node.tryGetContext("accountDeletionRestoreReconcilerEnabled"),
  app.node.tryGetContext("accountDeletionRecoverySchedulerEnabled"),
  app.node.tryGetContext("accountDeletionWorkerEnabled"),
  app.node.tryGetContext("accountDeletionFinalizerEnabled"),
  app.node.tryGetContext("accountDeletionWorkerEventSourceEnabled"),
  app.node.tryGetContext("accountDeletionRuntimeEnabled"),
  app.node.tryGetContext("accountDeletionNormalAccessEnabled"),
);
const accountDeletionSesNotificationsEnabled =
  accountDeletionSesNotificationsForEnvironment(
    config.name,
    app.node.tryGetContext("accountDeletionSesNotificationsEnabled"),
  );
const entitlementPreauthorizationPreviousHmacKeys = (() => {
  const value = app.node.tryGetContext(
    "entitlementPreauthorizationPreviousHmacKeys",
  ) as unknown;
  if (value === undefined) return [];
  if (
    !Array.isArray(value) ||
    value.some(
      (entry) =>
        typeof entry !== "object" ||
        entry === null ||
        typeof (entry as { keyArn?: unknown }).keyArn !== "string" ||
        typeof (entry as { keyVersion?: unknown }).keyVersion !== "string",
    )
  ) {
    throw new Error(
      "entitlementPreauthorizationPreviousHmacKeys must contain keyArn/keyVersion pairs.",
    );
  }
  return value as { keyArn: string; keyVersion: string }[];
})();
const requiredKeyArn = (contextName: string): string => {
  const value = app.node.tryGetContext(contextName);
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(
      `Missing required CDK context ${contextName}; refusing to create another retained Account Deletion KMS key.`,
    );
  }
  return value;
};

const backend = new FolooBackendStack(app, `FolooBackend-${config.name}`, {
  config,
  unlimitedQaMode,
  administrativeEntitlementEnabled,
  automaticEntitlement,
  entitlementPreauthorizationPreviousHmacKeys,
  webSessionQa,
  cognitoAllowedFederatedProviders:
    cognitoFederatedProviders.allowedProviderNames,
  cognitoAppleIdentityProvider,
  accountDeletionQa,
  accountDeletionSesNotificationsEnabled,
  accountDeletionKeyArns: {
    identityHmacKeyArn:
      prodIdentity?.identityHmacKey.keyArn ??
      requiredKeyArn("accountDeletionIdentityHmacKeyArn"),
    notificationRecipientKeyArn:
      prodIdentity?.notificationRecipientKey.keyArn ??
      requiredKeyArn("accountDeletionNotificationRecipientKeyArn"),
  },
  env: stackEnvironment,
  terminationProtection: config.name === "prod",
  description: "FL-014 Foloo backend foundation",
});
if (prodIdentity) {
  backend.addStackDependency(prodIdentity);
  cdk.Tags.of(prodIdentity).add("Environment", "prod");
  cdk.Tags.of(backend).add("Environment", "prod");
}
