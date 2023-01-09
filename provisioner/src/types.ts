/**
 * Provisioner configuration from terraform project.
 */
export type ProvisionerConfiguration = {
  secret: string;
  clusterConfigParameterArn: string;
  ecrRepositoryUrl: string;
};

/**
 * Cluster configuration from terraform project.
 */
export type ClusterConfiguration = {
  provisionerRoleArn: string;
  robotRoleArn: string;
  ecsTaskExecutionRoleArn: string;
  ecsClusterArn: string;
};
