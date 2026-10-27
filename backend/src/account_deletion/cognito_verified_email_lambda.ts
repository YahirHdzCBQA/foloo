/** Private token-to-verified-email boundary for the VPC-isolated Foloo API. */

import { CognitoIdentityProviderClient } from "@aws-sdk/client-cognito-identity-provider";
import { z } from "zod";

import { AwsCognitoVerifiedEmailResolver } from "./cognito_verified_email_resolver.js";
import { CognitoIdentityRejectedError } from "./verified_cognito_email.js";

const inputSchema = z
  .object({
    accessToken: z.string().min(16).max(16_384),
    expectedSubject: z.string().min(1).max(2048),
    scopes: z.array(z.string().min(1).max(256)).max(32),
  })
  .strict();

let resolver: AwsCognitoVerifiedEmailResolver | undefined;

export async function handler(event: unknown): Promise<
  | { ok: true; email: string }
  | {
      ok: false;
      errorCode: "unauthenticated" | "identity_verification_unavailable";
    }
> {
  const parsed = inputSchema.safeParse(event);
  if (!parsed.success) return { ok: false, errorCode: "unauthenticated" };
  try {
    resolver ??= new AwsCognitoVerifiedEmailResolver(
      new CognitoIdentityProviderClient({}),
      requiredEnvironment("COGNITO_USER_INFO_ENDPOINT"),
    );
    return { ok: true, email: await resolver.resolve(parsed.data) };
  } catch (error) {
    return {
      ok: false,
      errorCode:
        error instanceof CognitoIdentityRejectedError
          ? "unauthenticated"
          : "identity_verification_unavailable",
    };
  }
}

function requiredEnvironment(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required.`);
  return value;
}
