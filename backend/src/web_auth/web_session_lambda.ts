/**
 * AWS composition root for the disabled-by-default Foloo web-session BFF.
 * The handler intentionally logs only route/status metadata and never request
 * bodies, cookies, OAuth parameters, Cognito tokens or identity claims.
 */

import { CognitoIdentityProviderClient } from "@aws-sdk/client-cognito-identity-provider";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { KMSClient } from "@aws-sdk/client-kms";
import type {
  APIGatewayProxyEventV2,
  APIGatewayProxyHandlerV2,
} from "aws-lambda";
import { z } from "zod";

import { AwsCognitoWebSessionProvider } from "./cognito_web_session_provider.js";
import { DynamoWebSessionStore } from "./dynamodb_web_session_store.js";
import { KmsWebSessionTokenCipher } from "./kms_web_session_cipher.js";
import { createWebSessionHandler } from "./web_session_http.js";
import { WebSessionService } from "./web_session.js";

const schema = z.object({
  AWS_REGION: z.string().min(1),
  FOLOO_WEB_SESSION_ENABLED: z
    .enum(["true", "false"])
    .default("false")
    .transform((value) => value === "true"),
  WEB_SESSION_QA_SUBJECT_HASHES: z.string().default(""),
  WEB_SESSION_TABLE_NAME: z.string().min(1),
  WEB_SESSION_KEY_ARN: z.string().min(1),
  WEB_SESSION_ABSOLUTE_SECONDS: z.coerce.number().int().positive(),
  WEB_SESSION_IDLE_SECONDS: z.coerce.number().int().positive(),
  WEB_SESSION_REFRESH_SKEW_SECONDS: z.coerce.number().int().positive(),
  WEB_SESSION_OAUTH_TRANSACTION_SECONDS: z.coerce.number().int().positive(),
  WEB_AUTH_ALLOWED_ORIGIN: z.string().url(),
  WEB_AUTH_CALLBACK_URL: z.string().url(),
  WEB_AUTH_SUCCESS_REDIRECT_PATH: z.string().regex(/^\/[A-Za-z0-9/_-]*$/u),
  WEB_COGNITO_CLIENT_ID: z.string().min(1),
  WEB_COGNITO_ISSUER: z.string().url(),
  WEB_COGNITO_DOMAIN: z.string().min(1),
  PUBLIC_API_BASE_URL: z.string().url(),
});

let initialized: ReturnType<typeof createWebSessionHandler> | undefined;

function initialize(): ReturnType<typeof createWebSessionHandler> {
  const environment = schema.parse(process.env);
  const allowedSubjectHashes = new Set(
    environment.WEB_SESSION_QA_SUBJECT_HASHES.length === 0
      ? []
      : environment.WEB_SESSION_QA_SUBJECT_HASHES.split(","),
  );
  if (
    [...allowedSubjectHashes].some(
      (value) => !/^[A-Za-z0-9_-]{43}$/u.test(value),
    ) ||
    (environment.FOLOO_WEB_SESSION_ENABLED && allowedSubjectHashes.size === 0)
  ) {
    throw new Error("Web-session QA access configuration is invalid.");
  }
  const store = new DynamoWebSessionStore(
    new DynamoDBClient({}),
    environment.WEB_SESSION_TABLE_NAME,
  );
  const cipher = new KmsWebSessionTokenCipher(
    new KMSClient({}),
    environment.WEB_SESSION_KEY_ARN,
  );
  const cognito = new AwsCognitoWebSessionProvider(
    new CognitoIdentityProviderClient({}),
    {
      clientId: environment.WEB_COGNITO_CLIENT_ID,
      issuer: environment.WEB_COGNITO_ISSUER,
      domain: environment.WEB_COGNITO_DOMAIN,
      callbackUrl: environment.WEB_AUTH_CALLBACK_URL,
    },
  );
  const sessions = new WebSessionService(
    store,
    cipher,
    cognito,
    {
      absoluteDurationMs: environment.WEB_SESSION_ABSOLUTE_SECONDS * 1000,
      idleDurationMs: environment.WEB_SESSION_IDLE_SECONDS * 1000,
      refreshSkewMs: environment.WEB_SESSION_REFRESH_SKEW_SECONDS * 1000,
      oauthTransactionDurationMs:
        environment.WEB_SESSION_OAUTH_TRANSACTION_SECONDS * 1000,
    },
    undefined,
    { allowedSubjectHashes },
  );
  return createWebSessionHandler(
    { sessions },
    {
      enabled: environment.FOLOO_WEB_SESSION_ENABLED,
      allowedOrigin: environment.WEB_AUTH_ALLOWED_ORIGIN,
      sessionMaxAgeSeconds: environment.WEB_SESSION_ABSOLUTE_SECONDS,
      oauthMaxAgeSeconds: environment.WEB_SESSION_OAUTH_TRANSACTION_SECONDS,
      folooApiBaseUrl: environment.PUBLIC_API_BASE_URL,
      successRedirectPath: environment.WEB_AUTH_SUCCESS_REDIRECT_PATH,
    },
  );
}

export const handler: APIGatewayProxyHandlerV2 = async (
  event: APIGatewayProxyEventV2,
  context,
) => {
  initialized ??= initialize();
  const startedAt = Date.now();
  const response = await initialized(event);
  console.log(
    JSON.stringify({
      level: "info",
      requestId: event.requestContext.requestId || context.awsRequestId,
      routeKey: event.routeKey,
      statusCode: response.statusCode,
      durationMs: Date.now() - startedAt,
    }),
  );
  return response;
};
