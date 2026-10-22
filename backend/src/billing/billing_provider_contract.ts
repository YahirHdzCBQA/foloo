/** Internal public-egress boundary for MON-15/MON-17. Never accepts client identity. */
export type BillingCommand =
  | { action: "createCustomer"; accountId: string; sub: string }
  | {
      action: "createCheckoutSession";
      accountId: string;
      sub: string;
      customerId: string;
      priceId: string;
      successUrl: string;
      cancelUrl: string;
    }
  | { action: "createPortalSession"; customerId: string; returnUrl: string };
export interface BillingProvider {
  invoke(
    command: BillingCommand,
  ): Promise<{ url: string } | { customerId: string }>;
}
