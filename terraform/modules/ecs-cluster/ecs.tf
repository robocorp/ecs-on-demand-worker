resource "aws_security_group" "ecs_instance" {
  name = "${var.id}-ecs-instance"
  description = "Security group for ECS instances"
  vpc_id      = aws_vpc.vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.id}-ecs-instance"
  }
}

data "aws_ssm_parameter" "recommended_ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}

locals {
  recommended_ecs_ami_id = jsondecode(data.aws_ssm_parameter.recommended_ecs_ami.value)
}

resource "aws_launch_template" "ecs_instance_template" {
  name = "${var.id}-ecs-instance"
  instance_type = var.ec2_instance_type
  image_id = coalesce(var.ec2_instance_ami_id, nonsensitive(local.recommended_ecs_ami_id.image_id))

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_instance_profile.arn
  }

  update_default_version = true

  user_data = base64encode(
    templatefile("${path.module}/data/ec2-userdata.sh.tpl", {
      cluster_name = var.id
    })
  )

  network_interfaces {
    associate_public_ip_address = false
    security_groups = [aws_security_group.ecs_instance.id]
    delete_on_termination = true
  }

  monitoring {
    enabled = true
  }
}

resource "aws_placement_group" "ecs_asg" {
  name     = "${var.id}-ecs-instances-placement-group"
  strategy = "partition"
}

resource "aws_autoscaling_group" "ecs_asg" {
  name = "${var.id}-ecs-autoscaling-group"
  min_size = var.ecs_cluster_min_size
  max_size = var.ecs_cluster_max_size
  desired_capacity = 0 # Set to zero, let ECS manage it
  vpc_zone_identifier = aws_subnet.private_subnets.*.id
  protect_from_scale_in = true

  launch_template {
    id = aws_launch_template.ecs_instance_template.id
    version = "$Latest"
  }

  lifecycle {
    # capacity configuration may be adjusted outside terraform,
    # avoid touching it after the initial provisioning.
    ignore_changes = [desired_capacity, min_size, max_size]
    create_before_destroy = true
  }

  tag {
    key = "Name"
    value = var.id
    propagate_at_launch = true
  }

  tag {
    key = "AmazonECSManaged"
    value = true
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "ecs_asg_provider" {
  name = var.id

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn
    managed_termination_protection = "ENABLED"
    managed_scaling {
      status = "ENABLED"
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 1
      target_capacity = 80
    }
  }
}

resource "aws_ecs_cluster" "cluster" {
  name = var.id

  setting {
    name = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "cluster" {
  cluster_name = aws_ecs_cluster.cluster.name

  capacity_providers = [aws_ecs_capacity_provider.ecs_asg_provider.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_asg_provider.name
    weight            = 1
  }
}
