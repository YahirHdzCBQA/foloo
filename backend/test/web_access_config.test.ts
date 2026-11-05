/** AUT-18: explicit web admission configuration; no remote effects. */
import test from "node:test";
import assert from "node:assert/strict";
import { webSessionQaConfigForEnvironment } from "../infra/config.js";
test("normal web admission is explicit, DEV-only and cannot combine with QA admission", () => {
  assert.deepEqual(
    webSessionQaConfigForEnvironment("dev", false, undefined, true),
    { enabled: true, subjectHashes: [], normalAccessEnabled: true },
  );
  assert.throws(() =>
    webSessionQaConfigForEnvironment("prod", false, undefined, true),
  );
  assert.throws(() =>
    webSessionQaConfigForEnvironment("dev", false, undefined, "typo"),
  );
  assert.throws(() =>
    webSessionQaConfigForEnvironment("dev", true, "a".repeat(43), true),
  );
});
