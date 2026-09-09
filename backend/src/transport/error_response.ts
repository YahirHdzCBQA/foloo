/** Converts validation/domain/database failures to the public API contract. */

import type { APIGatewayProxyStructuredResultV2 } from "aws-lambda";
import { z } from "zod";

import { ApplicationError } from "../application/errors.js";

type PgLikeError = { code?: unknown };

export function errorResponse(
  error: unknown,
  requestId: string,
): APIGatewayProxyStructuredResultV2 {
  let statusCode = 500;
  let code = "internal_error";
  let message = "An unexpected error occurred.";

  if (error instanceof z.ZodError) {
    statusCode = 400;
    code = "validation_error";
    message = "Request validation failed.";
  } else if (error instanceof ApplicationError) {
    statusCode = error.statusCode;
    code = error.code;
    message = error.message;
  } else {
    const databaseCode = (error as PgLikeError | null)?.code;
    if (databaseCode === "23505") {
      statusCode = 409;
      code = "resource_conflict";
      message = "The resource already exists.";
    } else if (
      databaseCode === "23503" ||
      databaseCode === "23514" ||
      databaseCode === "22P02"
    ) {
      statusCode = 400;
      code = "invalid_resource";
      message = "The resource violates a data constraint.";
    }
  }

  return {
    statusCode,
    headers: { "content-type": "application/json; charset=utf-8" },
    body: JSON.stringify({ error: { code, message, requestId } }),
  };
}
