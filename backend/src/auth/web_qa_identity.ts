/**
 * Produces the non-reversible subject identifier shared by Web Sessions and
 * the protected API QA boundary. Raw Cognito subjects must never be logged or
 * placed in deployment configuration.
 */

import { createHash } from "node:crypto";

export function webQaSubjectHash(subject: string): string {
  if (subject.length === 0 || subject.length > 2048) {
    throw new Error("Web QA subject is invalid.");
  }
  return createHash("sha256")
    .update(`foloo-web-session\u0000${subject}`, "utf8")
    .digest("base64url");
}
