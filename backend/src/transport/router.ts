/** Routes the protected `/v1` API and produces stable, non-leaking responses. */

import type {
  APIGatewayProxyEventV2WithJWTAuthorizer,
  APIGatewayProxyStructuredResultV2,
} from "aws-lambda";
import { z } from "zod";

import { ApplicationError } from "../application/errors.js";
import { FolooApplication } from "../application/foloo_application.js";
import type { EventUpdateInput, EventDeleteInput } from "../domain/models.js";
import { authenticatedSubject } from "../auth/authenticated_identity.js";
import { requestHash } from "../persistence/postgres_repository.js";
import {
  eventSchema,
  eventUpdateSchema,
  eventDeleteSchema,
  contentSchema,
  contentUpdateSchema,
  contentDeleteSchema,
  leadSchema,
  leadUpdateSchema,
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
    body: JSON.stringify(body, (key, value: unknown) => {
      if (key !== "revision" || typeof value !== "string") return value;
      if (!/^[1-9]\d*$/.test(value)) return value;
      const revision = Number(value);
      if (!Number.isSafeInteger(revision)) {
        throw new ApplicationError(
          "invalid_revision",
          500,
          "Invalid revision.",
        );
      }
      return revision;
    }),
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
    const eventMatch = /^\/v1\/events\/([^/]+)$/.exec(path);
    if (eventMatch?.[1] && (method === "PUT" || method === "DELETE")) {
      const eventId = uuidSchema.parse(eventMatch[1]);
      const payload =
        method === "PUT"
          ? eventUpdateSchema.parse(body(event))
          : eventDeleteSchema.parse(body(event));
      const key = idempotencyKey(event);
      const hash = requestHash({ eventId, ...payload });
      const result =
        method === "PUT"
          ? await application.updateEvent(
              subject,
              eventId,
              payload as EventUpdateInput,
              key,
              hash,
            )
          : await application.deleteEvent(
              subject,
              eventId,
              payload as EventDeleteInput,
              key,
              hash,
            );
      return json(
        200,
        { data: result.value },
        result.replayed ? { "idempotency-replayed": "true" } : {},
      );
    }
    if (method === "GET" && path === "/v1/content")
      return json(200, { data: await application.content(subject) });
    if (method === "POST" && path === "/v1/content") {
      const payload = contentSchema.parse(body(event));
      const result = await application.createContent(
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
    const contentMatch = /^\/v1\/content\/([^/]+)$/.exec(path);
    if (contentMatch?.[1] && (method === "PUT" || method === "DELETE")) {
      const id = uuidSchema.parse(contentMatch[1]);
      const payload =
        method === "PUT"
          ? contentUpdateSchema.parse(body(event))
          : contentDeleteSchema.parse(body(event));
      const key = idempotencyKey(event);
      const hash = requestHash({ id, ...payload });
      const result =
        method === "PUT"
          ? await application.updateContent(
              subject,
              id,
              payload as z.infer<typeof contentUpdateSchema>,
              key,
              hash,
            )
          : await application.deleteContent(
              subject,
              id,
              payload as z.infer<typeof contentDeleteSchema>,
              key,
              hash,
            );
      return json(
        200,
        { data: result.value },
        result.replayed ? { "idempotency-replayed": "true" } : {},
      );
    }
    const contentUploadMatch = /^\/v1\/content\/([^/]+)\/uploads$/.exec(path);
    if (contentUploadMatch?.[1] && method === "POST") {
      return json(201, {
        data: await application.prepareContentUpload(
          subject,
          uuidSchema.parse(contentUploadMatch[1]),
        ),
      });
    }
    const contentConfirmMatch = /^\/v1\/content\/([^/]+)\/confirm$/.exec(path);
    if (contentConfirmMatch?.[1] && method === "POST") {
      const id = uuidSchema.parse(contentConfirmMatch[1]);
      const key = idempotencyKey(event);
      const result = await application.confirmContent(
        subject,
        id,
        key,
        requestHash({ id }),
      );
      return json(
        200,
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

    const leadMatch = /^\/v1\/leads\/([^/]+)$/.exec(path);
    if (leadMatch?.[1] && method === "PUT") {
      const leadId = uuidSchema.parse(leadMatch[1]);
      const payload = leadUpdateSchema.parse(body(event));
      const result = await application.updateLead(
        subject,
        leadId,
        payload,
        idempotencyKey(event),
        requestHash({ leadId, ...payload }),
      );
      return json(
        200,
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

    const mediaUploadMatch = /^\/v1\/leads\/([^/]+)\/media\/uploads$/.exec(
      path,
    );
    if (mediaUploadMatch?.[1] && method === "POST") {
      const leadId = uuidSchema.parse(mediaUploadMatch[1]);
      const payload = mediaSchema.parse(body(event));
      return json(201, {
        data: await application.prepareLeadMediaUpload(
          subject,
          leadId,
          payload,
        ),
      });
    }

    throw new ApplicationError("route_not_found", 404, "Route was not found.");
  };
}
