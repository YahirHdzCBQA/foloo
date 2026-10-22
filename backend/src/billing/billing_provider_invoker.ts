/** Invokes the billing provider over the existing private Lambda endpoint. */
import { InvokeCommand, LambdaClient } from "@aws-sdk/client-lambda";
import { z } from "zod";
import { ApplicationError, conflict } from "../application/errors.js";
import type {
  BillingCommand,
  BillingProvider,
} from "./billing_provider_contract.js";
import { billingNotConfigured } from "./secrets.js";
export class LambdaBillingProvider implements BillingProvider {
  private readonly client = new LambdaClient({});
  constructor(private readonly functionName?: string) {}
  async invoke(command: BillingCommand) {
    if (!this.functionName) throw billingNotConfigured();
    try {
      const response = await this.client.send(
        new InvokeCommand({
          FunctionName: this.functionName,
          InvocationType: "RequestResponse",
          Payload: Buffer.from(JSON.stringify(command)),
        }),
      );
      if (response.FunctionError || !response.Payload) throw new Error();
      const payload = JSON.parse(
        Buffer.from(response.Payload).toString("utf8"),
      ) as { errorCode?: string };
      if (payload.errorCode === "billing_use_portal")
        throw conflict("Subscription already exists. Use the billing portal.");
      return z
        .object({
          ok: z.literal(true),
          result: z.union([
            z.object({ url: z.url() }),
            z.object({ customerId: z.string().min(1) }),
          ]),
        })
        .parse(payload).result;
    } catch (error) {
      if (error instanceof ApplicationError && error.statusCode === 409)
        throw error;
      throw new ApplicationError(
        "billing_provider_unavailable",
        503,
        "Billing is temporarily unavailable.",
      );
    }
  }
}
