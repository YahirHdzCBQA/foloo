/** Core cloud-domain contracts for the FL-014 account/workspace boundary. */

export type Principal = {
  subject: string;
  userId: string;
  accountId: string;
  workspaceId: string;
};

export type SellerProfileInput = {
  name: string;
  company: string;
  position?: string | null;
  phone?: string | null;
  photoUrl?: string | null;
};

export type EventInput = {
  id: string;
  name: string;
  startsAt: string;
  endsAt: string;
};

export type EventUpdateInput = Omit<EventInput, "id"> & { revision: number };
export type EventDeleteInput = { revision: number };

export type ContentInput = {
  id: string;
  displayName: string;
  fileName: string;
  byteSize: number;
  allEvents: boolean;
  eventIds: string[];
};
export type ContentUpdateInput = Pick<
  ContentInput,
  "displayName" | "allEvents" | "eventIds"
> & { revision: number };
export type ContentDeleteInput = { revision: number };
export type ContentRecord = ContentInput & {
  revision: number;
  deletedAt: string | null;
  uploadStatus: "pending" | "available";
  storageObjectKey: string | null;
};

export type LeadInput = {
  id: string;
  capturedAt: string;
  origin: "event" | "direct";
  eventId?: string | null;
  place?: string | null;
  firstName: string;
  lastName?: string | null;
  position?: string | null;
  company: string;
  email?: string | null;
  phone?: string | null;
  leadType: "customer" | "partner" | "supplier";
  interest: "low" | "medium" | "high";
  writtenNote?: string | null;
  commercialFolio?: string | null;
  contentFileIds?: string[];
};

/** Mutable Lead fields plus the expected server revision (REG-07). */
export type LeadUpdateInput = {
  revision: number;
  firstName: string;
  lastName?: string | null;
  position?: string | null;
  company: string;
  email?: string | null;
  phone?: string | null;
  leadType: "customer" | "partner" | "supplier";
  interest: "low" | "medium" | "high";
  writtenNote?: string | null;
  place?: string | null;
  contentFileIds?: string[];
};

export type LeadMediaInput = {
  id: string;
  kind: "business_card" | "reference_image" | "voice_note";
  contentType: string;
  byteSize: number;
  capturedAt: string;
  durationMs?: number | null;
  sha256?: string | null;
};

export type LeadMediaRecord = LeadMediaInput & {
  storageObjectKey: string | null;
  uploadStatus: "pending" | "available";
  uploadedAt: string | null;
  revision: number;
};

export type MediaUploadAuthorization = {
  mediaId: string;
  upload: {
    method: "PUT";
    url: string;
    expiresAt: string;
    headers: Record<string, string>;
  };
};

export type MediaDownloadAuthorization = {
  url: string;
  expiresAt: string;
};

export type IdempotentResult<T> = { value: T; replayed: boolean };
