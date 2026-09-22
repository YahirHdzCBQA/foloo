/** Coordinates authenticated use cases without exposing transport or SQL details. */

import type { FolooRepository } from "./ports.js";
import type {
  EventInput,
  EventUpdateInput,
  EventDeleteInput,
  ContentInput,
  ContentUpdateInput,
  ContentDeleteInput,
  LeadInput,
  LeadUpdateInput,
  LeadMediaInput,
  SellerProfileInput,
} from "../domain/models.js";
import type { MediaStorage } from "../storage/media_storage.js";
import {
  validateEmailTemplate,
  validateEventEmailTemplate,
  type EmailTemplate,
  type EventEmailTemplate,
} from "../domain/email_templates.js";

export class FolooApplication {
  constructor(
    private readonly repository: FolooRepository,
    private readonly mediaStorage?: MediaStorage,
  ) {}

  async emailTemplates(subject: string) {
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.listEmailTemplates(principal);
  }

  async eventEmailTemplates(subject: string) {
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.listEventEmailTemplates(principal);
  }

  async saveEventEmailTemplate(
    subject: string,
    template: EventEmailTemplate,
    key: string,
    hash: string,
  ) {
    validateEventEmailTemplate(template);
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.saveEventEmailTemplate(
      principal,
      template,
      key,
      hash,
    );
  }

  async deleteEventEmailTemplate(
    subject: string,
    eventId: string,
    language: "es" | "en",
    key: string,
    hash: string,
  ) {
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.deleteEventEmailTemplate(
      principal,
      eventId,
      language,
      key,
      hash,
    );
  }

  async saveEmailTemplate(
    subject: string,
    template: EmailTemplate,
    key: string,
    hash: string,
  ) {
    validateEmailTemplate(template);
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.saveEmailTemplate(principal, template, key, hash);
  }

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

  async updateEvent(
    subject: string,
    eventId: string,
    input: EventUpdateInput,
    key: string,
    hash: string,
  ) {
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.updateEvent(principal, eventId, input, key, hash);
  }

  async deleteEvent(
    subject: string,
    eventId: string,
    input: EventDeleteInput,
    key: string,
    hash: string,
  ) {
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.deleteEvent(principal, eventId, input, key, hash);
  }

  async content(subject: string) {
    const principal = await this.repository.resolvePrincipal(subject);
    const rows = await this.repository.listContent(principal);
    return Promise.all(
      rows.map(async ({ storageObjectKey, ...row }) => ({
        ...row,
        download:
          row.uploadStatus === "available" &&
          !row.deletedAt &&
          storageObjectKey &&
          this.mediaStorage
            ? await this.mediaStorage.authorizeDownload(storageObjectKey)
            : null,
      })),
    );
  }

  async createContent(
    subject: string,
    input: ContentInput,
    key: string,
    hash: string,
  ) {
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.createContent(principal, input, key, hash);
  }

  async updateContent(
    subject: string,
    id: string,
    input: ContentUpdateInput,
    key: string,
    hash: string,
  ) {
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.updateContent(principal, id, input, key, hash);
  }

  async deleteContent(
    subject: string,
    id: string,
    input: ContentDeleteInput,
    key: string,
    hash: string,
  ) {
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.deleteContent(principal, id, input, key, hash);
  }

  async prepareContentUpload(subject: string, id: string) {
    const storage = this.requiredMediaStorage();
    const principal = await this.repository.resolvePrincipal(subject);
    const content = await this.repository.prepareContent(principal, id);
    return storage.authorizeContentUpload(
      principal,
      id,
      Number(content.byteSize),
    );
  }

  async confirmContent(subject: string, id: string, key: string, hash: string) {
    const storage = this.requiredMediaStorage();
    const principal = await this.repository.resolvePrincipal(subject);
    const content = await this.repository.prepareContent(principal, id);
    const objectKey = storage.contentObjectKey(principal, id);
    await storage.verifyContentUpload(objectKey, id, Number(content.byteSize));
    return this.repository.confirmContent(principal, id, key, hash, objectKey);
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

  async updateLead(
    subject: string,
    leadId: string,
    input: LeadUpdateInput,
    key: string,
    hash: string,
  ) {
    const principal = await this.repository.resolvePrincipal(subject);
    return this.repository.updateLead(principal, leadId, input, key, hash);
  }

  async leadMedia(subject: string, leadId: string) {
    const principal = await this.repository.resolvePrincipal(subject);
    const media = await this.repository.listLeadMedia(principal, leadId);
    return Promise.all(
      media.map(async (item) => {
        const { storageObjectKey, ...publicItem } = item;
        return {
          ...publicItem,
          download:
            item.uploadStatus === "available" &&
            storageObjectKey &&
            this.mediaStorage
              ? await this.mediaStorage.authorizeDownload(storageObjectKey)
              : null,
        };
      }),
    );
  }

  async prepareLeadMediaUpload(
    subject: string,
    leadId: string,
    input: LeadMediaInput,
  ) {
    const storage = this.requiredMediaStorage();
    const principal = await this.repository.resolvePrincipal(subject);
    const objectKey = storage.objectKey(principal, leadId, input.id);
    await this.repository.prepareLeadMedia(principal, leadId, input, objectKey);
    return storage.authorizeUpload(principal, leadId, input);
  }

  async createLeadMedia(
    subject: string,
    leadId: string,
    input: LeadMediaInput,
    key: string,
    hash: string,
  ) {
    const storage = this.requiredMediaStorage();
    const principal = await this.repository.resolvePrincipal(subject);
    const objectKey = storage.objectKey(principal, leadId, input.id);
    await storage.verifyUpload(objectKey, input);
    return this.repository.createLeadMedia(
      principal,
      leadId,
      input,
      key,
      hash,
      objectKey,
    );
  }

  private requiredMediaStorage(): MediaStorage {
    if (!this.mediaStorage) {
      throw new Error("Media storage is not configured.");
    }
    return this.mediaStorage;
  }
}
