/** Invokes the isolated provider Lambda through the private Lambda endpoint. */

import { InvokeCommand, LambdaClient } from "@aws-sdk/client-lambda";
import type { ProviderCommand, ProviderResult } from "./provider_contract.js";

export interface EmailProviderBoundary {
  invoke(command: ProviderCommand): Promise<ProviderResult>;
}

export class LambdaEmailProviderBoundary implements EmailProviderBoundary {
  private readonly client = new LambdaClient({});

  constructor(private readonly functionName: string) {}

  async invoke(command: ProviderCommand): Promise<ProviderResult> {
    const result = await this.client.send(
      new InvokeCommand({
        FunctionName: this.functionName,
        InvocationType: "RequestResponse",
        Payload: Buffer.from(JSON.stringify(command)),
      }),
    );
    if (result.FunctionError || !result.Payload)
      throw new Error("Email provider boundary failed.");
    const response = JSON.parse(
      Buffer.from(result.Payload).toString("utf8"),
    ) as {
      ok: boolean;
      result?: ProviderResult;
      errorCode?: string;
    };
    if (!response.ok || !response.result)
      throw new Error(response.errorCode ?? "Email provider boundary failed.");
    return response.result;
  }
}
