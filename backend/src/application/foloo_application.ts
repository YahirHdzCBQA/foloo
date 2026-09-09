/** Coordinates authenticated use cases without exposing transport or SQL details. */

import type { FolooRepository } from "./ports.js";
import type {
  EventInput,
  LeadInput,
  LeadMediaInput,
  SellerProfileInput,
} from "../domain/models.js";

export class FolooApplication {
  constructor(private readonly repository: FolooRepository) {}

  async workspace(subject: string) {
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.getWorkspace(principal);
  }

  async profile(subject: string) {
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.getProfile(principal);
  }

  async saveProfile(subject: string, input: SellerProfileInput) {
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.saveProfile(principal, input);
  }

  async events(subject: string) {
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.listEvents(principal);
  }

  async createEvent(
    subject: string,
    input: EventInput,
    key: string,
    hash: string,
  ) {
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.createEvent(principal, input, key, hash);
  }

  async leads(subject: string) {
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.listLeads(principal);
  }

  async createLead(
    subject: string,
    input: LeadInput,
    key: string,
    hash: string,
  ) {
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.createLead(principal, input, key, hash);
  }

  async leadMedia(subject: string, leadId: string) {
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.listLeadMedia(principal, leadId);
  }

  async createLeadMedia(
    subject: string,
    leadId: string,
    input: LeadMediaInput,
    key: string,
    hash: string,
  ) {
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.createLeadMedia(principal, leadId, input, key, hash);
  }
}
