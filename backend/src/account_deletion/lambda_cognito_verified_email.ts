/** Invokes the isolated Cognito verified-email boundary without logging PII. */

import { InvokeCommand, type LambdaClient } from "@aws-sdk/client-lambda";

import { ApplicationError, unauthorized } from "../application/errors.js";
import type {
  VerifiedCognitoEmailInput,
  VerifiedCognitoEmailResolver,
} from "./verified_cognito_email.js";

type ResolverResponse =
  | { ok: true; email: string }
  | {
      ok: false;
      errorCode: "unauthenticated" | "identity_verification_unavailable";
    };

export class LambdaCognitoVerifiedEmailResolver implements VerifiedCognitoEmailResolver {
  constructor(
    private readonly client: LambdaClient,
    private readonly functionName: string,
  ) {
    if (!functionName.trim()) {
      throw new Error("Verified-email function name is required.");
    }
  }

  async resolve(input: VerifiedCognitoEmailInput): Promise<string> {
    let response;
    try {
      response = await this.client.send(
        new InvokeCommand({
          FunctionName: this.functionName,
          InvocationType: "RequestResponse",
          Payload: Buffer.from(JSON.stringify(input)),
        }),
      );
    } catch {
      throw unavailable();
    }
    if (response.FunctionError || !response.Payload) throw unavailable();
    let result: ResolverResponse;
    try {
      result = JSON.parse(
        Buffer.from(response.Payload).toString("utf8"),
      ) as ResolverResponse;
    } catch {
      throw unavailable();
    }
    if (!result.ok) {
      if (result.errorCode === "unauthenticated") throw unauthorized();
      throw unavailable();
    }
    if (typeof result.email !== "string" || result.email.length === 0) {
      throw unavailable();
    }
    return result.email;
  }
}

function unavailable(): ApplicationError {
  return new ApplicationError(
    "identity_verification_unavailable",
    503,
    "Identity verification is temporarily unavailable.",
  );
}
