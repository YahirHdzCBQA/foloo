/** Extracts the only trusted owner identity from API Gateway JWT claims. */

import type { APIGatewayProxyEventV2WithJWTAuthorizer } from "aws-lambda";

import { unauthorized } from "../application/errors.js";

export function authenticatedSubject(
  event: APIGatewayProxyEventV2WithJWTAuthorizer,
): string {
  const claims = event.requestContext.authorizer.jwt.claims;
  if (claims.token_use !== "access") {
    throw unauthorized();
  }
  const subject = claims.sub;
  if (typeof subject !== "string" || subject.trim().length === 0) {
    throw unauthorized();
  }
  return subject;
}
