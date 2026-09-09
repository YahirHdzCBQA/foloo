/** Validates Lambda configuration without embedding credentials or endpoints. */

import { z } from "zod";

const environmentSchema = z.object({
  AWS_REGION: z.string().min(1),
  DB_SECRET_ARN: z.string().min(1),
  DB_HOST: z.string().min(1),
  DB_PORT: z.coerce.number().int().positive().default(5432),
  DB_NAME: z.string().min(1),
  DB_POOL_MAX: z.coerce.number().int().min(1).max(5).default(2),
});

export type BackendEnvironment = z.infer<typeof environmentSchema>;

export function loadEnvironment(
  values: NodeJS.ProcessEnv = process.env,
): BackendEnvironment {
  return environmentSchema.parse(values);
}
