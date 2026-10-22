/**
 * Exchanges and refreshes Cognito web tokens without accepting identity claims
 * from the browser. Token payloads are checked against the configured issuer
 * and public client before the session boundary consumes them.
 */

import {
  GetUserCommand,
  GetTokensFromRefreshTokenCommand,
  RevokeTokenCommand,
  type CognitoIdentityProviderClient,
} from "@aws-sdk/client-cognito-identity-provider";

import type {
  CognitoTokenSet,
  CognitoWebSessionProvider,
  WebSessionIdentity,
} from "./web_session.js";

export type CognitoWebSessionConfiguration = Readonly<{
  clientId: string;
  issuer: string;
  domain: string;
  callbackUrl: string;
}>;

type OAuthTokenResponse = {
  access_token?: unknown;
  refresh_token?: unknown;
  expires_in?: unknown;
  token_type?: unknown;
};

type AccessClaims = {
  sub?: unknown;
  iss?: unknown;
  client_id?: unknown;
  token_use?: unknown;
  exp?: unknown;
  auth_time?: unknown;
  scope?: unknown;
};

export class AwsCognitoWebSessionProvider implements CognitoWebSessionProvider {
  constructor(
    private readonly client: CognitoIdentityProviderClient,
    private readonly configuration: CognitoWebSessionConfiguration,
    private readonly request: typeof fetch = fetch,
  ) {
    if (
      configuration.clientId.length === 0 ||
      configuration.issuer.length === 0 ||
      configuration.domain.length === 0 ||
      configuration.callbackUrl.length === 0
    ) {
      throw new Error("Cognito web session configuration is incomplete.");
    }
  }

  async refresh(refreshToken: string): Promise<CognitoTokenSet> {
    const response = await this.client.send(
      new GetTokensFromRefreshTokenCommand({
        ClientId: this.configuration.clientId,
        RefreshToken: refreshToken,
      }),
    );
    const result = response.AuthenticationResult;
    if (!result?.AccessToken) {
      throw new Error("Cognito did not return a web access token.");
    }
    return this.validatedTokenSet(result.AccessToken, result.RefreshToken);
  }

  async revoke(refreshToken: string): Promise<void> {
    await this.client.send(
      new RevokeTokenCommand({
        ClientId: this.configuration.clientId,
        Token: refreshToken,
      }),
    );
  }

  async identity(accessToken: string): Promise<WebSessionIdentity> {
    const claims = this.validatedAccessClaims(accessToken);
    const scopes =
      typeof claims.scope === "string" ? claims.scope.split(" ") : [];
    if (scopes.includes("openid")) {
      return this.oauthIdentity(accessToken, claims.sub);
    }
    return this.sdkIdentity(accessToken, claims.sub);
  }

  private async oauthIdentity(
    accessToken: string,
    expectedSubject: string,
  ): Promise<WebSessionIdentity> {
    const response = await this.request(
      new URL("/oauth2/userInfo", this.domainOrigin()),
      {
        method: "GET",
        headers: { authorization: `Bearer ${accessToken}` },
        redirect: "error",
      },
    );
    if (!response.ok) {
      throw new Error("Cognito web identity lookup failed.");
    }
    const attributes = (await response.json()) as Record<string, unknown>;
    return identityFromAttributes(attributes, expectedSubject);
  }

  private async sdkIdentity(
    accessToken: string,
    expectedSubject: string,
  ): Promise<WebSessionIdentity> {
    const response = await this.client.send(
      new GetUserCommand({ AccessToken: accessToken }),
    );
    const attributes = Object.fromEntries(
      (response.UserAttributes ?? [])
        .filter(
          (attribute): attribute is { Name: string; Value: string } =>
            typeof attribute.Name === "string" &&
            typeof attribute.Value === "string",
        )
        .map((attribute) => [attribute.Name, attribute.Value]),
    );
    return identityFromAttributes(attributes, expectedSubject);
  }

  googleAuthorizationUrl(input: {
    state: string;
    codeChallenge: string;
  }): string {
    const url = new URL("/oauth2/authorize", this.domainOrigin());
    url.searchParams.set("client_id", this.configuration.clientId);
    url.searchParams.set("response_type", "code");
    url.searchParams.set("redirect_uri", this.configuration.callbackUrl);
    url.searchParams.set("scope", "openid email profile");
    url.searchParams.set("identity_provider", "Google");
    url.searchParams.set("prompt", "select_account");
    url.searchParams.set("state", input.state);
    url.searchParams.set("code_challenge", input.codeChallenge);
    url.searchParams.set("code_challenge_method", "S256");
    return url.toString();
  }

  async exchangeAuthorizationCode(
    code: string,
    codeVerifier: string,
  ): Promise<CognitoTokenSet> {
    const response = await this.request(
      new URL("/oauth2/token", this.domainOrigin()),
      {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          grant_type: "authorization_code",
          client_id: this.configuration.clientId,
          redirect_uri: this.configuration.callbackUrl,
          code,
          code_verifier: codeVerifier,
        }),
        redirect: "error",
      },
    );
    if (!response.ok) {
      throw new Error("Cognito authorization-code exchange failed.");
    }
    const payload = (await response.json()) as OAuthTokenResponse;
    if (
      typeof payload.access_token !== "string" ||
      typeof payload.refresh_token !== "string"
    ) {
      throw new Error("Cognito token response is incomplete.");
    }
    return this.validatedTokenSet(payload.access_token, payload.refresh_token);
  }

  private validatedTokenSet(
    accessToken: string,
    refreshToken?: string,
  ): CognitoTokenSet {
    const claims = this.validatedAccessClaims(accessToken);
    return {
      accessToken,
      refreshToken,
      subject: claims.sub,
      accessExpiresAtMs: claims.exp * 1000,
      authenticationTimeMs: claims.auth_time * 1000,
    };
  }

  private validatedAccessClaims(accessToken: string): AccessClaims & {
    sub: string;
    exp: number;
    auth_time: number;
  } {
    const claims = decodeClaims(accessToken);
    if (
      claims.iss !== this.configuration.issuer ||
      claims.client_id !== this.configuration.clientId ||
      claims.token_use !== "access" ||
      typeof claims.sub !== "string" ||
      claims.sub.length === 0 ||
      typeof claims.exp !== "number" ||
      typeof claims.auth_time !== "number"
    ) {
      throw new Error("Cognito web access token claims are invalid.");
    }
    return claims as AccessClaims & {
      sub: string;
      exp: number;
      auth_time: number;
    };
  }

  private domainOrigin(): URL {
    const origin = this.configuration.domain.startsWith("https://")
      ? this.configuration.domain
      : `https://${this.configuration.domain}`;
    const url = new URL(origin);
    if (url.protocol !== "https:") {
      throw new Error("Cognito domain must use HTTPS.");
    }
    return url;
  }
}

function identityFromAttributes(
  attributes: Record<string, unknown>,
  expectedSubject: string,
): WebSessionIdentity {
  if (attributes.sub !== expectedSubject) {
    throw new Error("Cognito web identity does not match the access token.");
  }
  const emailVerified = verifiedAttribute(attributes.email_verified);
  return {
    sub: expectedSubject,
    email:
      emailVerified === true && isSafeAttribute(attributes.email)
        ? attributes.email
        : null,
    emailVerified,
  };
}

function verifiedAttribute(value: unknown): boolean | null {
  if (value === true || value === "true") return true;
  if (value === false || value === "false") return false;
  return null;
}

function isSafeAttribute(value: unknown): value is string {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= 320 &&
    !/[\p{Cc}\p{Z}]/u.test(value)
  );
}

function decodeClaims(token: string): AccessClaims {
  const parts = token.split(".");
  if (parts.length !== 3 || !parts[1]) {
    throw new Error("Cognito web access token is malformed.");
  }
  try {
    return JSON.parse(
      Buffer.from(parts[1], "base64url").toString("utf8"),
    ) as AccessClaims;
  } catch {
    throw new Error("Cognito web access token payload is malformed.");
  }
}
