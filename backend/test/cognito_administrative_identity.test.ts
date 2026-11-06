/** Fail-closed identity validation for the private administrative grant tool. */

import assert from "node:assert/strict";
import test from "node:test";

import type { UserType } from "@aws-sdk/client-cognito-identity-provider";

import { verifiedAdministrativeIdentity } from "../src/entitlements/cognito_administrative_identity.js";

function identity(input?: {
  status?: UserType["UserStatus"];
  provider?: string;
  email?: string;
  verified?: string;
  enabled?: boolean;
}): UserType {
  const attributes = [
    { Name: "sub", Value: "subject-synthetic" },
    { Name: "email", Value: input?.email ?? "synthetic@example.test" },
    { Name: "email_verified", Value: input?.verified ?? "true" },
  ];
  if (input?.provider)
    attributes.push({
      Name: "identities",
      Value: JSON.stringify([{ providerName: input.provider }]),
    });
  return {
    Enabled: input?.enabled ?? true,
    UserStatus: input?.status ?? "CONFIRMED",
    Attributes: attributes,
  };
}

test("accepts an exact verified native identity", () => {
  assert.deepEqual(
    verifiedAdministrativeIdentity(identity(), "SYNTHETIC@example.test"),
    { subject: "subject-synthetic", emailVerified: true },
  );
});

test("accepts only approved verified federated parents", () => {
  for (const provider of ["Google", "SignInWithApple"])
    assert.doesNotThrow(() =>
      verifiedAdministrativeIdentity(
        identity({ status: "EXTERNAL_PROVIDER", provider }),
        "synthetic@example.test",
      ),
    );
  for (const provider of ["Microsoft", "Unknown"])
    assert.throws(() =>
      verifiedAdministrativeIdentity(
        identity({ status: "EXTERNAL_PROVIDER", provider }),
        "synthetic@example.test",
      ),
    );
});

test("rejects mismatched, disabled or unverified identities", () => {
  for (const user of [
    identity({ email: "different@example.test" }),
    identity({ verified: "false" }),
    identity({ enabled: false }),
    identity({ status: "EXTERNAL_PROVIDER" }),
  ])
    assert.throws(() =>
      verifiedAdministrativeIdentity(user, "synthetic@example.test"),
    );
});
