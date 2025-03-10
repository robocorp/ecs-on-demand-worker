data "aws_caller_identity" "current" {
}

/**
 * Instance profile passes the IAM role to an EC2 instance when it starts.
 */
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.id}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

/**
 * This role is attached to the EC2 host machines.
 */
resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.id}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
}

/**
 * This role is used _within_ the robot run on ECS i.e. it
 * is the effective role during the robot run.
 */
resource "aws_iam_role" "ecs_robot_task_role" {
  name = "${var.id}-robot-role"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.id}-ecs-task-execution-role"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "create-log-groups-policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "logs:CreateLogGroup"
          ]
          Resource = "*"
        }
      ]
    })
  }

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}

/**
 * This role is assumed by the worker provisioner component responsible
 * for launching containers.
 */
resource "aws_iam_role" "worker_provisioner_role" {
  name = "${var.id}-provisioner-role"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${coalesce(var.provisioner_aws_account_id, data.aws_caller_identity.current.account_id)}:root",
          ]
        }
      },
    ]
  })

  inline_policy {
    name = "ecs-policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "ecs:RunTask",
            "ecs:StartTask",
            "ecs:DescribeClusters",
            "ecs:ListTasks",
            "ecs:RegisterTaskDefinition",
            "ecs:DeregisterTaskDefinition",
            "ecs:DescribeTaskDefinition",
            "ecs:ListContainerInstances",
            "ecs:StopTask",
            "ecs:DescribeTasks"
          ]
          Resource = "*"
        }
      ]
    })
  }

  inline_policy {
    name = "iam-policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "iam:GetRole",
            "iam:PassRole"
          ]
          Resource = [
            aws_iam_role.ecs_task_execution_role.arn,
            aws_iam_role.ecs_robot_task_role.arn,
          ]
        }
      ]
    })
  }
}

