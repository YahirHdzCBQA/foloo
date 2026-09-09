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
