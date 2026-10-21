/**
 * Enforces Account Deletion barriers at Cognito's verified-identity boundary.
 * Native users are checked after email confirmation during authentication;
 * federated users can additionally be checked during external-provider signup.
 */

import type { AccountDeletionGuardDecision } from "./account_deletion_guard.js";

type Guard = {
  evaluateIdentity(subject: string): Promise<AccountDeletionGuardDecision>;
  evaluateRegistration(email: string): Promise<AccountDeletionGuardDecision>;
};

export class CognitoAccountAccessDeniedError extends Error {
  constructor() {
    super("Account access is temporarily unavailable.");
    this.name = "CognitoAccountAccessDeniedError";
  }
}

export class CognitoAccountAccessProtection {
  constructor(private readonly guard: Guard) {}

  /** Checks both the durable subject tombstone and the 30-day email barrier. */
  async assertPostAuthentication(input: {
    subject?: string;
    email?: string;
    emailVerified: boolean;
  }): Promise<void> {
    if (!input.subject || !input.email || !input.emailVerified) {
      throw new CognitoAccountAccessDeniedError();
    }
    try {
      const [identity, registration] = await Promise.all([
        this.guard.evaluateIdentity(input.subject),
        this.guard.evaluateRegistration(input.email),
      ]);
      if (identity.state === "active" && registration.state === "active") {
        return;
      }
    } catch {
      // Cognito receives a stable denial; raw AWS/identity errors stay private.
    }
    throw new CognitoAccountAccessDeniedError();
  }

  /** External-provider signup has verified-email evidence before provisioning. */
  async assertFederatedRegistration(input: {
    email?: string;
    emailVerified: boolean;
  }): Promise<void> {
    if (!input.email || !input.emailVerified) {
      throw new CognitoAccountAccessDeniedError();
    }
    try {
      const registration = await this.guard.evaluateRegistration(input.email);
      if (registration.state === "active") return;
    } catch {
      // Keep provider and ledger diagnostics out of the Cognito response.
    }
    throw new CognitoAccountAccessDeniedError();
  }
}
