
/**
 * Generate a secret to be shared with the provisioner and Control Room.
 *  - resulting secret is hex(sha256(preshared_secret_as_utf8_bytes))
 */
resource "random_password" "preshared_secret" {
  length  = 100
  special = false
  lower   = true
  numeric = true
  upper   = true
}

resource "aws_secretsmanager_secret" "configuration_out" {
  name = "${var.id}-config"
  description = "Configuration of Robocorp On-demand Worker Provisioner ${var.id}"
}

resource "aws_secretsmanager_secret_version" "configuration_out" {
  secret_id     = aws_secretsmanager_secret.configuration_out.id
  secret_string = jsonencode({
    secret = random_password.preshared_secret.result,
    clusterConfigParameterArn = module.ecs_cluster_1.cluster_configuration_parameter_arn,
    ecrRepositoryUrl = aws_ecr_repository.worker_images.repository_url,
  })
}
