/** AWS Lambda composition root for the protected Foloo HTTP API. */

import type { APIGatewayProxyHandlerV2WithJWTAuthorizer } from "aws-lambda";

import { FolooApplication } from "../application/foloo_application.js";
import { databasePool } from "../persistence/database.js";
import { PostgresFolooRepository } from "../persistence/postgres_repository.js";
import { errorResponse } from "./error_response.js";
import { logEvent } from "./logging.js";
import { createRouter } from "./router.js";

let routerPromise: ReturnType<typeof initialize> | undefined;

async function initialize() {
  const pool = await databasePool();
  return createRouter(new FolooApplication(new PostgresFolooRepository(pool)));
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
    const response = errorResponse(error, requestId);
    logEvent("error", {
      requestId,
      routeKey: event.routeKey,
      statusCode: response.statusCode,
      errorType: error instanceof Error ? error.name : "UnknownError",
      durationMs: Date.now() - startedAt,
    });
    return response;
  }
};
