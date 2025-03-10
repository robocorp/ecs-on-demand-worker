output "cluster_configuration_parameter_arn" {
  description = "ARN of SSM parameter containing cluster configuration"
  value       = aws_ssm_parameter.configuration_out.arn
}
