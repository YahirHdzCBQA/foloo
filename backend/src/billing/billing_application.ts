/** Web billing identity and signed webhook boundary (AUT-10, MON-15–MON-19). */
import Stripe from "stripe";
import type { FolooRepository } from "../application/ports.js";
import { ApplicationError, conflict, notFound } from "../application/errors.js";
import type { BackendEnvironment } from "../config/environment.js";
import { billingEventSchema } from "../transport/schemas.js";
import type { BillingProvider } from "./billing_provider_contract.js";
import type { BillingRepository } from "./postgres_billing_repository.js";
import { billingNotConfigured, readBillingSecret } from "./secrets.js";
export class BillingApplication {
  constructor(
    private readonly identities: Pick<FolooRepository, "resolvePrincipal">,
    private readonly repository: BillingRepository,
    private readonly provider: BillingProvider,
    private readonly environment: Partial<BackendEnvironment>,
    private readonly secretReader = readBillingSecret,
  ) {}
  private async account(subject: string) {
    const principal = await this.identities.resolvePrincipal(subject);
    const account = await this.repository.account(principal.accountId);
    if (!account) throw notFound("Account");
    return account;
  }
  async checkout(subject: string) {
    const account = await this.account(subject);
    if (account.subscriptionStatus === "active")
      throw conflict("Subscription is already active. Use the billing portal.");
    const config = this.environment;
    if (
      !config.STRIPE_WEBHOOK_SECRET_ARN ||
      !config.STRIPE_PRICE_ID ||
      !config.BILLING_SUCCESS_URL ||
      !config.BILLING_CANCEL_URL ||
      !config.BILLING_PROVIDER_FUNCTION_NAME ||
      !config.STRIPE_SECRET_ARN
    )
      throw billingNotConfigured();
    let customerId = account.customerId;
    if (!customerId) {
      const created = await this.provider.invoke({
        action: "createCustomer",
        accountId: account.id,
        sub: subject,
      });
      if (!("customerId" in created)) throw billingNotConfigured();
      customerId = await this.repository.linkCustomer(
        account.id,
        created.customerId,
      );
    }
    return this.provider.invoke({
      action: "createCheckoutSession",
      accountId: account.id,
      sub: subject,
      customerId,
      priceId: config.STRIPE_PRICE_ID,
      successUrl: config.BILLING_SUCCESS_URL,
      cancelUrl: config.BILLING_CANCEL_URL,
    });
  }
  async portal(subject: string) {
    const account = await this.account(subject);
    if (!account.customerId) throw notFound("Billing customer");
    const config = this.environment;
    if (
      !config.BILLING_PORTAL_RETURN_URL ||
      !config.BILLING_PROVIDER_FUNCTION_NAME ||
      !config.STRIPE_SECRET_ARN
    )
      throw billingNotConfigured();
    return this.provider.invoke({
      action: "createPortalSession",
      customerId: account.customerId,
      returnUrl: config.BILLING_PORTAL_RETURN_URL,
    });
  }
  async webhook(raw: Buffer, signature: string | undefined) {
    if (!signature?.trim())
      throw new ApplicationError("invalid_webhook", 400, "Invalid webhook.");
    const secret = await this.secretReader(
      this.environment.STRIPE_WEBHOOK_SECRET_ARN,
    );
    let event;
    try {
      event = billingEventSchema.parse(
        Stripe.webhooks.constructEvent(raw, signature ?? "", secret),
      );
    } catch {
      throw new ApplicationError("invalid_webhook", 400, "Invalid webhook.");
    }
    await this.repository.apply(event, this.environment.STRIPE_PRICE_ID);
    return { received: true };
  }
}
