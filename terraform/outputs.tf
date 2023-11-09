output "configuration_secret_arn" {
  description = "ARN of Secrets Manager secret containing provisioner configuration"
  value = aws_secretsmanager_secret.configuration_out.arn
}

output "eventbus_arn" {
  description = "ARN of event bus for incoming events"
  value = module.eventbridge.eventbus_arn
}
