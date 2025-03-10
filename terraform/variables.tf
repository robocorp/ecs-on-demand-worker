
variable "id" {
  type        = string
  description = "Identifier of this on-demand worker infrastructure. Used to makes resource names unique."
  default     = "rc-odw-1"
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy to"
  default     = "us-east-1"
}
