variable "id" {
  type = string
}

variable "eventbridge_external_in_allowed_source_rule_arns" {
  description = "Allowed source event rule ARNs that can put events to the bus"
  type        = set(string)
}
