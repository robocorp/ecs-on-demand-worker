terraform {
  required_version = "~> 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider aws {
  region = var.aws_region
}

module ecs_cluster_1 {
  source = "./modules/ecs-cluster"
  id = "${var.id}-cluster-1"
}

resource "aws_ecr_repository" "worker_images" {
  name                 = "${var.id}-worker-images"
  // For optimum robot start speed we want to cache the images on EC2,
  // machines, immutable tags help avoid invalidation challenges.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
