/** Verifies the temporary unlimited switch remains explicit and DEV-only. */

import assert from "node:assert/strict";
import test from "node:test";

import { loadEnvironment } from "../src/config/environment.js";
import {
  accountDeletionQaConfigForEnvironment,
  unlimitedQaModeForEnvironment,
  webSessionQaConfigForEnvironment,
} from "../infra/config.js";

const requiredEnvironment = {
  AWS_REGION: "us-east-1",
  DB_SECRET_ARN: "arn:aws:secretsmanager:us-east-1:123456789012:secret:test",
  DB_HOST: "database.internal",
  DB_PORT: "5432",
  DB_NAME: "foloo",
  DB_POOL_MAX: "2",
  MEDIA_BUCKET_NAME: "foloo-dev-media",
  EMAIL_PROVIDER_FUNCTION_NAME: "foloo-email-provider",
  PUBLIC_API_BASE_URL: "https://example.execute-api.us-east-1.amazonaws.com",
};

test("Unlimited QA defaults to disabled", () => {
  const environment = loadEnvironment(requiredEnvironment);
  assert.equal(environment.FOLOO_UNLIMITED_QA_MODE, false);
  assert.equal(environment.FOLOO_ACCOUNT_DELETION_ENABLED, false);
  assert.equal(environment.FOLOO_ACCOUNT_DELETION_INTAKE_ENABLED, false);
  assert.equal(environment.ACCOUNT_DELETION_NOTIFICATION_MODE, "disabled");
});

test("Account Deletion notification mode is explicit and closed to unknown values", () => {
  assert.equal(
    loadEnvironment({
      ...requiredEnvironment,
      ACCOUNT_DELETION_NOTIFICATION_MODE: "ses",
    }).ACCOUNT_DELETION_NOTIFICATION_MODE,
    "ses",
  );
  assert.throws(() =>
    loadEnvironment({
      ...requiredEnvironment,
      ACCOUNT_DELETION_NOTIFICATION_MODE: "smtp",
    }),
  );
});

test("Unlimited QA accepts only an explicit true value", () => {
  assert.equal(
    loadEnvironment({
      ...requiredEnvironment,
      FOLOO_UNLIMITED_QA_MODE: "true",
    }).FOLOO_UNLIMITED_QA_MODE,
    true,
  );
  assert.throws(() =>
    loadEnvironment({
      ...requiredEnvironment,
      FOLOO_UNLIMITED_QA_MODE: "1",
    }),
  );
});

test("Infrastructure refuses Unlimited QA outside DEV", () => {
  assert.equal(unlimitedQaModeForEnvironment("dev", "true"), true);
  assert.equal(unlimitedQaModeForEnvironment("dev", undefined), false);
  assert.throws(
    () => unlimitedQaModeForEnvironment("prod", "true"),
    /restricted to DEV/,
  );
});

test("AUT-18 web-session QA is DEV-only and fail-closed without subjects", () => {
  const hash = "A".repeat(43);
  assert.deepEqual(
    webSessionQaConfigForEnvironment("dev", undefined, undefined),
    {
      enabled: false,
      subjectHashes: [],
    },
  );
  assert.deepEqual(webSessionQaConfigForEnvironment("dev", "true", hash), {
    enabled: true,
    subjectHashes: [hash],
  });
  assert.throws(
    () => webSessionQaConfigForEnvironment("dev", "true", undefined),
    /requires at least one/u,
  );
  assert.throws(
    () => webSessionQaConfigForEnvironment("prod", "true", hash),
    /restricted to DEV/u,
  );
  assert.throws(
    () => webSessionQaConfigForEnvironment("dev", false, "raw-subject"),
    /invalid/u,
  );
});

test("AUT-18 Account Deletion destructive QA requires exactly one DEV identity", () => {
  const hash = "D".repeat(43);
  assert.deepEqual(
    accountDeletionQaConfigForEnvironment(
      "dev",
      undefined,
      undefined,
      undefined,
    ),
    {
      enabled: false,
      intakeEnabled: false,
      registrationGuardEnabled: false,
      outboxRecoveryEnabled: false,
      restoreReconcilerEnabled: false,
      recoverySchedulerEnabled: false,
      workerEnabled: false,
      workerEventSourceEnabled: false,
      finalizerEnabled: false,
      subjectHashes: [],
    },
  );
  assert.deepEqual(
    accountDeletionQaConfigForEnvironment(
      "dev",
      "true",
      "true",
      hash,
      false,
      true,
      true,
      true,
      true,
      true,
      true,
    ),
    {
      enabled: true,
      intakeEnabled: true,
      registrationGuardEnabled: false,
      outboxRecoveryEnabled: true,
      restoreReconcilerEnabled: true,
      recoverySchedulerEnabled: true,
      workerEnabled: true,
      workerEventSourceEnabled: true,
      finalizerEnabled: true,
      subjectHashes: [hash],
    },
  );
  assert.deepEqual(
    accountDeletionQaConfigForEnvironment("dev", "true", "false", hash),
    {
      enabled: true,
      intakeEnabled: false,
      registrationGuardEnabled: false,
      outboxRecoveryEnabled: false,
      restoreReconcilerEnabled: false,
      recoverySchedulerEnabled: false,
      workerEnabled: false,
      workerEventSourceEnabled: false,
      finalizerEnabled: false,
      subjectHashes: [hash],
    },
  );
  assert.throws(
    () =>
      accountDeletionQaConfigForEnvironment("dev", "true", "true", undefined),
    /exactly one/u,
  );
  assert.throws(
    () =>
      accountDeletionQaConfigForEnvironment(
        "dev",
        "true",
        "true",
        `${hash},${"E".repeat(43)}`,
      ),
    /exactly one/u,
  );
  assert.throws(
    () => accountDeletionQaConfigForEnvironment("prod", "true", "true", hash),
    /restricted to DEV/u,
  );
  assert.deepEqual(
    accountDeletionQaConfigForEnvironment("dev", false, false, hash),
    {
      enabled: false,
      intakeEnabled: false,
      registrationGuardEnabled: false,
      outboxRecoveryEnabled: false,
      restoreReconcilerEnabled: false,
      recoverySchedulerEnabled: false,
      workerEnabled: false,
      workerEventSourceEnabled: false,
      finalizerEnabled: false,
      subjectHashes: [hash],
    },
  );
  assert.throws(
    () => accountDeletionQaConfigForEnvironment("dev", false, true, undefined),
    /requires the protected runtime/u,
  );
});

test("AUT-18 Account Deletion activation controls are independent and fail closed", () => {
  const hash = "D".repeat(43);
  const configuration = accountDeletionQaConfigForEnvironment(
    "dev",
    true,
    false,
    hash,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
  );
  assert.deepEqual(configuration, {
    enabled: true,
    intakeEnabled: false,
    registrationGuardEnabled: true,
    outboxRecoveryEnabled: true,
    restoreReconcilerEnabled: true,
    recoverySchedulerEnabled: true,
    workerEnabled: true,
    workerEventSourceEnabled: true,
    finalizerEnabled: true,
    subjectHashes: [hash],
  });

  const registrationGuardOnly = accountDeletionQaConfigForEnvironment(
    "dev",
    false,
    false,
    hash,
    true,
  );
  assert.equal(registrationGuardOnly.enabled, false);
  assert.equal(registrationGuardOnly.registrationGuardEnabled, true);

  const containedWorker = accountDeletionQaConfigForEnvironment(
    "dev",
    true,
    true,
    hash,
    true,
    true,
    true,
    false,
    true,
    true,
    false,
  );
  assert.equal(containedWorker.workerEnabled, true);
  assert.equal(containedWorker.workerEventSourceEnabled, false);
  assert.equal(containedWorker.recoverySchedulerEnabled, false);

  assert.throws(
    () =>
      accountDeletionQaConfigForEnvironment(
        "dev",
        true,
        false,
        hash,
        true,
        false,
        false,
        false,
        false,
        false,
        true,
      ),
    /event source requires worker/u,
  );

  const invalidConfigurations: Array<
    readonly [
      unknown,
      unknown,
      unknown,
      unknown,
      unknown,
      unknown,
      unknown,
      unknown,
      unknown,
    ]
  > = [
    [false, false, hash, false, false, false, false, true, false],
    [true, false, hash, false, false, false, false, false, true],
    [true, false, hash, false, true, false, false, false, false],
    [true, false, hash, false, false, false, true, true, false],
    [true, false, hash, false, false, true, false, false, false],
  ];
  for (const values of invalidConfigurations) {
    assert.throws(() =>
      accountDeletionQaConfigForEnvironment("dev", ...values),
    );
  }
  assert.throws(
    () =>
      accountDeletionQaConfigForEnvironment("dev", "invalid", false, undefined),
    /must be true or false/u,
  );
  assert.throws(
    () =>
      accountDeletionQaConfigForEnvironment(
        "dev",
        true,
        true,
        hash,
        false,
        false,
        true,
        true,
        true,
        true,
      ),
    /intake requires worker, finalizer, and outbox recovery/u,
  );
  assert.throws(
    () =>
      accountDeletionQaConfigForEnvironment(
        "dev",
        true,
        false,
        hash,
        false,
        false,
        false,
        false,
        true,
        false,
      ),
    /worker requires finalizer/u,
  );
  assert.throws(
    () =>
      accountDeletionQaConfigForEnvironment(
        "prod",
        false,
        false,
        undefined,
        true,
      ),
    /restricted to DEV/u,
  );
});
