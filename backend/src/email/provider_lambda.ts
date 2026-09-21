/** Public-egress-only Lambda for Google OAuth/Gmail and Microsoft OAuth/Graph.
 *
 * This function has no VPC/database access. It obtains app credentials from
 * Secrets Manager and decrypts renewable tokens only for the scoped command.
 */

import { DecryptCommand, EncryptCommand, KMSClient } from "@aws-sdk/client-kms";
import { randomUUID, webcrypto } from "node:crypto";
import {
  GetSecretValueCommand,
  SecretsManagerClient,
} from "@aws-sdk/client-secrets-manager";
import {
  GOOGLE_SCOPES,
  MICROSOFT_SCOPES,
  classifyProviderHttpStatus,
  opaqueToken,
  tokenHash,
  type EmailProviderName,
} from "../domain/email_follow_ups.js";
import type {
  ProviderAttachment,
  ProviderCommand,
  ProviderResult,
} from "./provider_contract.js";

type ProviderSecrets = {
  googleClientId: string;
  googleClientSecret: string;
  microsoftClientId: string;
  microsoftClientSecret: string;
  microsoftTenant: string;
};
type Credentials = {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
  providerSubject: string;
  senderAddress: string;
};

const kms = new KMSClient({});
const secrets = new SecretsManagerClient({});
let cachedSecrets: ProviderSecrets | undefined;

async function configuration(): Promise<ProviderSecrets> {
  if (cachedSecrets) return cachedSecrets;
  const arn = process.env.EMAIL_PROVIDER_SECRET_ARN;
  if (!arn) throw new Error("EMAIL_PROVIDER_SECRET_ARN is required");
  const value = await secrets.send(
    new GetSecretValueCommand({ SecretId: arn }),
  );
  if (!value.SecretString) throw new Error("Email provider secret is empty");
  const parsed = JSON.parse(value.SecretString) as Partial<ProviderSecrets>;
  if (
    !parsed.googleClientId ||
    !parsed.googleClientSecret ||
    !parsed.microsoftClientId ||
    !parsed.microsoftClientSecret ||
    !parsed.microsoftTenant
  )
    throw new Error("email_provider_configuration_invalid");
  cachedSecrets = parsed as ProviderSecrets;
  return cachedSecrets;
}

function endpoints(provider: EmailProviderName, config: ProviderSecrets) {
  if (provider === "google")
    return {
      authorize: "https://accounts.google.com/o/oauth2/v2/auth",
      token: "https://oauth2.googleapis.com/token",
      userinfo: "https://openidconnect.googleapis.com/v1/userinfo",
      clientId: config.googleClientId,
      clientSecret: config.googleClientSecret,
      scopes: GOOGLE_SCOPES,
    };
  const tenant = config.microsoftTenant;
  return {
    authorize: `https://login.microsoftonline.com/${tenant}/oauth2/v2.0/authorize`,
    token: `https://login.microsoftonline.com/${tenant}/oauth2/v2.0/token`,
    userinfo: "https://graph.microsoft.com/oidc/userinfo",
    clientId: config.microsoftClientId,
    clientSecret: config.microsoftClientSecret,
    scopes: MICROSOFT_SCOPES,
  };
}

async function encryptValue(value: unknown, workspaceId: string) {
  const keyId = process.env.EMAIL_TOKEN_KEY_ARN;
  if (!keyId) throw new Error("EMAIL_TOKEN_KEY_ARN is required");
  const result = await kms.send(
    new EncryptCommand({
      KeyId: keyId,
      Plaintext: Buffer.from(JSON.stringify(value)),
      EncryptionContext: { workspaceId, purpose: "foloo-email-oauth" },
    }),
  );
  if (!result.CiphertextBlob) throw new Error("KMS returned no ciphertext");
  return Buffer.from(result.CiphertextBlob).toString("base64");
}

async function decryptValue<T>(value: string, workspaceId: string): Promise<T> {
  const result = await kms.send(
    new DecryptCommand({
      CiphertextBlob: Buffer.from(value, "base64"),
      EncryptionContext: { workspaceId, purpose: "foloo-email-oauth" },
    }),
  );
  if (!result.Plaintext) throw new Error("KMS returned no plaintext");
  return JSON.parse(Buffer.from(result.Plaintext).toString("utf8")) as T;
}

async function tokenRequest(
  provider: EmailProviderName,
  params: Record<string, string>,
) {
  const target = endpoints(provider, await configuration());
  const response = await fetch(target.token, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: target.clientId,
      ...(target.clientSecret ? { client_secret: target.clientSecret } : {}),
      ...params,
    }),
  });
  if (!response.ok) throw new Error(`oauth_token_${response.status}`);
  return (await response.json()) as {
    access_token: string;
    refresh_token?: string;
    expires_in: number;
  };
}

async function exchange(
  command: Extract<ProviderCommand, { action: "exchange_code" }>,
) {
  const target = endpoints(command.provider, await configuration());
  const flow = await decryptValue<{
    codeVerifier: string;
  }>(command.encryptedFlow, command.workspaceId);
  const token = await tokenRequest(command.provider, {
    grant_type: "authorization_code",
    code: command.code,
    redirect_uri: command.redirectUri,
    code_verifier: flow.codeVerifier,
  });
  if (!token.refresh_token) throw new Error("oauth_refresh_token_missing");
  const identityResponse = await fetch(target.userinfo, {
    headers: { authorization: `Bearer ${token.access_token}` },
  });
  if (!identityResponse.ok) throw new Error("oauth_identity_unavailable");
  const identity = (await identityResponse.json()) as {
    sub?: string;
    email?: string;
    mail?: string;
    userPrincipalName?: string;
    preferred_username?: string;
  };
  const senderAddress =
    identity.email ??
    identity.mail ??
    identity.userPrincipalName ??
    identity.preferred_username;
  if (!identity.sub || !senderAddress)
    throw new Error("oauth_identity_incomplete");
  const credentials: Credentials = {
    accessToken: token.access_token,
    refreshToken: token.refresh_token,
    expiresAt: Date.now() + token.expires_in * 1000,
    providerSubject: identity.sub,
    senderAddress,
  };
  return {
    providerSubject: identity.sub,
    senderAddress,
    encryptedCredentials: await encryptValue(credentials, command.workspaceId),
  };
}

async function validCredentials(
  provider: EmailProviderName,
  encrypted: string,
  workspaceId: string,
) {
  const current = await decryptValue<Credentials>(encrypted, workspaceId);
  if (current.expiresAt > Date.now() + 60_000)
    return { credentials: current, encryptedCredentials: encrypted };
  try {
    const target = endpoints(provider, await configuration());
    const token = await tokenRequest(provider, {
      grant_type: "refresh_token",
      refresh_token: current.refreshToken,
      scope: target.scopes.join(" "),
    });
    const refreshed = {
      ...current,
      accessToken: token.access_token,
      refreshToken: token.refresh_token ?? current.refreshToken,
      expiresAt: Date.now() + token.expires_in * 1000,
    };
    return {
      credentials: refreshed,
      encryptedCredentials: await encryptValue(refreshed, workspaceId),
    };
  } catch {
    return null;
  }
}

async function loadAttachments(items: ProviderAttachment[]) {
  return Promise.all(
    items.map(async (item) => {
      const response = await fetch(item.downloadUrl);
      if (!response.ok) throw new Error(`attachment_${item.id}_unavailable`);
      const bytes = Buffer.from(await response.arrayBuffer());
      if (bytes.byteLength !== item.byteSize)
        throw new Error(`attachment_${item.id}_changed`);
      return { ...item, bytes };
    }),
  );
}

function mime(
  command: Extract<ProviderCommand, { action: "send" }>,
  attachments: Awaited<ReturnType<typeof loadAttachments>>,
) {
  const boundary = `foloo_${randomUUID()}`;
  const lines = [
    `From: ${command.senderAddress}`,
    `To: ${command.recipientAddress}`,
    `Subject: =?UTF-8?B?${Buffer.from(command.subject).toString("base64")}?=`,
    "MIME-Version: 1.0",
    `Content-Type: multipart/mixed; boundary=${boundary}`,
    "",
    `--${boundary}`,
    "Content-Type: multipart/alternative; boundary=foloo_body",
    "",
    "--foloo_body",
    "Content-Type: text/plain; charset=UTF-8",
    "Content-Transfer-Encoding: base64",
    "",
    Buffer.from(command.plainBody).toString("base64"),
    "--foloo_body",
    "Content-Type: text/html; charset=UTF-8",
    "Content-Transfer-Encoding: base64",
    "",
    Buffer.from(command.htmlBody).toString("base64"),
    "--foloo_body--",
  ];
  for (const item of attachments)
    lines.push(
      `--${boundary}`,
      `Content-Type: ${item.contentType}; name="${item.name.replaceAll('"', "")}"`,
      "Content-Transfer-Encoding: base64",
      `Content-Disposition: attachment; filename="${item.name.replaceAll('"', "")}"`,
      "",
      item.bytes.toString("base64"),
    );
  lines.push(`--${boundary}--`);
  return lines.join("\r\n");
}

async function send(
  command: Extract<ProviderCommand, { action: "send" }>,
): Promise<ProviderResult> {
  const current = await validCredentials(
    command.provider,
    command.encryptedCredentials,
    command.workspaceId,
  );
  if (!current)
    return { outcome: "reconnect_required", errorCode: "oauth_revoked" };
  const attachments = await loadAttachments(command.attachments);
  const request =
    command.provider === "google"
      ? {
          url: "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
          body: JSON.stringify({
            raw: Buffer.from(mime(command, attachments)).toString("base64url"),
          }),
        }
      : {
          url: "https://graph.microsoft.com/v1.0/me/sendMail",
          body: JSON.stringify({
            message: {
              subject: command.subject,
              body: { contentType: "HTML", content: command.htmlBody },
              toRecipients: [
                { emailAddress: { address: command.recipientAddress } },
              ],
              attachments: attachments.map((item) => ({
                "@odata.type": "#microsoft.graph.fileAttachment",
                name: item.name,
                contentType: item.contentType,
                contentBytes: item.bytes.toString("base64"),
              })),
            },
            saveToSentItems: true,
          }),
        };
  let dispatched = false;
  try {
    dispatched = true;
    const response = await fetch(request.url, {
      method: "POST",
      headers: {
        authorization: `Bearer ${current.credentials.accessToken}`,
        "content-type": "application/json",
      },
      body: request.body,
      signal: AbortSignal.timeout(25_000),
    });
    const classification = classifyProviderHttpStatus(response.status);
    if (classification === "reconnect_required")
      return { outcome: "reconnect_required", errorCode: "oauth_revoked" };
    if (classification === "safe_retry")
      return {
        outcome: "safe_retry",
        errorCode: `provider_${response.status}`,
        encryptedCredentials: current.encryptedCredentials,
      };
    if (classification === "rejected")
      return {
        outcome: "safe_retry",
        errorCode: `provider_${response.status}`,
        encryptedCredentials: current.encryptedCredentials,
      };
    const payload = await acceptedProviderPayload(response);
    return {
      outcome: "accepted",
      providerMessageId: payload.id,
      encryptedCredentials: current.encryptedCredentials,
    };
  } catch {
    return {
      outcome: dispatched ? "ambiguous" : "safe_retry",
      errorCode: dispatched ? "provider_response_lost" : "provider_not_called",
      encryptedCredentials: current.encryptedCredentials,
    };
  }
}

/** Graph sendMail succeeds with HTTP 202 and intentionally has no body. */
export async function acceptedProviderPayload(
  response: Pick<Response, "status" | "text">,
): Promise<{ id?: string }> {
  if (response.status === 202 || response.status === 204) return {};
  const body = await response.text();
  return body.trim().length === 0 ? {} : (JSON.parse(body) as { id?: string });
}

export async function handler(command: ProviderCommand) {
  try {
    let result: ProviderResult;
    if (command.action === "authorization_url") {
      const target = endpoints(command.provider, await configuration());
      const state = opaqueToken();
      const codeVerifier = opaqueToken(48);
      const codeChallenge = Buffer.from(
        await webcrypto.subtle.digest("SHA-256", Buffer.from(codeVerifier)),
      ).toString("base64url");
      const url = new URL(target.authorize);
      url.search = new URLSearchParams({
        client_id: target.clientId,
        redirect_uri: command.redirectUri,
        response_type: "code",
        scope: target.scopes.join(" "),
        state,
        code_challenge: codeChallenge,
        code_challenge_method: "S256",
        access_type: "offline",
        prompt: "consent",
      }).toString();
      result = {
        authorizationUrl: url.toString(),
        stateHash: tokenHash(state),
        encryptedFlow: await encryptValue(
          { codeVerifier },
          command.workspaceId,
        ),
      };
    } else if (command.action === "exchange_code")
      result = await exchange(command);
    else result = await send(command);
    console.info(
      JSON.stringify({
        scope: "email_provider",
        provider: command.provider,
        action: command.action,
        outcome: "outcome" in result ? result.outcome : "completed",
      }),
    );
    return { ok: true, result };
  } catch (error) {
    console.error(
      JSON.stringify({
        scope: "email_provider",
        provider: command.provider,
        action: command.action,
        outcome: "failed",
        errorType: error instanceof Error ? error.name : "UnknownError",
      }),
    );
    return {
      ok: false,
      errorCode: error instanceof Error ? error.message : "provider_error",
    };
  }
}
