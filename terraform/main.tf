terraform {
  required_version = "~> 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "ecs_cluster_1" {
  source = "./modules/ecs-cluster"
  id     = "${var.id}-cluster-1"
}

module "eventbridge" {
  source = "./modules/eventbridge"
  id     = var.id
  eventbridge_external_in_allowed_source_rule_arns = [
    // Update this according to instructions here: https://robocorp.com/docs/control-room/aws-integrations/eventbridge#configuration
    "arn:aws:events:eu-west-1:827142569422:rule/demo-customer-integration/org-0f9993a1-92e4-4b4d-8ff7-07f1ea39dfaf",
    "arn:aws:events:us-east-1:312661337933:rule/us1-customer-integration/org-2db51ec1-a021-4142-a3af-3e1b46ebc7c7",
  ]
}

resource "aws_ecr_repository" "worker_images" {
  name = "${var.id}-worker-images"
  // For optimum robot start speed we want to cache the images on EC2,
  // machines, immutable tags help avoid invalidation challenges.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
