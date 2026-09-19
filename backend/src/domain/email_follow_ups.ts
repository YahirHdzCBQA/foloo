/** Email connection and follow-up contracts shared by application adapters.
 *
 * They deliberately contain no OAuth tokens. Provider credentials remain an
 * encrypted backend concern while mobile receives only safe account metadata.
 */

import { randomBytes, createHash } from "node:crypto";

export type EmailProviderName = "google" | "microsoft";
export type EmailConnectionState =
  "connected" | "reconnect_required" | "disconnected";
export type EmailSendState =
  "pending" | "sending" | "sent" | "error" | "confirmation_required";

export const GOOGLE_SCOPES = [
  "openid",
  "email",
  "https://www.googleapis.com/auth/gmail.send",
] as const;

export const MICROSOFT_SCOPES = [
  "openid",
  "email",
  "offline_access",
  "Mail.Send",
] as const;

export const MICROSOFT_SIMPLE_ATTACHMENT_LIMIT = 3_000_000;
export const GMAIL_MESSAGE_LIMIT = 25_000_000;

export function opaqueToken(bytes = 32): string {
  return randomBytes(bytes).toString("base64url");
}

export function tokenHash(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

export function normalizedRecipient(value: string): string {
  return value.trim().toLowerCase();
}

export function maskedAddress(value: string): string {
  const [local, domain] = value.split("@");
  if (!local || !domain) return "***";
  return `${local.slice(0, 2)}***@${domain}`;
}

export type HistoricalAttachment = {
  id: string;
  name: string;
  byteSize: number;
  contentType: "application/pdf";
  available: boolean;
  storageObjectKey: string | null;
};

export type AttachmentDecision = {
  unavailableIds: string[];
  reason: "missing" | "provider_limit";
};

export function classifyProviderHttpStatus(
  status: number,
): "accepted" | "safe_retry" | "reconnect_required" | "rejected" {
  if (status === 401 || status === 403) return "reconnect_required";
  if (status === 429 || status >= 500) return "safe_retry";
  if (status >= 200 && status < 300) return "accepted";
  return "rejected";
}

export function incompatibleAttachments(
  provider: EmailProviderName,
  attachments: HistoricalAttachment[],
): AttachmentDecision[] {
  const missing = attachments
    .filter((item) => !item.available)
    .map((i) => i.id);
  const decisions: AttachmentDecision[] = [];
  if (missing.length)
    decisions.push({ unavailableIds: missing, reason: "missing" });
  if (provider === "microsoft") {
    const tooLarge = attachments
      .filter(
        (item) =>
          item.available && item.byteSize >= MICROSOFT_SIMPLE_ATTACHMENT_LIMIT,
      )
      .map((item) => item.id);
    if (tooLarge.length)
      decisions.push({ unavailableIds: tooLarge, reason: "provider_limit" });
  } else {
    // Base64 and MIME headers add roughly 4/3 plus a small deterministic margin.
    const effectiveSize = attachments.reduce(
      (total, item) => total + Math.ceil(item.byteSize / 3) * 4 + 1024,
      2048,
    );
    if (effectiveSize > GMAIL_MESSAGE_LIMIT)
      decisions.push({
        unavailableIds: attachments
          .filter((item) => item.available)
          .map((i) => i.id),
        reason: "provider_limit",
      });
  }
  return decisions;
}
