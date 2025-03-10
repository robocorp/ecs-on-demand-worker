resource "aws_ssm_parameter" "configuration_out" {
  name = "${var.id}-configuration"
  type = "String"
  value = jsonencode({
    provisionerRoleArn      = aws_iam_role.worker_provisioner_role.arn,
    robotRoleArn            = aws_iam_role.ecs_robot_task_role.arn,
    ecsTaskExecutionRoleArn = aws_iam_role.ecs_task_execution_role.arn,
    ecsClusterArn           = aws_ecs_cluster.cluster.arn,
  })
}
