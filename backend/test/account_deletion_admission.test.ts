/** AUT-18/AUT-19/RNF-09: no admission is inferred from disabling QA. */
import assert from "node:assert/strict";
import test from "node:test";
import { createAccountDeletionAdmissionGuard } from "../src/account_deletion/account_deletion_admission.js";
import { accountDeletionQaSubjectHash } from "../src/account_deletion/account_deletion_qa_access.js";
import { accountDeletionQaConfigForEnvironment } from "../infra/config.js";
import { composeAccountDeletionRuntime } from "../src/account_deletion/account_deletion_composition.js";
import type { Pool } from "pg";

const base = {
  environment: "dev",
  normalAccessEnabled: false,
  qaEnabled: false,
  qaAllowedSubjectHashes: new Set<string>(),
};
test("AUT-18 QA off does not authorize anyone; runtime can remain constructed", () => {
  const gate = createAccountDeletionAdmissionGuard(base);
  assert.throws(() => gate.assertAllowed("synthetic-owner"), /not enabled/u);
  const runtime = composeAccountDeletionRuntime({} as Pool, {
    tableName: "unused",
    hmacKeyArn: "unused",
    hmacKeyVersion: "v1",
    recipientKeyArn: "unused",
    queueUrl: "https://example.invalid/queue",
    notificationFunctionName: "unused",
    notificationMode: "disabled",
    emailProviderFunctionName: "unused",
    cognitoFinalizerFunctionName: "unused",
    mediaBucketName: "unused",
    maximumAuthenticationAgeMs: 300000,
    environment: "dev",
    qaAccessEnabled: false,
    qaAllowedSubjectHashes: new Set(),
    intakeEnabled: true,
  });
  assert.ok(
    runtime.workflow &&
      runtime.controller &&
      runtime.accessGuard &&
      runtime.executor,
  );
});
test("AUT-18 normal mode requires explicit opt-in and rejects empty identity", () => {
  const gate = createAccountDeletionAdmissionGuard({
    ...base,
    normalAccessEnabled: true,
  });
  gate.assertAllowed("synthetic-owner");
  assert.throws(() => gate.assertAllowed(" "));
  assert.throws(() => gate.assertAllowed("x".repeat(2049)));
});
test("AUT-18 QA mode retains exact subject authorization", () => {
  const gate = createAccountDeletionAdmissionGuard({
    ...base,
    qaEnabled: true,
    qaAllowedSubjectHashes: new Set([
      accountDeletionQaSubjectHash("synthetic-owner"),
    ]),
  });
  gate.assertAllowed("synthetic-owner");
  assert.throws(() => gate.assertAllowed("another-owner"));
});
test("RNF-09 invalid or production admission configuration fails closed", () => {
  for (const config of [
    { ...base, qaEnabled: true },
    {
      ...base,
      qaAllowedSubjectHashes: new Set([
        accountDeletionQaSubjectHash("old-owner"),
      ]),
    },
    { ...base, qaEnabled: true, normalAccessEnabled: true },
    { ...base, environment: "prod", normalAccessEnabled: true },
    { ...base, qaEnabled: true, qaAllowedSubjectHashes: new Set(["invalid"]) },
  ])
    assert.throws(() => createAccountDeletionAdmissionGuard(config));
});
function configuration(
  runtime: unknown,
  normal: unknown,
  qa = false,
  hash = "",
  intake = true,
) {
  return accountDeletionQaConfigForEnvironment(
    "dev",
    qa,
    intake,
    hash,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    runtime,
    normal,
  );
}
test("INF-18 explicit runtime and recovery remain enabled after QA removal", () => {
  const config = configuration(true, false);
  assert.equal(config.enabled, false);
  assert.equal(config.runtimeEnabled, true);
  assert.equal(config.normalAccessEnabled, false);
  assert.deepEqual(config.subjectHashes, []);
  assert.equal(config.workerEnabled, true);
  assert.equal(config.registrationGuardEnabled, true);
  assert.equal(config.intakeEnabled, true);
});
test("AUT-18 explicit normal admission is independent of QA", () => {
  const config = configuration(true, true);
  assert.equal(config.normalAccessEnabled, true);
  assert.equal(config.enabled, false);
});
test("RNF-09 runtime cannot be disabled under active admission or worker", () => {
  assert.throws(() => configuration(false, true));
  assert.throws(() => configuration(false, false));
  assert.throws(() =>
    configuration(
      true,
      true,
      true,
      accountDeletionQaSubjectHash("synthetic-owner"),
    ),
  );
  assert.throws(() =>
    configuration(
      true,
      false,
      false,
      accountDeletionQaSubjectHash("synthetic-owner"),
    ),
  );
  assert.throws(() => configuration("invalid", false));
});
