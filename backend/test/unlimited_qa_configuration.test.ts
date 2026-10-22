/** Verifies the temporary unlimited switch remains explicit and DEV-only. */

import assert from "node:assert/strict";
import test from "node:test";

import { loadEnvironment } from "../src/config/environment.js";
import { unlimitedQaModeForEnvironment } from "../infra/config.js";

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
