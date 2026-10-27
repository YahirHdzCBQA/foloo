/** Outside-VPC Cognito finalizer invoked only by the deletion worker. */

import { CognitoIdentityProviderClient } from "@aws-sdk/client-cognito-identity-provider";

import { CognitoAdminErasure } from "./aws_account_deletion_adapters.js";

type FinalizerCommand = {
  action: "delete" | "exists";
  ownerSubject: string;
};

const client = new CognitoIdentityProviderClient({});

export async function handler(command: FinalizerCommand) {
  const userPoolId = process.env.COGNITO_USER_POOL_ID;
  if (!userPoolId) throw new Error("COGNITO_USER_POOL_ID is required.");
  if (process.env.FOLOO_ACCOUNT_DELETION_FINALIZER_ENABLED !== "true") {
    throw new Error("Account deletion finalizer is disabled.");
  }
  const erasure = new CognitoAdminErasure(client, userPoolId);
  if (command.action === "delete") {
    await erasure.globallySignOutAndDelete(command.ownerSubject);
    return { deleted: true };
  }
  if (command.action === "exists") {
    return { exists: await erasure.identityExists(command.ownerSubject) };
  }
  throw new Error("Invalid Cognito finalizer action.");
}
