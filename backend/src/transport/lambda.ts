/** AWS Lambda composition root for the protected Foloo HTTP API. */

import type { APIGatewayProxyHandlerV2WithJWTAuthorizer } from "aws-lambda";

import { FolooApplication } from "../application/foloo_application.js";
import { ApplicationError } from "../application/errors.js";
import { databasePool } from "../persistence/database.js";
import { PostgresFolooRepository } from "../persistence/postgres_repository.js";
import { errorResponse, safeValidationDiagnostics } from "./error_response.js";
import { logEvent } from "./logging.js";
import { createRouter } from "./router.js";
import { S3MediaStorage } from "../storage/media_storage.js";
import { EmailApplication } from "../email/email_application.js";
import { PostgresEmailRepository } from "../email/postgres_email_repository.js";
import { LambdaEmailProviderBoundary } from "../email/provider_invoker.js";
import { loadEnvironment } from "../config/environment.js";
import { DisabledAccountDeletionHttpController } from "../account_deletion/account_deletion_http.js";
import { composeAccountDeletionRuntime } from "../account_deletion/account_deletion_composition.js";
import { createApiClientAccessGuard } from "../auth/api_client_access_guard.js";

import { BillingApplication } from "../billing/billing_application.js";
import { PostgresBillingRepository } from "../billing/postgres_billing_repository.js";
import { LambdaBillingProvider } from "../billing/billing_provider_invoker.js";

let routerPromise: ReturnType<typeof initialize> | undefined;

async function initialize() {
  const pool = await databasePool();
  const bucketName = process.env.MEDIA_BUCKET_NAME;
  if (!bucketName) throw new Error("MEDIA_BUCKET_NAME is required");
  const environment = loadEnvironment();
  const allowedWebSubjectHashes = new Set(
    (process.env.WEB_SESSION_QA_SUBJECT_HASHES ?? "").length === 0
      ? []
      : process.env.WEB_SESSION_QA_SUBJECT_HASHES!.split(","),
  );
  const apiClientAccessGuard = createApiClientAccessGuard({
    issuer: required(process.env.COGNITO_ISSUER, "COGNITO_ISSUER"),
    mobileClientId: required(
      process.env.MOBILE_COGNITO_CLIENT_ID,
      "MOBILE_COGNITO_CLIENT_ID",
    ),
    webClientId: required(
      process.env.WEB_COGNITO_CLIENT_ID,
      "WEB_COGNITO_CLIENT_ID",
    ),
    webSessionsEnabled: process.env.FOLOO_WEB_SESSION_ENABLED === "true",
    allowedWebSubjectHashes,
  });
  const repository = new PostgresFolooRepository(pool, {
    unlimitedQaMode: environment.FOLOO_UNLIMITED_QA_MODE,
  });
  const media = new S3MediaStorage(bucketName);
  const deletion = environment.FOLOO_ACCOUNT_DELETION_ENABLED
    ? composeAccountDeletionRuntime(pool, {
        tableName: required(
          environment.ACCOUNT_DELETION_TABLE_NAME,
          "ACCOUNT_DELETION_TABLE_NAME",
        ),
        hmacKeyArn: required(
          environment.ACCOUNT_DELETION_HMAC_KEY_ARN,
          "ACCOUNT_DELETION_HMAC_KEY_ARN",
        ),
        hmacKeyVersion: required(
          environment.ACCOUNT_DELETION_HMAC_KEY_VERSION,
          "ACCOUNT_DELETION_HMAC_KEY_VERSION",
        ),
        recipientKeyArn: required(
          environment.ACCOUNT_DELETION_RECIPIENT_KEY_ARN,
          "ACCOUNT_DELETION_RECIPIENT_KEY_ARN",
        ),
        queueUrl: required(
          environment.ACCOUNT_DELETION_QUEUE_URL,
          "ACCOUNT_DELETION_QUEUE_URL",
        ),
        notificationFunctionName: required(
          environment.ACCOUNT_DELETION_NOTIFICATION_FUNCTION_NAME,
          "ACCOUNT_DELETION_NOTIFICATION_FUNCTION_NAME",
        ),
        notificationMode: environment.ACCOUNT_DELETION_NOTIFICATION_MODE,
        emailProviderFunctionName: environment.EMAIL_PROVIDER_FUNCTION_NAME,
        cognitoFinalizerFunctionName: required(
          environment.ACCOUNT_DELETION_COGNITO_FINALIZER_FUNCTION_NAME,
          "ACCOUNT_DELETION_COGNITO_FINALIZER_FUNCTION_NAME",
        ),
        verifiedEmailFunctionName: required(
          environment.ACCOUNT_DELETION_VERIFIED_EMAIL_FUNCTION_NAME,
          "ACCOUNT_DELETION_VERIFIED_EMAIL_FUNCTION_NAME",
        ),
        mediaBucketName: environment.MEDIA_BUCKET_NAME,
        maximumAuthenticationAgeMs:
          environment.ACCOUNT_DELETION_REAUTH_MAX_AGE_SECONDS * 1000,
        environment: environment.FOLOO_ENVIRONMENT,
        normalAccessEnabled:
          environment.FOLOO_ACCOUNT_DELETION_NORMAL_ACCESS_ENABLED,
        qaAccessEnabled: environment.FOLOO_ACCOUNT_DELETION_QA_ENABLED,
        intakeEnabled: environment.FOLOO_ACCOUNT_DELETION_INTAKE_ENABLED,
        qaAllowedSubjectHashes: new Set(
          environment.ACCOUNT_DELETION_QA_SUBJECT_HASHES.length === 0
            ? []
            : environment.ACCOUNT_DELETION_QA_SUBJECT_HASHES.split(","),
        ),
      })
    : null;
  const accessGuard = deletion?.accessGuard;
  const email = new EmailApplication(
    repository,
    new PostgresEmailRepository(pool),
    new LambdaEmailProviderBoundary(environment.EMAIL_PROVIDER_FUNCTION_NAME),
    media,
    environment.PUBLIC_API_BASE_URL,
    accessGuard,
  );
  return createRouter(
    new FolooApplication(repository, media),
    email,
    deletion?.controller ?? new DisabledAccountDeletionHttpController(),
    accessGuard,
    apiClientAccessGuard,
    new BillingApplication(
      repository,
      new PostgresBillingRepository(pool),
      new LambdaBillingProvider(environment.BILLING_PROVIDER_FUNCTION_NAME),
      environment,
    ),
  );
}

function required(value: string | undefined, name: string): string {
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

export const handler: APIGatewayProxyHandlerV2WithJWTAuthorizer = async (
  event,
  context,
) => {
  const requestId = event.requestContext.requestId || context.awsRequestId;
  const startedAt = Date.now();
  try {
    routerPromise ??= initialize();
    const router = await routerPromise;
    const response = await router(event);
    logEvent("info", {
      requestId,
      routeKey: event.routeKey,
      statusCode: response.statusCode,
      durationMs: Date.now() - startedAt,
    });
    return response;
  } catch (error) {
    const response = errorResponse(error, requestId, event.rawPath);
    logEvent("error", {
      requestId,
      routeKey: event.routeKey,
      statusCode: response.statusCode,
      errorType: error instanceof Error ? error.name : "UnknownError",
      diagnosticCode:
        error instanceof ApplicationError ? error.diagnosticCode : undefined,
      validationIssues: safeValidationDiagnostics(error),
      durationMs: Date.now() - startedAt,
    });
    return response;
  }
};
