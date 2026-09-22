/** Persistence contract for OAuth connections, follow-ups and opt-out state. */

import type { Principal } from "../domain/models.js";
import type {
  EmailConnectionState,
  EmailProviderName,
  EmailSendState,
  HistoricalAttachment,
} from "../domain/email_follow_ups.js";

export type SafeEmailConnection = {
  id: string;
  provider: EmailProviderName;
  senderAddress: string;
  status: EmailConnectionState;
  updatedAt: string;
};

export type OAuthState = {
  principal: Principal;
  provider: EmailProviderName;
  encryptedFlow: string;
  redirectUri: string;
};

export type FollowUpContext = {
  leadId: string;
  eventId: string | null;
  origin: "event" | "direct";
  recipientAddress: string | null;
  values: Record<string, string>;
  contentFileIds: string[];
  contentNames: string[];
  attachments: HistoricalAttachment[];
};

export type StoredSendIntent = {
  id: string;
  workspaceId: string;
  followUpId: string;
  connectionId: string | null;
  provider: EmailProviderName | null;
  senderAddress: string | null;
  recipientAddress: string;
  subject: string;
  plainBody: string;
  htmlBody: string;
  attachedContentIds: string[];
  omittedContentIds: string[];
  status: EmailSendState;
  errorCode: string | null;
  attemptCount: number;
  encryptedCredentials: string | null;
};

export interface EmailRepository {
  connection(principal: Principal): Promise<SafeEmailConnection | null>;
  beginOAuth(
    principal: Principal,
    provider: EmailProviderName,
    stateHash: string,
    encryptedFlow: string,
    redirectUri: string,
  ): Promise<void>;
  consumeOAuthState(stateHash: string): Promise<OAuthState>;
  connect(
    state: OAuthState,
    input: {
      providerSubject: string;
      senderAddress: string;
      encryptedCredentials: string;
    },
  ): Promise<SafeEmailConnection>;
  disconnect(principal: Principal): Promise<void>;
  followUpContext(
    principal: Principal,
    leadId: string,
  ): Promise<FollowUpContext>;
  createFollowUp(
    principal: Principal,
    input: {
      id: string;
      context: FollowUpContext;
      language: "es" | "en";
      subject: string;
      body: string;
      signature: string;
      footer: string;
      plainBody: string;
      htmlBody: string;
      unsubscribeTokenHash: string;
      recipientHash: string;
    },
  ): Promise<unknown>;
  listFollowUps(principal: Principal): Promise<unknown[]>;
  isOptedOut(principal: Principal, recipientHash: string): Promise<boolean>;
  createIntent(
    principal: Principal,
    input: {
      id: string;
      followUpId: string;
      omittedContentIds: string[];
      parentIntentId?: string;
      kind: "initial" | "manual_resend";
    },
  ): Promise<StoredSendIntent>;
  intent(principal: Principal, id: string): Promise<StoredSendIntent>;
  markSending(
    principal: Principal,
    id: string,
    kind: "initial" | "safe_retry" | "manual_resend",
  ): Promise<StoredSendIntent>;
  finishIntent(
    principal: Principal,
    id: string,
    update: {
      status: EmailSendState;
      errorCode?: string;
      providerMessageId?: string;
      encryptedCredentials?: string;
      acceptedSenderAddress?: string;
    },
  ): Promise<StoredSendIntent>;
  intentAttachments(
    principal: Principal,
    intent: StoredSendIntent,
  ): Promise<HistoricalAttachment[]>;
  isUnsubscribeTokenValid(tokenHash: string): Promise<boolean>;
  optOut(tokenHash: string): Promise<boolean>;
}
