###############################################
# modules/tools_asg/main.tf
# ASG for Prometheus + Grafana + Alertmanager + Node Exporter
###############################################

variable "project_name" {}
variable "private_subnets" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "instance_type" {}
variable "ami" {}
variable "key_name" {}
variable "desired_capacity" {}
variable "min_size" {}
variable "max_size" {}
variable "region" {}

###############################################
# IAM Role for EC2
###############################################

resource "aws_iam_role" "tools_role" {
  name = "${var.project_name}-tools-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "tools_policy" {
  name = "${var.project_name}-tools-policy"
  role = aws_iam_role.tools_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeInstanceStatus"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "tools_profile" {
  name = "${var.project_name}-tools-profile"
  role = aws_iam_role.tools_role.name
}

###############################################
# Launch Template
###############################################

resource "aws_launch_template" "tools_lt" {
  name_prefix = "${var.project_name}-tools-lt-"

  image_id      = var.ami
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.tools_profile.name
  }

  network_interfaces {
    security_groups             = var.security_group_ids
    associate_public_ip_address = false
  }

  user_data = base64encode(file("${path.module}/userdata/tools_userdata.sh"))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-tools"
      Role        = "tools"
      Environment = "prod"
    }
  }
}

###############################################
# AutoScaling Group
###############################################

resource "aws_autoscaling_group" "tools_asg" {
  name = "${var.project_name}-tools-asg"

  desired_capacity = var.desired_capacity
  min_size         = var.min_size
  max_size         = var.max_size

  vpc_zone_identifier = var.private_subnets

  launch_template {
    id      = aws_launch_template.tools_lt.id
    version = "$Latest"
  }

  health_check_type = "EC2"

  tag {
    key                 = "Role"
    value               = "tools"
    propagate_at_launch = true
  }
}

###############################################
# Output: Private IP(s)
###############################################

data "aws_instances" "tools" {
  depends_on = [aws_autoscaling_group.tools_asg]

  filter {
    name   = "tag:Role"
    values = ["tools"]
  }
}

output "tools_private_ips" {
  description = "Private IPs of tools ASG instances"
  value       = data.aws_instances.tools.private_ips
}

resource "aws_iam_role_policy_attachment" "tools_s3_attach" {
  role       = aws_iam_role.tools_role.name
  policy_arn = var.monitoring_s3_policy_arn
 # or use aws_iam_policy.monitoring_s3_policy.arn if same module
}

