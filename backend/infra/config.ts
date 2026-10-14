/** Central AWS environment configuration; PROD stays undefined until approved. */

export type EnvironmentConfig = {
  name: "dev";
  region: "us-east-1";
  userPoolId: string;
  appClientId: string;
  databaseName: string;
};

const dev: EnvironmentConfig = {
  name: "dev",
  region: "us-east-1",
  userPoolId: "us-east-1_QVm3dWe4O",
  appClientId: "6jong3atp2crqcsde6g215ant8",
  databaseName: "foloo",
};

export function environmentConfig(name: string): EnvironmentConfig {
  if (name !== "dev")
    throw new Error(`Environment ${name} has no approved configuration.`);
  return dev;
}

/** Allows the temporary unlimited switch only in an explicitly selected DEV stack. */
export function unlimitedQaModeForEnvironment(
  environment: string,
  rawValue: unknown,
): boolean {
  const enabled = rawValue === true || rawValue === "true";
  if (enabled && environment !== "dev") {
    throw new Error("FOLOO unlimited QA mode is restricted to DEV.");
  }
  return enabled;
}
