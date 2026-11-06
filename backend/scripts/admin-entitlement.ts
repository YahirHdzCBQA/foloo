/** Private operator entry point for one verified administrative PRO grant.
 *
 * Inputs and database credentials are runtime-only. The command emits only the
 * action and resulting plan; it never logs email, Cognito subject, or secrets.
 */

import {
  CognitoIdentityProviderClient,
  ListUsersCommand,
} from "@aws-sdk/client-cognito-identity-provider";
import {
  GetSecretValueCommand,
  SecretsManagerClient,
} from "@aws-sdk/client-secrets-manager";
import { GetCallerIdentityCommand, STSClient } from "@aws-sdk/client-sts";
import pg from "pg";

import {
  AdministrativeEntitlementService,
  type VerifiedCognitoIdentityResolver,
} from "../src/entitlements/administrative_entitlement.js";
import { verifiedAdministrativeIdentity } from "../src/entitlements/cognito_administrative_identity.js";

const databaseSecretArn = required("DB_ENTITLEMENT_OPERATOR_SECRET_ARN");
const databaseHost = required("DB_HOST");
const databaseName = required("DB_NAME");
const databasePort = positivePort(process.env.DB_PORT ?? "5432");
const userPoolId = required("COGNITO_USER_POOL_ID");
const region = required("AWS_REGION");
const email = required("FOLOO_ENTITLEMENT_EMAIL");
const reason = required("FOLOO_ADMIN_REASON");
const rawAction = required("FOLOO_ENTITLEMENT_ACTION");
if (rawAction !== "grant" && rawAction !== "revoke") {
  throw new Error("FOLOO_ENTITLEMENT_ACTION must be grant or revoke.");
}

const cognito = new CognitoIdentityProviderClient({ region });
const caller = await new STSClient({ region }).send(
  new GetCallerIdentityCommand({}),
);
const actor = caller.Arn?.trim();
if (!actor || actor.length > 160)
  throw new Error("Authenticated operator identity is unavailable.");
const identities: VerifiedCognitoIdentityResolver = {
  async resolveVerifiedEmail(candidate) {
    const users = await cognito.send(
      new ListUsersCommand({
        UserPoolId: userPoolId,
        Filter: `email = "${cognitoFilterValue(candidate)}"`,
        Limit: 2,
      }),
    );
    if (users.Users?.length !== 1) {
      throw new Error("Administrative identity is missing or ambiguous.");
    }
    return verifiedAdministrativeIdentity(users.Users[0]!, candidate);
  },
};

const secretResult = await new SecretsManagerClient({ region }).send(
  new GetSecretValueCommand({ SecretId: databaseSecretArn }),
);
if (!secretResult.SecretString)
  throw new Error("Administrative database secret is unavailable.");
const databaseSecret = JSON.parse(secretResult.SecretString) as Partial<{
  username: string;
  password: string;
}>;
if (!databaseSecret.username || !databaseSecret.password)
  throw new Error("Administrative database secret is incomplete.");
if (databaseSecret.username !== "foloo_entitlement_operator")
  throw new Error("Administrative database role is invalid.");
const pool = new pg.Pool({
  host: databaseHost,
  port: databasePort,
  database: databaseName,
  user: databaseSecret.username,
  password: databaseSecret.password,
  ssl: { rejectUnauthorized: true },
  max: 1,
  connectionTimeoutMillis: 5_000,
});
try {
  const result = await new AdministrativeEntitlementService(
    pool,
    identities,
  ).execute({ action: rawAction, email, actor, reason });
  console.info(JSON.stringify(result));
} finally {
  await pool.end();
}

function cognitoFilterValue(value: string): string {
  const normalized = value.trim().toLowerCase();
  if (!/^[^\s@"]+@[^\s@"]+$/u.test(normalized)) {
    throw new Error("FOLOO_ENTITLEMENT_EMAIL is invalid.");
  }
  return normalized.replaceAll("\\", "\\\\");
}

function required(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

function positivePort(value: string): number {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > 65535)
    throw new Error("DB_PORT is invalid.");
  return parsed;
}
