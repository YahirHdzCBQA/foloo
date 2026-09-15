/** Coordinates authenticated use cases without exposing transport or SQL details. */

import type { FolooRepository } from "./ports.js";
import type {
  EventInput,
  LeadInput,
  LeadMediaInput,
  SellerProfileInput,
} from "../domain/models.js";
import type { MediaStorage } from "../storage/media_storage.js";

export class FolooApplication {
  constructor(
    private readonly repository: FolooRepository,
    private readonly mediaStorage?: MediaStorage,
  ) {}

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
