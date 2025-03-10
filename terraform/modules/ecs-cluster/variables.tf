variable "id" {
  type        = string
  description = "Identifier to make the resources unique"
}

variable "ec2_instance_type" {
  type        = string
  description = "Instance type for EC2 instances powering the cluster"
  default     = "t3a.medium"
}

variable "ec2_instance_ami_id" {
  type        = string
  description = "AMI ID of instances to be launched. Defaults to latest recommended ECS-optimized image."
  default     = null
}

variable "ecs_cluster_min_size" {
  type        = number
  description = "Minimum number of instances in ECS cluster"
  default     = 1
}

variable "ecs_cluster_max_size" {
  type        = number
  description = "Maximum number of instances in ECS cluster"
  default     = 3
}

variable "az_count" {
  type        = number
  description = "Number of availability zones to utilize. Capped at AZ count of the region."
  default     = 2
}

variable "provisioner_aws_account_id" {
  type        = string
  description = "AWS Account ID where the provisioner is running. Used to set up AssumeRole permission. Defaults to current account."
  default     = null
}
