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

export type IdempotentResult<T> = { value: T; replayed: boolean };
