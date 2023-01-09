export const parseEnvVariable = (variableName: string): string => {
  const envVariable = process.env[variableName];

  if (envVariable === undefined) {
    throw new Error(`Missing environment variable: ${variableName}`);
  }

  return envVariable;
};
