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

let routerPromise: ReturnType<typeof initialize> | undefined;

async function initialize() {
  const pool = await databasePool();
  const bucketName = process.env.MEDIA_BUCKET_NAME;
  if (!bucketName) throw new Error("MEDIA_BUCKET_NAME is required");
  const environment = loadEnvironment();
  const repository = new PostgresFolooRepository(pool);
  const media = new S3MediaStorage(bucketName);
  return createRouter(
    new FolooApplication(repository, media),
    new EmailApplication(
      repository,
      new PostgresEmailRepository(pool),
      new LambdaEmailProviderBoundary(environment.EMAIL_PROVIDER_FUNCTION_NAME),
      media,
      environment.PUBLIC_API_BASE_URL,
    ),
  );
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
