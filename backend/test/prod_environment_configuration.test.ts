/** Verifies that PROD infrastructure configuration is explicit and isolated. */
import assert from "node:assert/strict";
import test from "node:test";

import {
  accountDeletionQaConfigForEnvironment,
  accountDeletionSesNotificationsForEnvironment,
  environmentConfig,
  unlimitedQaModeForEnvironment,
  webSessionQaConfigForEnvironment,
} from "../infra/config.js";

const prodEnvironment = {
  FOLOO_PROD_COGNITO_USER_POOL_ID: "us-east-1_ProdFixture1",
  FOLOO_PROD_COGNITO_APP_CLIENT_ID: "abcdefghijklmnopqrstuvwx",
  FOLOO_PROD_COGNITO_DOMAIN:
    "foloo-prod-fixture.auth.us-east-1.amazoncognito.com",
};

test("INF-04 PROD refuses missing or reused DEV identity values", () => {
  assert.throws(() => environmentConfig("prod", {}), /requires explicit/u);
  assert.throws(
    () =>
      environmentConfig("prod", {
        ...prodEnvironment,
        FOLOO_PROD_COGNITO_USER_POOL_ID: "us-east-1_QVm3dWe4O",
      }),
    /must not reuse/u,
  );
});

test("INF-04 PROD is isolated and has no commercial billing configuration", () => {
  const config = environmentConfig("prod", prodEnvironment);
  assert.equal(config.name, "prod");
  assert.equal(config.billingEnabled, false);
  assert.equal(config.stripeSecretName, undefined);
  assert.equal(config.databaseBackupRetentionDays, 15);
  assert.equal(config.databaseDeletionProtection, true);
  assert.equal(config.vpcCidr, "10.43.0.0/16");
  assert.equal(config.sesIdentityName, "foloo.io");
  assert.equal(config.manageSesIdentity, false);
  assert.throws(
    () =>
      environmentConfig("prod", {
        ...prodEnvironment,
        BILLING_ENABLED: "true",
      }),
    /outside the PROD V1 scope/u,
  );
});

test("INF-04 PROD forbids QA bypasses and allows explicit normal boundaries", () => {
  assert.throws(() => unlimitedQaModeForEnvironment("prod", true), /DEV/u);
  assert.deepEqual(
    webSessionQaConfigForEnvironment("prod", false, undefined, true),
    { enabled: true, subjectHashes: [], normalAccessEnabled: true },
  );
  const deletion = accountDeletionQaConfigForEnvironment(
    "prod",
    false,
    true,
    undefined,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
  );
  assert.equal(deletion.normalAccessEnabled, true);
  assert.equal(deletion.enabled, false);
  assert.equal(
    accountDeletionSesNotificationsForEnvironment("prod", true),
    true,
  );
});
