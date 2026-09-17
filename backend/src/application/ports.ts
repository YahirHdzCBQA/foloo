/** Persistence port keeps application rules independent from PostgreSQL. */

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
} from "../domain/models.js";

export interface FolooRepository {
  resolvePrincipal(subject: string): Promise<Principal>;
  getWorkspace(principal: Principal): Promise<unknown>;
  getProfile(principal: Principal): Promise<unknown | null>;
  saveProfile(
    principal: Principal,
    input: SellerProfileInput,
  ): Promise<unknown>;
  listEvents(principal: Principal): Promise<unknown[]>;
  createEvent(
    principal: Principal,
    input: EventInput,
    idempotencyKey: string,
    requestHash: string,
  ): Promise<IdempotentResult<unknown>>;
  updateEvent(
    principal: Principal,
    eventId: string,
    input: EventUpdateInput,
    idempotencyKey: string,
    requestHash: string,
  ): Promise<IdempotentResult<unknown>>;
  deleteEvent(
    principal: Principal,
    eventId: string,
    input: EventDeleteInput,
    idempotencyKey: string,
    requestHash: string,
  ): Promise<IdempotentResult<unknown>>;
  listContent(principal: Principal): Promise<ContentRecord[]>;
  createContent(
    principal: Principal,
    input: ContentInput,
    key: string,
    hash: string,
  ): Promise<IdempotentResult<unknown>>;
  updateContent(
    principal: Principal,
    id: string,
    input: ContentUpdateInput,
    key: string,
    hash: string,
  ): Promise<IdempotentResult<unknown>>;
  deleteContent(
    principal: Principal,
    id: string,
    input: ContentDeleteInput,
    key: string,
    hash: string,
  ): Promise<IdempotentResult<unknown>>;
  prepareContent(principal: Principal, id: string): Promise<ContentRecord>;
  confirmContent(
    principal: Principal,
    id: string,
    key: string,
    hash: string,
    objectKey: string,
  ): Promise<IdempotentResult<unknown>>;
  listLeads(principal: Principal): Promise<unknown[]>;
  createLead(
    principal: Principal,
    input: LeadInput,
    idempotencyKey: string,
    requestHash: string,
  ): Promise<IdempotentResult<unknown>>;
  updateLead(
    principal: Principal,
    leadId: string,
    input: LeadUpdateInput,
    idempotencyKey: string,
    requestHash: string,
  ): Promise<IdempotentResult<unknown>>;
  listLeadMedia(
    principal: Principal,
    leadId: string,
  ): Promise<LeadMediaRecord[]>;
  prepareLeadMedia(
    principal: Principal,
    leadId: string,
    input: LeadMediaInput,
    objectKey: string,
  ): Promise<void>;
  createLeadMedia(
    principal: Principal,
    leadId: string,
    input: LeadMediaInput,
    idempotencyKey: string,
    requestHash: string,
    objectKey: string,
  ): Promise<IdempotentResult<unknown>>;
}
