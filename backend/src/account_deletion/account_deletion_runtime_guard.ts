/** Fail-closed access guard shared by API, sync and OAuth callback paths. */

import { ApplicationError } from "../application/errors.js";
import type { AccountDeletionGuard } from "./account_deletion_guard.js";

export class AccountDeletionRuntimeGuard<KeyHandle> {
  constructor(private readonly guard: AccountDeletionGuard<KeyHandle>) {}

  async assertActive(subject: string): Promise<void> {
    const result = await this.guard.evaluateIdentity(subject);
    if (result.state !== "active") {
      throw new ApplicationError(
        "account_deletion_pending",
        423,
        "Account deletion is pending or completed.",
      );
    }
  }
}
