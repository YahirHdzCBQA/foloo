/** Converts validation/domain/database failures to the public API contract. */

import type { APIGatewayProxyStructuredResultV2 } from "aws-lambda";
import { z } from "zod";

import { ApplicationError } from "../application/errors.js";

type PgLikeError = { code?: unknown };

export function errorResponse(
  error: unknown,
  requestId: string,
  path?: string,
): APIGatewayProxyStructuredResultV2 {
  let statusCode = 500;
  let code = "internal_error";
  let message = "An unexpected error occurred.";

  if (error instanceof z.ZodError) {
    statusCode = 400;
    code = validationCode(error, path);
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

function validationCode(error: z.ZodError, path?: string): string {
  const field = error.issues[0]?.path[0];
  if (path === "/v1/leads") {
    return (
      (
        {
          id: "invalid_lead_id",
          capturedAt: "invalid_captured_at",
          origin: "invalid_origin",
          eventId: "invalid_event_id",
          place: "invalid_place",
          firstName: "invalid_first_name",
          lastName: "invalid_last_name",
          position: "invalid_position",
          company: "invalid_company",
          email: "invalid_email",
          phone: "invalid_phone",
          leadType: "invalid_lead_type",
          interest: "invalid_interest",
          writtenNote: "invalid_written_note",
          commercialFolio: "invalid_commercial_folio",
        } as Record<PropertyKey, string>
      )[field ?? ""] ?? "invalid_lead_payload"
    );
  }
  if (!path?.includes("/media")) return "validation_error";
  return (
    (
      {
        id: "invalid_media_id",
        kind: "invalid_media_type",
        contentType: "invalid_content_type",
        byteSize: "invalid_size",
        capturedAt: "invalid_captured_at",
      } as Record<PropertyKey, string>
    )[field ?? ""] ??
    (field === undefined ? "invalid_lead_id" : "invalid_payload")
  );
}

/** Returns field/category only, never rejected values or request payloads. */
export function safeValidationDiagnostics(
  error: unknown,
): Array<{ field: string; category: string }> | undefined {
  if (!(error instanceof z.ZodError)) return undefined;
  return error.issues.slice(0, 8).map((issue) => ({
    field: issue.path.length === 0 ? "payload" : issue.path.join("."),
    category:
      issue.code === "invalid_format" && "format" in issue
        ? `invalid_${String(issue.format)}`
        : issue.code,
  }));
}
