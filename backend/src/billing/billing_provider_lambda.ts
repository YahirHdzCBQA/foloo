/** Stripe SDK calls run outside the isolated API VPC (MON-15/MON-17). */
import Stripe from "stripe";
import { ApplicationError, conflict } from "../application/errors.js";
import type { BillingCommand } from "./billing_provider_contract.js";
import { readBillingSecret } from "./secrets.js";
export async function executeBillingCommand(
  stripe: Stripe,
  command: BillingCommand,
) {
  if (command.action === "createCustomer") {
    const customer = await stripe.customers.create(
      { metadata: { accountId: command.accountId, sub: command.sub } },
      { idempotencyKey: command.accountId },
    );
    return { customerId: customer.id };
  }
  if (command.action === "createCheckoutSession") {
    for await (const subscription of stripe.subscriptions.list({
      customer: command.customerId,
      status: "all",
      limit: 100,
    })) {
      if (["active", "trialing", "past_due"].includes(subscription.status))
        throw conflict("Subscription already exists. Use the billing portal.");
    }
  }
  const session =
    command.action === "createCheckoutSession"
      ? await stripe.checkout.sessions.create({
          mode: "subscription",
          client_reference_id: command.accountId,
          metadata: { sub: command.sub, origin: "foloo-app" },
          subscription_data: { metadata: { accountId: command.accountId } },
          customer: command.customerId,
          line_items: [{ price: command.priceId, quantity: 1 }],
          success_url: command.successUrl,
          cancel_url: command.cancelUrl,
        })
      : await stripe.billingPortal.sessions.create({
          customer: command.customerId,
          return_url: command.returnUrl,
        });
  if (!session.url) throw new Error("billing_provider_failed");
  return { url: session.url };
}
export async function handler(command: BillingCommand) {
  try {
    const stripe = new Stripe(
      await readBillingSecret(process.env.STRIPE_SECRET_ARN),
      { timeout: 8000, maxNetworkRetries: 0 },
    );
    return { ok: true, result: await executeBillingCommand(stripe, command) };
  } catch (error) {
    if (error instanceof ApplicationError && error.statusCode === 409)
      return { ok: false, errorCode: "billing_use_portal" };
    return { ok: false, errorCode: "billing_provider_unavailable" };
  }
}
