/** AWS CDK entry point for explicitly selected Foloo environments. */

import * as cdk from "aws-cdk-lib";

import {
  environmentConfig,
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

const app = new cdk.App();
const environment = app.node.tryGetContext("environment");
const config = environmentConfig(
  typeof environment === "string" ? environment : "dev",
);
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
const cognitoFederatedProviders = cognitoFederatedProviderConfigForEnvironment(
  config.name,
  app.node.tryGetContext("cognitoAppleSignInEnabled"),
  app.node.tryGetContext("cognitoMicrosoftSignInEnabled"),
);
const cognitoAppleIdentityProvider =
  cognitoAppleIdentityProviderConfigForEnvironment(
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

new FolooBackendStack(app, `FolooBackend-${config.name}`, {
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
    identityHmacKeyArn: requiredKeyArn("accountDeletionIdentityHmacKeyArn"),
    notificationRecipientKeyArn: requiredKeyArn(
      "accountDeletionNotificationRecipientKeyArn",
    ),
  },
  env: process.env.CDK_DEFAULT_ACCOUNT
    ? { account: process.env.CDK_DEFAULT_ACCOUNT, region: config.region }
    : { region: config.region },
  description: "FL-014 Foloo backend foundation",
});
