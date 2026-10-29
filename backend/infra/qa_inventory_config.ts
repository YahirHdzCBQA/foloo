/** WEB-02: bind an optional operator inventory to the single existing DEV destructive QA subject. */
import { createHash } from "node:crypto";
export function qaInventoryEnvironment(
  environment: string,
  subject: unknown,
  enabled: boolean,
  hashes: readonly string[],
  webHashes: readonly string[],
): Record<string, string> {
  if (subject === undefined) return {};
  if (
    environment !== "dev" ||
    !enabled ||
    typeof subject !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(
      subject,
    ) ||
    hashes.length !== 1
  )
    throw new Error("Invalid DEV inventory configuration");
  const hash = createHash("sha256")
    .update("foloo-account-deletion-qa\0" + subject)
    .digest("base64url");
  const webHash = createHash("sha256")
    .update("foloo-web-session\0" + subject)
    .digest("base64url");
  if (hashes[0] !== hash || !webHashes.includes(webHash))
    throw new Error("Inventory subject is not the authorized QA identity");
  return {
    QA_INVENTORY_ENVIRONMENT: "dev",
    QA_INVENTORY_SUBJECT: subject,
    QA_INVENTORY_SUBJECT_HASH: hash,
  };
}
