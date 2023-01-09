import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';
import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';
import { parse as parseArn } from '@aws-sdk/util-arn-parser';
import { EcsProvisioner } from './ecs';
import { ClusterConfiguration, ProvisionerConfiguration } from './types';

const ssmParameterArnToName = (parameterArn: string): string => {
  // SSM seems to require parameter name in GetParameter request.
  // Extract name from the full ARN.
  const parameterArnComponents = parseArn(parameterArn);
  const parameterName = parameterArnComponents.resource;
  return parameterName.replace(/^parameter\//, '');
};

let provisionerConfiguration: ProvisionerConfiguration;
export async function getProvisionerConfiguration(
  secretName: string,
): Promise<ProvisionerConfiguration> {
  if (!provisionerConfiguration) {
    console.log(`No cached provisioner configuration found, read secret ${secretName}`);
    const client = new SecretsManagerClient({});
    const command = new GetSecretValueCommand({
      SecretId: secretName,
    });
    const response = await client.send(command);
    provisionerConfiguration = JSON.parse(response.SecretString!);
  }
  return provisionerConfiguration;
}

let clusterConfiguration: ClusterConfiguration;
export async function getClusterConfiguration(parameterArn: string): Promise<ClusterConfiguration> {
  if (!clusterConfiguration) {
    const parameterName = ssmParameterArnToName(parameterArn);
    console.log(
      `No cached cluster configuration found, read SSM parameter ${parameterName} (arn=${parameterArn})`,
    );

    const client = new SSMClient({});
    const command = new GetParameterCommand({
      Name: parameterName,
    });
    const response = await client.send(command);
    clusterConfiguration = JSON.parse(response.Parameter!.Value!);
  }
  return clusterConfiguration;
}

let ecsProvisioner: EcsProvisioner;
export function getEcsProvisioner(clusterConfiguration: ClusterConfiguration): EcsProvisioner {
  if (!ecsProvisioner) {
    ecsProvisioner = new EcsProvisioner(clusterConfiguration);
  }
  return ecsProvisioner;
}
