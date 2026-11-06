/** Static security contract for the private administrative entitlement script. */

import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("operator identity and database credentials come from authenticated AWS boundaries", async () => {
  const [source, router] = await Promise.all([
    readFile(
      new URL("../scripts/admin-entitlement.ts", import.meta.url),
      "utf8",
    ),
    readFile(new URL("../src/transport/router.ts", import.meta.url), "utf8"),
  ]);
  assert.match(source, /GetCallerIdentityCommand/);
  assert.match(source, /GetSecretValueCommand/);
  assert.match(source, /DB_ENTITLEMENT_OPERATOR_SECRET_ARN/);
  assert.match(source, /foloo_entitlement_operator/);
  assert.doesNotMatch(
    source,
    /DB_ADMIN_SECRET_ARN|FOLOO_ADMIN_ACTOR|DATABASE_URL/,
  );
  assert.doesNotMatch(
    source,
    /console\.(?:info|log).*email|console\.(?:info|log).*subject/,
  );
  assert.doesNotMatch(
    router,
    /AdministrativeEntitlementService|entitlement_grants|entitlement:admin/,
  );
});
