/** Regression coverage for the fail-closed Cognito trigger boundary. */

import assert from "node:assert/strict";
import test from "node:test";
import type {
  Context,
  PostAuthenticationTriggerEvent,
  PreSignUpTriggerEvent,
} from "aws-lambda";

import { handler as postAuthenticationHandler } from "../src/account_deletion/cognito_post_authentication_lambda.js";
import { handler as preSignUpHandler } from "../src/account_deletion/cognito_pre_signup_lambda.js";
import { validateCognitoGuardTriggerContext } from "../src/account_deletion/cognito_trigger_context.js";

const environment = {
  COGNITO_USER_POOL_ID: "us-east-1_fixture",
  COGNITO_ALLOWED_APP_CLIENT_IDS: "mobile-client,web-client",
  COGNITO_ALLOWED_FEDERATED_PROVIDERS: "Google",
};

function event(overrides: Record<string, unknown> = {}) {
  return {
    userPoolId: "us-east-1_fixture",
    triggerSource: "PostAuthentication_Authentication",
    userName: "synthetic-native-user",
    callerContext: { clientId: "mobile-client" },
    request: { userAttributes: {} },
    ...overrides,
  };
}

test("AUT-18 accepts only the expected pool, app clients and native trigger", () => {
  assert.deepEqual(
    validateCognitoGuardTriggerContext(
      event(),
      "post-authentication",
      environment,
    ),
    { provider: "COGNITO" },
  );
  for (const invalid of [
    event({ userPoolId: "us-east-1_other" }),
    event({ callerContext: { clientId: "other-client" } }),
    event({ callerContext: {} }),
    event({ triggerSource: "PreAuthentication_Authentication" }),
  ]) {
    assert.throws(
      () =>
        validateCognitoGuardTriggerContext(
          invalid,
          "post-authentication",
          environment,
        ),
      /not permitted/u,
    );
  }
});

test("AUT-18 accepts Google and rejects unsupported or ambiguous providers", () => {
  const google = event({
    userName: "Google_fixture",
    request: {
      userAttributes: {
        identities: JSON.stringify([{ providerName: "Google" }]),
      },
    },
  });
  assert.deepEqual(
    validateCognitoGuardTriggerContext(
      google,
      "post-authentication",
      environment,
    ),
    { provider: "Google" },
  );
  for (const identities of [
    [{ providerName: "Microsoft" }],
    [{ providerName: "Google" }, { providerName: "Google" }],
    [{ providerName: "" }],
  ]) {
    assert.throws(
      () =>
        validateCognitoGuardTriggerContext(
          event({
            request: {
              userAttributes: { identities: JSON.stringify(identities) },
            },
          }),
          "post-authentication",
          environment,
        ),
      /not permitted/u,
    );
  }
});

test("AUT-18 validates native and Google PreSignUp trigger sources", () => {
  assert.deepEqual(
    validateCognitoGuardTriggerContext(
      event({ triggerSource: "PreSignUp_SignUp" }),
      "pre-sign-up",
      environment,
    ),
    { provider: "COGNITO" },
  );
  assert.deepEqual(
    validateCognitoGuardTriggerContext(
      event({
        triggerSource: "PreSignUp_ExternalProvider",
        userName: "Google_fixture",
      }),
      "pre-sign-up",
      environment,
    ),
    { provider: "Google" },
  );
  assert.throws(
    () =>
      validateCognitoGuardTriggerContext(
        event({ triggerSource: "PreSignUp_AdminCreateUser" }),
        "pre-sign-up",
        environment,
      ),
    /not permitted/u,
  );
});

test("RNF-09 missing, malformed or duplicate configuration fails closed", () => {
  for (const invalid of [
    {},
    { ...environment, COGNITO_USER_POOL_ID: "" },
    {
      ...environment,
      COGNITO_ALLOWED_APP_CLIENT_IDS: "mobile-client,mobile-client",
    },
    { ...environment, COGNITO_ALLOWED_FEDERATED_PROVIDERS: "" },
  ]) {
    assert.throws(
      () =>
        validateCognitoGuardTriggerContext(
          event(),
          "post-authentication",
          invalid,
        ),
      /configuration is incomplete/u,
    );
  }
});

test("AUT-18 disabled handlers remain pass-through before configuration", async () => {
  const previous =
    process.env.FOLOO_ACCOUNT_DELETION_REGISTRATION_GUARD_ENABLED;
  delete process.env.FOLOO_ACCOUNT_DELETION_REGISTRATION_GUARD_ENABLED;
  try {
    const preSignUp = {
      ...event({ triggerSource: "PreSignUp_SignUp" }),
      version: "1",
      region: "us-east-1",
      callerContext: { awsSdkVersion: "fixture", clientId: "unconfigured" },
      request: { userAttributes: {} },
      response: {
        autoConfirmUser: false,
        autoVerifyEmail: false,
        autoVerifyPhone: false,
      },
    } as PreSignUpTriggerEvent;
    const postAuthentication = {
      ...event(),
      version: "1",
      region: "us-east-1",
      callerContext: { awsSdkVersion: "fixture", clientId: "unconfigured" },
      request: { userAttributes: {}, newDeviceUsed: false },
      response: {},
    } as PostAuthenticationTriggerEvent;
    const context = {} as Context;
    const callback = () => undefined;

    assert.equal(
      await preSignUpHandler(preSignUp, context, callback),
      preSignUp,
    );
    assert.equal(
      await postAuthenticationHandler(postAuthentication, context, callback),
      postAuthentication,
    );
  } finally {
    if (previous === undefined) {
      delete process.env.FOLOO_ACCOUNT_DELETION_REGISTRATION_GUARD_ENABLED;
    } else {
      process.env.FOLOO_ACCOUNT_DELETION_REGISTRATION_GUARD_ENABLED = previous;
    }
  }
});

test("AUT-01/AUT-21 canonicalizes only allowlisted provider capitalization", () => {
  for (const provider of ["google", "Google", "GOOGLE", "gOoGlE"]) {
    const signup = event({
      triggerSource: "PreSignUp_ExternalProvider",
      userName: `${provider}_CaseSensitiveSubject`,
      callerContext: { clientId: "web-client" },
    });
    const original = structuredClone(signup);
    assert.deepEqual(
      validateCognitoGuardTriggerContext(signup, "pre-sign-up", environment),
      { provider: "Google" },
    );
    assert.deepEqual(signup, original);
    for (const kind of ["pre-sign-up", "post-authentication"] as const) {
      assert.deepEqual(
        validateCognitoGuardTriggerContext(
          event({
            triggerSource:
              kind === "pre-sign-up"
                ? "PreSignUp_ExternalProvider"
                : "PostAuthentication_Authentication",
            request: {
              userAttributes: {
                identities: JSON.stringify([{ providerName: provider }]),
              },
            },
          }),
          kind,
          environment,
        ),
        { provider: "Google" },
      );
    }
  }
});

test("RNF-09 provider normalization never broadens identifiers or provenance", () => {
  for (const provider of [
    "Microsoft",
    "microsoft",
    "GoogleOther",
    " Google",
    "Google ",
    "Gοogle",
    "",
    "google.evil",
  ]) {
    for (const attributes of [
      {},
      { identities: JSON.stringify([{ providerName: provider }]) },
    ]) {
      assert.throws(
        () =>
          validateCognitoGuardTriggerContext(
            event({
              triggerSource: "PreSignUp_ExternalProvider",
              userName: `${provider}_fixture`,
              request: { userAttributes: attributes },
            }),
            "pre-sign-up",
            environment,
          ),
        /not permitted/u,
      );
    }
  }
  for (const overrides of [
    { userPoolId: "US-EAST-1_fixture" },
    { callerContext: { clientId: "WEB-CLIENT" } },
  ]) {
    assert.throws(
      () =>
        validateCognitoGuardTriggerContext(
          event({
            triggerSource: "PreSignUp_ExternalProvider",
            userName: "google_fixture",
            ...overrides,
          }),
          "pre-sign-up",
          environment,
        ),
      /not permitted/u,
    );
  }
  assert.throws(
    () =>
      validateCognitoGuardTriggerContext(event(), "post-authentication", {
        ...environment,
        COGNITO_ALLOWED_FEDERATED_PROVIDERS: "Google,google",
      }),
    /configuration is incomplete/u,
  );
  assert.throws(
    () =>
      validateCognitoGuardTriggerContext(
        event({
          triggerSource: "PreSignUp_ExternalProvider",
          userName: "google_fixture",
        }),
        "pre-sign-up",
        {
          ...environment,
          COGNITO_ALLOWED_FEDERATED_PROVIDERS: "OtherProvider",
        },
      ),
    /not permitted/u,
  );
});
