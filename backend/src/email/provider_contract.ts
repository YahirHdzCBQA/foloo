/** Internal Lambda contract for public OAuth/provider calls.
 *
 * Only the VPC API Lambda may invoke this boundary. Tokens cross the boundary
 * solely as KMS ciphertext and are never returned to Flutter (SAL-04/SAL-08).
 */

import type { EmailProviderName } from "../domain/email_follow_ups.js";

export type ProviderAttachment = {
  id: string;
  name: string;
  contentType: "application/pdf";
  byteSize: number;
  downloadUrl: string;
};

export type ProviderCommand =
  | {
      action: "authorization_url";
      provider: EmailProviderName;
      redirectUri: string;
      workspaceId: string;
    }
  | {
      action: "exchange_code";
      provider: EmailProviderName;
      code: string;
      encryptedFlow: string;
      redirectUri: string;
      workspaceId: string;
    }
  | {
      action: "send";
      provider: EmailProviderName;
      encryptedCredentials: string;
      workspaceId: string;
      senderAddress: string;
      recipientAddress: string;
      subject: string;
      plainBody: string;
      htmlBody: string;
      attachments: ProviderAttachment[];
    };

export type ProviderResult =
  | { authorizationUrl: string; stateHash: string; encryptedFlow: string }
  | {
      providerSubject: string;
      senderAddress: string;
      encryptedCredentials: string;
    }
  | {
      outcome: "accepted" | "safe_retry" | "reconnect_required" | "ambiguous";
      providerMessageId?: string;
      encryptedCredentials?: string;
      errorCode?: string;
    };
