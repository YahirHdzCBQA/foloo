/**
 * WEB-02 / AUT-10: bind an optional operator-only inventory to one DEV subject.
 * The diagnostic selector is independent from runtime admission allowlists so
 * evidence can be collected before enabling destructive QA.
 */
import { createHash } from "node:crypto";
export function qaInventoryEnvironment(
  environment: string,
  subject: unknown,
): Record<string, string> {
  if (subject === undefined) return {};
  if (
    environment !== "dev" ||
    typeof subject !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(
      subject,
    )
  )
    throw new Error("Invalid DEV inventory configuration");
  const hash = createHash("sha256")
    .update("foloo-account-deletion-qa\0" + subject)
    .digest("base64url");
  return {
    QA_INVENTORY_ENVIRONMENT: "dev",
    QA_INVENTORY_SUBJECT: subject,
    QA_INVENTORY_SUBJECT_HASH: hash,
  };
}
