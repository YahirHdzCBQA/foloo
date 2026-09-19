/** Orchestrates OAuth, immutable follow-ups and conservative provider sends. */

import { randomUUID } from "node:crypto";
import { ApplicationError } from "../application/errors.js";
import type { FolooRepository } from "../application/ports.js";
import {
  appendFixedEmailFooter,
  contentNamesForEmail,
  defaultEmailTemplate,
  renderEmailPreview,
  type EmailLanguage,
} from "../domain/email_templates.js";
import {
  incompatibleAttachments,
  normalizedRecipient,
  opaqueToken,
  tokenHash,
  type EmailProviderName,
} from "../domain/email_follow_ups.js";
import type { MediaStorage } from "../storage/media_storage.js";
import type { EmailProviderBoundary } from "./provider_invoker.js";
import type { EmailRepository } from "./email_repository.js";

export class EmailApplication {
  constructor(
    private readonly core: FolooRepository,
    private readonly repository: EmailRepository,
    private readonly providers: EmailProviderBoundary,
    private readonly media: MediaStorage,
    private readonly publicBaseUrl: string,
  ) {}

  private principal(subject: string) {
    return this.core.resolvePrincipal(subject);
  }

  async connection(subject: string) {
    return this.repository.connection(await this.principal(subject));
  }

  async beginConnection(subject: string, provider: EmailProviderName) {
    const principal = await this.principal(subject);
    const redirectUri = `${this.publicBaseUrl}/v1/email/oauth/callback/${provider}`;
    const result = await this.providers.invoke({
      action: "authorization_url",
      provider,
      redirectUri,
      workspaceId: principal.workspaceId,
    });
    if (!("authorizationUrl" in result))
      throw new Error("Invalid provider response");
    await this.repository.beginOAuth(
      principal,
      provider,
      result.stateHash,
      result.encryptedFlow,
      redirectUri,
    );
    return { authorizationUrl: result.authorizationUrl, expiresInSeconds: 600 };
  }

  async callback(provider: EmailProviderName, code: string, state: string) {
    const stored = await this.repository.consumeOAuthState(tokenHash(state));
    if (stored.provider !== provider)
      throw new ApplicationError(
        "invalid_oauth_state",
        400,
        "Authorization provider does not match.",
      );
    const result = await this.providers.invoke({
      action: "exchange_code",
      provider,
      code,
      encryptedFlow: stored.encryptedFlow,
      redirectUri: stored.redirectUri,
      workspaceId: stored.principal.workspaceId,
    });
    if (!("providerSubject" in result))
      throw new Error("Invalid provider response");
    return this.repository.connect(stored, result);
  }

  async disconnect(subject: string) {
    await this.repository.disconnect(await this.principal(subject));
  }

  async prepare(
    subject: string,
    leadId: string,
    language: EmailLanguage,
    id: string = randomUUID(),
    frozen?: { subject: string; plainBody: string; htmlBody: string },
  ) {
    const principal = await this.principal(subject);
    const context = await this.repository.followUpContext(principal, leadId);
    if (!context.recipientAddress)
      throw new ApplicationError(
        "lead_email_required",
        409,
        "The lead has no email address.",
      );
    const templates = await this.core.listEmailTemplates(principal);
    const template =
      templates.find(
        (item) => item.origin === context.origin && item.language === language,
      ) ?? defaultEmailTemplate(context.origin, language);
    context.values.contenido = contentNamesForEmail(
      context.contentNames,
      language,
    );
    const unsubscribeToken = opaqueToken();
    const unsubscribeUrl = `${this.publicBaseUrl}/v1/email/unsubscribe?token=${encodeURIComponent(unsubscribeToken)}`;
    const rendered = frozen
      ? appendFixedEmailFooter(
          {
            subject: frozen.subject,
            plainText: frozen.plainBody,
            html: frozen.htmlBody,
          },
          language,
          context.origin === "event"
            ? (context.values.evento ?? "")
            : (context.values.lugar ?? ""),
          unsubscribeUrl,
        )
      : renderEmailPreview(template, context.values, unsubscribeUrl);
    const footerStart = rendered.plainText.lastIndexOf("\n\n");
    const value = await this.repository.createFollowUp(principal, {
      id,
      context,
      language,
      subject: template.subject,
      body: template.body,
      signature: template.signature,
      footer: footerStart >= 0 ? rendered.plainText.slice(footerStart + 2) : "",
      plainBody: rendered.plainText,
      htmlBody: rendered.html,
      unsubscribeTokenHash: tokenHash(unsubscribeToken),
      recipientHash: tokenHash(normalizedRecipient(context.recipientAddress)),
    });
    return {
      ...(value as object),
      preview: rendered,
      attachments: context.attachments,
    };
  }

  async list(subject: string) {
    return this.repository.listFollowUps(await this.principal(subject));
  }

  async confirm(
    subject: string,
    followUpId: string,
    options: {
      intentId?: string;
      omittedContentIds?: string[];
      parentIntentId?: string;
      manualResend?: boolean;
    },
  ) {
    const principal = await this.principal(subject);
    const connection = await this.repository.connection(principal);
    if (!connection || connection.status !== "connected")
      throw new ApplicationError(
        "email_connection_required",
        409,
        "Connect or reconnect an email account.",
      );
    const intent = await this.repository.createIntent(principal, {
      id: options.intentId ?? randomUUID(),
      followUpId,
      omittedContentIds: options.omittedContentIds ?? [],
      parentIntentId: options.parentIntentId,
      kind: options.manualResend ? "manual_resend" : "initial",
    });
    if (intent.status === "sending") {
      const ambiguous = await this.repository.finishIntent(
        principal,
        intent.id,
        {
          status: "confirmation_required",
          errorCode: "previous_attempt_outcome_unknown",
        },
      );
      return { intent: ambiguous };
    }
    if (intent.status !== "pending") return { intent };
    const recipientHash = tokenHash(
      normalizedRecipient(intent.recipientAddress),
    );
    if (await this.repository.isOptedOut(principal, recipientHash))
      throw new ApplicationError(
        "recipient_opted_out",
        409,
        "This recipient opted out of follow-up email.",
      );
    const attachments = await this.repository.intentAttachments(
      principal,
      intent,
    );
    const decisions = incompatibleAttachments(connection.provider, attachments);
    const remotelyUnavailable: string[] = [];
    for (const attachment of attachments) {
      if (!attachment.available || !attachment.storageObjectKey) continue;
      try {
        await this.media.verifyContentUpload(
          attachment.storageObjectKey,
          attachment.id,
          attachment.byteSize,
        );
      } catch (error) {
        if (error instanceof ApplicationError && error.statusCode === 409) {
          remotelyUnavailable.push(attachment.id);
          continue;
        }
        throw error;
      }
    }
    const unresolved = decisions
      .flatMap((decision) => decision.unavailableIds)
      .concat(remotelyUnavailable)
      .filter((id) => !intent.omittedContentIds.includes(id));
    if (unresolved.length)
      return {
        intent,
        requiresAttachmentDecision: true,
        incompatibleAttachmentIds: [...new Set(unresolved)],
      };
    return {
      intent: await this.send(
        principal,
        intent.id,
        options.manualResend ? "manual_resend" : "initial",
      ),
    };
  }

  async retry(subject: string, intentId: string) {
    const principal = await this.principal(subject);
    const intent = await this.repository.intent(principal, intentId);
    if (intent.status === "confirmation_required")
      throw new ApplicationError(
        "ambiguous_send",
        409,
        "The previous email may have been sent. Use manual resend.",
      );
    if (intent.status !== "error")
      throw new ApplicationError(
        "email_retry_not_allowed",
        409,
        "This email cannot be retried.",
      );
    return this.send(principal, intentId, "safe_retry");
  }

  async cancel(subject: string, intentId: string) {
    const principal = await this.principal(subject);
    const intent = await this.repository.intent(principal, intentId);
    if (intent.status !== "pending")
      throw new ApplicationError(
        "email_cancel_not_allowed",
        409,
        "Only a pending email can be cancelled.",
      );
    return this.repository.finishIntent(principal, intentId, {
      status: "error",
      errorCode: "cancelled_by_seller",
    });
  }

  private async send(
    principal: Awaited<ReturnType<FolooRepository["resolvePrincipal"]>>,
    intentId: string,
    kind: "initial" | "safe_retry" | "manual_resend",
  ) {
    let intent = await this.repository.intent(principal, intentId);
    const connection = await this.repository.connection(principal);
    if (!connection || connection.status !== "connected")
      throw new ApplicationError(
        "email_reconnect_required",
        409,
        "Reconnect the email account before sending.",
      );
    if (
      intent.connectionId !== connection.id ||
      intent.senderAddress !== connection.senderAddress
    )
      throw new ApplicationError(
        "sender_confirmation_required",
        409,
        "The connected sender changed. Confirm a new manual resend.",
      );
    if (
      !intent.provider ||
      !intent.encryptedCredentials ||
      !intent.senderAddress
    )
      throw new ApplicationError(
        "email_connection_required",
        409,
        "Email connection is incomplete.",
      );
    const attachments = await this.repository.intentAttachments(
      principal,
      intent,
    );
    const commands = await Promise.all(
      attachments.map(async (item) => {
        if (!item.available || !item.storageObjectKey)
          throw new ApplicationError(
            "attachment_unavailable",
            409,
            `${item.name} is unavailable.`,
          );
        const download = await this.media.authorizeDownload(
          item.storageObjectKey,
        );
        return {
          id: item.id,
          name: item.name,
          contentType: item.contentType,
          byteSize: item.byteSize,
          downloadUrl: download.url,
        };
      }),
    );
    intent = await this.repository.markSending(principal, intentId, kind);
    const result = await this.providers.invoke({
      action: "send",
      provider: intent.provider!,
      encryptedCredentials: intent.encryptedCredentials!,
      workspaceId: principal.workspaceId,
      senderAddress: intent.senderAddress!,
      recipientAddress: intent.recipientAddress,
      subject: intent.subject,
      plainBody: intent.plainBody,
      htmlBody: intent.htmlBody,
      attachments: commands,
    });
    if (!("outcome" in result)) throw new Error("Invalid provider response");
    const status =
      result.outcome === "accepted"
        ? "sent"
        : result.outcome === "ambiguous"
          ? "confirmation_required"
          : "error";
    return this.repository.finishIntent(principal, intentId, {
      status,
      errorCode: result.errorCode,
      providerMessageId: result.providerMessageId,
      encryptedCredentials: result.encryptedCredentials,
      acceptedSenderAddress:
        result.outcome === "accepted" ? intent.senderAddress! : undefined,
    });
  }

  async unsubscribe(token: string) {
    if (token.length < 32) return false;
    return this.repository.optOut(tokenHash(token));
  }
}
