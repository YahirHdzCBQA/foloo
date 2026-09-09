/** Routes the protected `/v1` API and produces stable, non-leaking responses. */

import type {
  APIGatewayProxyEventV2WithJWTAuthorizer,
  APIGatewayProxyStructuredResultV2,
} from "aws-lambda";
import { z } from "zod";

import { ApplicationError } from "../application/errors.js";
import { FolooApplication } from "../application/foloo_application.js";
import { authenticatedSubject } from "../auth/authenticated_identity.js";
import { requestHash } from "../persistence/postgres_repository.js";
import {
  eventSchema,
  leadSchema,
  mediaSchema,
  profileSchema,
} from "./schemas.js";

const idempotencyKeySchema = z.string().min(8).max(128);
const uuidSchema = z.uuid();

function json(
  statusCode: number,
  body: unknown,
  headers: Record<string, string> = {},
): APIGatewayProxyStructuredResultV2 {
  return {
    statusCode,
    headers: { "content-type": "application/json; charset=utf-8", ...headers },
    body: JSON.stringify(body),
  };
}

function body(event: APIGatewayProxyEventV2WithJWTAuthorizer): unknown {
  if (!event.body) return {};
  try {
    const value = event.isBase64Encoded
      ? Buffer.from(event.body, "base64").toString("utf8")
      : event.body;
    return JSON.parse(value) as unknown;
  } catch {
    throw new ApplicationError(
      "invalid_json",
      400,
      "Request body must be valid JSON.",
    );
  }
}

function header(
  event: APIGatewayProxyEventV2WithJWTAuthorizer,
  name: string,
): string | undefined {
  const target = name.toLowerCase();
  return Object.entries(event.headers).find(
    ([key]) => key.toLowerCase() === target,
  )?.[1];
}

function idempotencyKey(
  event: APIGatewayProxyEventV2WithJWTAuthorizer,
): string {
  const parsed = idempotencyKeySchema.safeParse(
    header(event, "idempotency-key"),
  );
  if (!parsed.success)
    throw new ApplicationError(
      "idempotency_key_required",
      400,
      "A valid Idempotency-Key header is required.",
    );
  return parsed.data;
}

export function createRouter(application: FolooApplication) {
  return async (
    event: APIGatewayProxyEventV2WithJWTAuthorizer,
  ): Promise<APIGatewayProxyStructuredResultV2> => {
    const subject = authenticatedSubject(event);
    const method = event.requestContext.http.method.toUpperCase();
    const path = event.rawPath.replace(/\/$/, "");

    if (method === "GET" && path === "/v1/workspace")
      return json(200, { data: await application.workspace(subject) });
    if (method === "GET" && path === "/v1/profile")
      return json(200, { data: await application.profile(subject) });
    if (method === "PUT" && path === "/v1/profile") {
      return json(200, {
        data: await application.saveProfile(
          subject,
          profileSchema.parse(body(event)),
        ),
      });
    }
    if (method === "GET" && path === "/v1/events")
      return json(200, { data: await application.events(subject) });
    if (method === "POST" && path === "/v1/events") {
      const payload = eventSchema.parse(body(event));
      const result = await application.createEvent(
        subject,
        payload,
        idempotencyKey(event),
        requestHash(payload),
      );
      return json(
        201,
        { data: result.value },
        result.replayed ? { "idempotency-replayed": "true" } : {},
      );
    }
    if (method === "GET" && path === "/v1/leads")
      return json(200, { data: await application.leads(subject) });
    if (method === "POST" && path === "/v1/leads") {
      const payload = leadSchema.parse(body(event));
      const result = await application.createLead(
        subject,
        payload,
        idempotencyKey(event),
        requestHash(payload),
      );
      return json(
        201,
        { data: result.value },
        result.replayed ? { "idempotency-replayed": "true" } : {},
      );
    }

    const mediaMatch = /^\/v1\/leads\/([^/]+)\/media$/.exec(path);
    if (mediaMatch?.[1]) {
      const leadId = uuidSchema.parse(mediaMatch[1]);
      if (method === "GET")
        return json(200, {
          data: await application.leadMedia(subject, leadId),
        });
      if (method === "POST") {
        const payload = mediaSchema.parse(body(event));
        const result = await application.createLeadMedia(
          subject,
          leadId,
          payload,
          idempotencyKey(event),
          requestHash({ leadId, ...payload }),
        );
        return json(
          201,
          { data: result.value },
          result.replayed ? { "idempotency-replayed": "true" } : {},
        );
      }
    }

    throw new ApplicationError("route_not_found", 404, "Route was not found.");
  };
}
