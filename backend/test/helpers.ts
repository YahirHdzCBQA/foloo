/** Test doubles for transport/application tests; no real Cognito or AWS calls. */

import type { APIGatewayProxyEventV2WithJWTAuthorizer } from "aws-lambda";

import type { FolooRepository } from "../src/application/ports.js";
import type {
  EventInput,
  EventUpdateInput,
  EventDeleteInput,
  ContentInput,
  ContentUpdateInput,
  ContentDeleteInput,
  ContentRecord,
  IdempotentResult,
  LeadInput,
  LeadUpdateInput,
  LeadMediaInput,
  LeadMediaRecord,
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
  readonly contentByWorkspace = new Map<string, ContentRecord[]>();

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
  async updateEvent(
    principal: Principal,
    eventId: string,
    input: EventUpdateInput,
  ): Promise<IdempotentResult<unknown>> {
    const events = this.eventsByWorkspace.get(principal.workspaceId) ?? [];
    const index = events.findIndex(
      (item) => (item as { id?: string }).id === eventId,
    );
    if (index < 0) throw new Error("Event missing");
    const updated = {
      ...(events[index] as object),
      ...input,
      id: eventId,
      revision: input.revision + 1,
    };
    events[index] = updated;
    return { value: updated, replayed: false };
  }
  async deleteEvent(
    principal: Principal,
    eventId: string,
    input: EventDeleteInput,
  ): Promise<IdempotentResult<unknown>> {
    const events = this.eventsByWorkspace.get(principal.workspaceId) ?? [];
    this.eventsByWorkspace.set(
      principal.workspaceId,
      events.filter((item) => (item as { id?: string }).id !== eventId),
    );
    return {
      value: { id: eventId, revision: input.revision + 1 },
      replayed: false,
    };
  }
  async listContent(principal: Principal): Promise<ContentRecord[]> {
    return this.contentByWorkspace.get(principal.workspaceId) ?? [];
  }
  async createContent(
    principal: Principal,
    input: ContentInput,
  ): Promise<IdempotentResult<unknown>> {
    const rows = this.contentByWorkspace.get(principal.workspaceId) ?? [];
    const row: ContentRecord = {
      ...input,
      revision: 1,
      deletedAt: null,
      uploadStatus: "pending",
      storageObjectKey: null,
    };
    rows.push(row);
    this.contentByWorkspace.set(principal.workspaceId, rows);
    return { value: row, replayed: false };
  }
  async updateContent(
    principal: Principal,
    id: string,
    input: ContentUpdateInput,
  ): Promise<IdempotentResult<unknown>> {
    const row = (this.contentByWorkspace.get(principal.workspaceId) ?? []).find(
      (item) => item.id === id,
    );
    if (!row) throw new Error("Content missing");
    Object.assign(row, input, { revision: input.revision + 1 });
    return { value: row, replayed: false };
  }
  async deleteContent(
    principal: Principal,
    id: string,
    input: ContentDeleteInput,
  ): Promise<IdempotentResult<unknown>> {
    const row = (this.contentByWorkspace.get(principal.workspaceId) ?? []).find(
      (item) => item.id === id,
    );
    if (!row) throw new Error("Content missing");
    row.deletedAt = new Date().toISOString();
    row.revision = input.revision + 1;
    return { value: row, replayed: false };
  }
  async prepareContent(
    principal: Principal,
    id: string,
  ): Promise<ContentRecord> {
    const row = (this.contentByWorkspace.get(principal.workspaceId) ?? []).find(
      (item) => item.id === id && !item.deletedAt,
    );
    if (!row) throw new Error("Content missing");
    return row;
  }
  async confirmContent(
    principal: Principal,
    id: string,
    _key: string,
    _hash: string,
    objectKey: string,
  ): Promise<IdempotentResult<unknown>> {
    const row = await this.prepareContent(principal, id);
    row.uploadStatus = "available";
    row.storageObjectKey = objectKey;
    row.revision += 1;
    return { value: row, replayed: false };
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
  async updateLead(
    _principal: Principal,
    _leadId: string,
    input: LeadUpdateInput,
  ): Promise<IdempotentResult<unknown>> {
    return {
      value: { ...input, revision: input.revision + 1 },
      replayed: false,
    };
  }
  async listLeadMedia(
    principal: Principal,
    leadId: string,
  ): Promise<LeadMediaRecord[]> {
    void principal;
    void leadId;
    return [];
  }
  async prepareLeadMedia(
    principal: Principal,
    leadId: string,
    input: LeadMediaInput,
    objectKey: string,
  ) {
    void principal;
    void leadId;
    void input;
    void objectKey;
  }
  async createLeadMedia(
    _principal: Principal,
    _leadId: string,
    input: LeadMediaInput,
    key: string,
    hash: string,
    objectKey: string,
  ): Promise<IdempotentResult<unknown>> {
    void key;
    void hash;
    void objectKey;
    return { value: input, replayed: false };
  }
}
