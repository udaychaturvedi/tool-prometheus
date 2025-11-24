###############################################
# modules/security/main.tf
# Security Groups for tool-prometheus
###############################################

variable "project_name" {}
variable "vpc_id" {}
variable "my_ip" {}
variable "vpc_cidr" {}

###############################################
# Bastion SG (public)
###############################################
resource "aws_security_group" "bastion_sg" {
  name        = "${var.project_name}-bastion-sg"
  description = "Allow SSH from my IP only"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from My IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Allow HTTP/HTTPS for Nginx reverse proxy (public)
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outgoing anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

###############################################
# Private SG (Prometheus / Grafana / Alertmanager / Node Exporter)
###############################################
resource "aws_security_group" "private_sg" {
  name        = "${var.project_name}-private-sg"
  description = "Private SG for monitoring tools"
  vpc_id      = var.vpc_id

  # Allow all traffic inside VPC
  ingress {
    description = "All inside VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow outgoing
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-private-sg"
  }
}

###############################################
# Outputs
###############################################

output "bastion_sg" {
  value = aws_security_group.bastion_sg.id
}

output "private_sg" {
  value = aws_security_group.private_sg.id
}
