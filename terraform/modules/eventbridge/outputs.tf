output "eventbus_arn" {
  description = "ARN of event bus for incoming events"
  value = aws_cloudwatch_event_bus.bus.arn
}
