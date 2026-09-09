/** Persistence port keeps application rules independent from PostgreSQL. */

import type {
  EventInput,
  IdempotentResult,
  LeadInput,
  LeadMediaInput,
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
  listLeads(principal: Principal): Promise<unknown[]>;
  createLead(
    principal: Principal,
    input: LeadInput,
    idempotencyKey: string,
    requestHash: string,
  ): Promise<IdempotentResult<unknown>>;
  listLeadMedia(principal: Principal, leadId: string): Promise<unknown[]>;
  createLeadMedia(
    principal: Principal,
    leadId: string,
    input: LeadMediaInput,
    idempotencyKey: string,
    requestHash: string,
  ): Promise<IdempotentResult<unknown>>;
}
