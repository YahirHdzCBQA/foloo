/** Test doubles for transport/application tests; no real Cognito or AWS calls. */

import type { APIGatewayProxyEventV2WithJWTAuthorizer } from "aws-lambda";

import type { FolooRepository } from "../src/application/ports.js";
import type {
  EventInput,
  IdempotentResult,
  LeadInput,
  LeadMediaInput,
  Principal,
  SellerProfileInput,
} from "../src/domain/models.js";

export function apiEvent(
  options: {
    method?: string;
    path?: string;
    subject?: string;
    body?: unknown;
    idempotencyKey?: string;
  } = {},
): APIGatewayProxyEventV2WithJWTAuthorizer {
  return {
    version: "2.0",
    routeKey: "$default",
    rawPath: options.path ?? "/v1/workspace",
    rawQueryString: "",
    headers: options.idempotencyKey
      ? { "idempotency-key": options.idempotencyKey }
      : {},
    requestContext: {
      accountId: "test",
      apiId: "test",
      domainName: "test",
      domainPrefix: "test",
      http: {
        method: options.method ?? "GET",
        path: options.path ?? "/v1/workspace",
        protocol: "HTTP/1.1",
        sourceIp: "127.0.0.1",
        userAgent: "test",
      },
      requestId: "request-test",
      routeKey: "$default",
      stage: "$default",
      time: "now",
      timeEpoch: 0,
      authorizer: {
        jwt: {
          claims: options.subject
            ? { sub: options.subject, token_use: "access" }
            : {},
          scopes: [],
        },
        principalId: options.subject ?? "",
        integrationLatency: 0,
      },
    },
    isBase64Encoded: false,
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  };
}

export class MemoryRepository implements FolooRepository {
  readonly seenSubjects: string[] = [];
  readonly eventsByWorkspace = new Map<string, unknown[]>();

  async resolvePrincipal(subject: string): Promise<Principal> {
    this.seenSubjects.push(subject);
    return {
      subject,
      userId: `user-${subject}`,
      accountId: `account-${subject}`,
      workspaceId: `workspace-${subject}`,
    };
  }

  async getWorkspace(principal: Principal) {
    return {
      accountId: principal.accountId,
      workspaceId: principal.workspaceId,
    };
  }
  async getProfile() {
    return null;
  }
  async saveProfile(_principal: Principal, input: SellerProfileInput) {
    return input;
  }
  async listEvents(principal: Principal) {
    return this.eventsByWorkspace.get(principal.workspaceId) ?? [];
  }
  async createEvent(
    principal: Principal,
    input: EventInput,
  ): Promise<IdempotentResult<unknown>> {
    const events = this.eventsByWorkspace.get(principal.workspaceId) ?? [];
    events.push(input);
    this.eventsByWorkspace.set(principal.workspaceId, events);
    return { value: input, replayed: false };
  }
  async listLeads() {
    return [];
  }
  async createLead(
    _principal: Principal,
    input: LeadInput,
  ): Promise<IdempotentResult<unknown>> {
    return { value: input, replayed: false };
  }
  async listLeadMedia() {
    return [];
  }
  async createLeadMedia(
    _principal: Principal,
    _leadId: string,
    input: LeadMediaInput,
  ): Promise<IdempotentResult<unknown>> {
    return { value: input, replayed: false };
  }
}
