/** Private Lambda boundary keeping Cognito administration outside the VPC. */

import { InvokeCommand, type LambdaClient } from "@aws-sdk/client-lambda";

import type { CognitoErasurePort } from "./staged_account_deletion_executor.js";

export class LambdaCognitoErasure implements CognitoErasurePort {
  constructor(
    private readonly client: LambdaClient,
    private readonly functionName: string,
  ) {}

  async globallySignOutAndDelete(ownerSubject: string): Promise<void> {
    const result = await this.invoke("delete", ownerSubject);
    if (result.deleted !== true)
      throw new Error("Cognito deletion was not confirmed.");
  }

  async identityExists(ownerSubject: string): Promise<boolean> {
    const result = await this.invoke("exists", ownerSubject);
    if (typeof result.exists !== "boolean") {
      throw new Error("Cognito verification returned an invalid response.");
    }
    return result.exists;
  }

  private async invoke(
    action: "delete" | "exists",
    ownerSubject: string,
  ): Promise<{ deleted?: boolean; exists?: boolean }> {
    const response = await this.client.send(
      new InvokeCommand({
        FunctionName: this.functionName,
        InvocationType: "RequestResponse",
        Payload: Buffer.from(JSON.stringify({ action, ownerSubject })),
      }),
    );
    if (response.FunctionError || !response.Payload) {
      throw new Error("Cognito finalizer failed.");
    }
    return JSON.parse(Buffer.from(response.Payload).toString("utf8")) as {
      deleted?: boolean;
      exists?: boolean;
    };
  }
}
