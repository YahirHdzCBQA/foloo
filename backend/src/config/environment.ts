/** Validates Lambda configuration without embedding credentials or endpoints. */

import { z } from "zod";

const environmentSchema = z.object({
  STRIPE_PRICE_ID: z.string().min(1).optional(),
  STRIPE_SECRET_ARN: z.string().min(1).optional(),
  STRIPE_WEBHOOK_SECRET_ARN: z.string().min(1).optional(),
  BILLING_PROVIDER_FUNCTION_NAME: z.string().min(1).optional(),
  BILLING_SUCCESS_URL: z.string().url().optional(),
  BILLING_CANCEL_URL: z.string().url().optional(),
  BILLING_PORTAL_RETURN_URL: z.string().url().optional(),
  AWS_REGION: z.string().min(1),
  DB_SECRET_ARN: z.string().min(1),
  DB_HOST: z.string().min(1),
  DB_PORT: z.coerce.number().int().positive().default(5432),
  DB_NAME: z.string().min(1),
  DB_POOL_MAX: z.coerce.number().int().min(1).max(5).default(2),
  MEDIA_BUCKET_NAME: z.string().min(3),
  EMAIL_PROVIDER_FUNCTION_NAME: z.string().min(1),
  PUBLIC_API_BASE_URL: z.string().url(),
  FOLOO_UNLIMITED_QA_MODE: z
    .enum(["true", "false"])
    .default("false")
    .transform((value) => value === "true"),
  FOLOO_ACCOUNT_DELETION_ENABLED: z
    .enum(["true", "false"])
    .default("false")
    .transform((value) => value === "true"),
  FOLOO_ACCOUNT_DELETION_NORMAL_ACCESS_ENABLED: z
    .enum(["true", "false"])
    .default("false")
    .transform((value) => value === "true"),
  FOLOO_ACCOUNT_DELETION_INTAKE_ENABLED: z
    .enum(["true", "false"])
    .default("false")
    .transform((value) => value === "true"),
  FOLOO_ENVIRONMENT: z.string().min(1).default("unconfigured"),
  FOLOO_ACCOUNT_DELETION_QA_ENABLED: z
    .enum(["true", "false"])
    .default("false")
    .transform((value) => value === "true"),
  ACCOUNT_DELETION_QA_SUBJECT_HASHES: z.string().default(""),
  ACCOUNT_DELETION_TABLE_NAME: z.string().min(1).optional(),
  ACCOUNT_DELETION_HMAC_KEY_ARN: z.string().min(1).optional(),
  ACCOUNT_DELETION_HMAC_KEY_VERSION: z.string().min(1).optional(),
  ACCOUNT_DELETION_QUEUE_URL: z.string().url().optional(),
  ACCOUNT_DELETION_RECIPIENT_KEY_ARN: z.string().min(1).optional(),
  ACCOUNT_DELETION_NOTIFICATION_FUNCTION_NAME: z.string().min(1).optional(),
  ACCOUNT_DELETION_NOTIFICATION_MODE: z
    .enum(["disabled", "ses"])
    .default("disabled"),
  ACCOUNT_DELETION_COGNITO_FINALIZER_FUNCTION_NAME: z
    .string()
    .min(1)
    .optional(),
  ACCOUNT_DELETION_VERIFIED_EMAIL_FUNCTION_NAME: z.string().min(1).optional(),
  ACCOUNT_DELETION_REAUTH_MAX_AGE_SECONDS: z.coerce
    .number()
    .int()
    .positive()
    .default(300),
});

export type BackendEnvironment = z.infer<typeof environmentSchema>;

export function loadEnvironment(
  values: NodeJS.ProcessEnv = process.env,
): BackendEnvironment {
  return environmentSchema.parse(values);
}
