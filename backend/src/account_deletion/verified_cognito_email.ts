/** Trusted Cognito boundary for the verified email used during deletion.
 *
 * The API keeps the access token as its bearer credential. Implementations
 * must resolve attributes from Cognito and bind them to the already verified
 * API Gateway subject before returning an email (AUT-19, RNF-09).
 */

export type VerifiedCognitoEmailInput = Readonly<{
  accessToken: string;
  expectedSubject: string;
  scopes: readonly string[];
}>;

export interface VerifiedCognitoEmailResolver {
  resolve(input: VerifiedCognitoEmailInput): Promise<string>;
}

export class CognitoIdentityRejectedError extends Error {
  constructor() {
    super("Cognito identity could not be verified.");
    this.name = "CognitoIdentityRejectedError";
  }
}

export class CognitoIdentityUnavailableError extends Error {
  constructor() {
    super("Cognito identity verification is unavailable.");
    this.name = "CognitoIdentityUnavailableError";
  }
}
