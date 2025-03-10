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
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_ecs_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_ssm_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_cloudwatch_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
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
}

data "aws_iam_policy_document" "ecs_task_execution_role_ecs_inline_policy" {
  version = "2012-10-17"

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_role_ecs_inline_policy" {
  name   = "create-log-groups-policy"
  role   = aws_iam_role.ecs_task_execution_role.id
  policy = data.aws_iam_policy_document.ecs_task_execution_role_ecs_inline_policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_ecs_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
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
}

data "aws_iam_policy_document" "worker_provisioner_ecs_policy" {
  version = "2012-10-17"

  statement {
    effect = "Allow"
    actions = [
      "ecs:RunTask",
      "ecs:StartTask",
      "ecs:DescribeClusters",
      "ecs:ListTasks",
      "ecs:RegisterTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:ListContainerInstances",
      "ecs:StopTask",
      "ecs:DescribeTasks",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "worker_provisioner_ecs_policy" {
  name   = "ecs-policy"
  role   = aws_iam_role.worker_provisioner_role.id
  policy = data.aws_iam_policy_document.worker_provisioner_ecs_policy.json
}

data "aws_iam_policy_document" "worker_provisioner_iam_policy" {
  version = "2012-10-17"

  statement {
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:PassRole",
    ]
    resources = [
      aws_iam_role.ecs_task_execution_role.arn,
      aws_iam_role.ecs_robot_task_role.arn,
    ]
  }
}

resource "aws_iam_role_policy" "worker_provisioner_iam_policy" {
  name   = "iam-policy"
  role   = aws_iam_role.worker_provisioner_role.id
  policy = data.aws_iam_policy_document.worker_provisioner_iam_policy.json
}
