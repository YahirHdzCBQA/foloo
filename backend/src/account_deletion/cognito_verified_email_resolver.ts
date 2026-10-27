/** Resolves a verified email from Cognito without trusting client attributes. */

import {
  GetUserCommand,
  type CognitoIdentityProviderClient,
} from "@aws-sdk/client-cognito-identity-provider";

import {
  canonicalizeVerifiedEmail,
  InvalidCanonicalEmailError,
} from "./pseudonymous_identity.js";
import {
  CognitoIdentityRejectedError,
  CognitoIdentityUnavailableError,
  type VerifiedCognitoEmailInput,
  type VerifiedCognitoEmailResolver,
} from "./verified_cognito_email.js";

type Attributes = Record<string, unknown>;

export class AwsCognitoVerifiedEmailResolver implements VerifiedCognitoEmailResolver {
  private readonly userInfoEndpoint: URL;

  constructor(
    private readonly client: CognitoIdentityProviderClient,
    endpoint: string,
    private readonly request: typeof fetch = fetch,
  ) {
    this.userInfoEndpoint = new URL(endpoint);
    if (
      this.userInfoEndpoint.protocol !== "https:" ||
      this.userInfoEndpoint.pathname !== "/oauth2/userInfo" ||
      this.userInfoEndpoint.username.length > 0 ||
      this.userInfoEndpoint.password.length > 0
    ) {
      throw new Error("Cognito userInfo endpoint is invalid.");
    }
  }

  async resolve(input: VerifiedCognitoEmailInput): Promise<string> {
    if (
      input.accessToken.length < 16 ||
      input.accessToken.length > 16_384 ||
      input.expectedSubject.length === 0 ||
      input.expectedSubject.length > 2048
    ) {
      throw new CognitoIdentityRejectedError();
    }
    try {
      const attributes = input.scopes.includes("openid")
        ? await this.oauthAttributes(input.accessToken)
        : await this.nativeAttributes(input.accessToken);
      return verifiedEmail(attributes, input.expectedSubject);
    } catch (error) {
      if (
        error instanceof CognitoIdentityRejectedError ||
        error instanceof CognitoIdentityUnavailableError
      ) {
        throw error;
      }
      if (isCognitoRejection(error)) {
        throw new CognitoIdentityRejectedError();
      }
      throw new CognitoIdentityUnavailableError();
    }
  }

  private async nativeAttributes(accessToken: string): Promise<Attributes> {
    const response = await this.client.send(
      new GetUserCommand({ AccessToken: accessToken }),
    );
    return Object.fromEntries(
      (response.UserAttributes ?? [])
        .filter(
          (attribute): attribute is { Name: string; Value: string } =>
            typeof attribute.Name === "string" &&
            typeof attribute.Value === "string",
        )
        .map((attribute) => [attribute.Name, attribute.Value]),
    );
  }

  private async oauthAttributes(accessToken: string): Promise<Attributes> {
    let response: Response;
    try {
      response = await this.request(this.userInfoEndpoint, {
        method: "GET",
        headers: { authorization: `Bearer ${accessToken}` },
        redirect: "error",
      });
    } catch {
      throw new CognitoIdentityUnavailableError();
    }
    if (response.status === 401 || response.status === 403) {
      throw new CognitoIdentityRejectedError();
    }
    if (!response.ok) throw new CognitoIdentityUnavailableError();
    try {
      return (await response.json()) as Attributes;
    } catch {
      throw new CognitoIdentityUnavailableError();
    }
  }
}

function verifiedEmail(
  attributes: Attributes,
  expectedSubject: string,
): string {
  if (
    attributes.sub !== expectedSubject ||
    !(
      attributes.email_verified === true || attributes.email_verified === "true"
    ) ||
    typeof attributes.email !== "string"
  ) {
    throw new CognitoIdentityRejectedError();
  }
  try {
    return canonicalizeVerifiedEmail(attributes.email);
  } catch (error) {
    if (error instanceof InvalidCanonicalEmailError) {
      throw new CognitoIdentityRejectedError();
    }
    throw error;
  }
}

function isCognitoRejection(error: unknown): boolean {
  const name = (error as { name?: unknown } | null)?.name;
  return (
    name === "NotAuthorizedException" ||
    name === "UserNotFoundException" ||
    name === "TokenExpiredException"
  );
}
