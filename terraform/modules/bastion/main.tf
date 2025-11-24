###############################################
# modules/bastion/main.tf
# Bastion EC2 + Nginx Reverse Proxy
###############################################

variable "project_name" {}
variable "public_subnet" {}
variable "bastion_sg" {}
variable "instance_type" {}
variable "ami" {}
variable "key_name" {}

###############################################
# Bastion EC2 Instance
###############################################

resource "aws_instance" "bastion" {
  ami               = var.ami
  instance_type     = var.instance_type
  subnet_id         = var.public_subnet
  vpc_security_group_ids = [var.bastion_sg]
  key_name          = var.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y nginx

systemctl enable nginx
systemctl start nginx

EOF

  tags = {
    Name = "${var.project_name}-bastion"
    Role = "bastion"
    Environment = "prod"
  }
}

###############################################
# OUTPUTS
###############################################

output "bastion_public_ip" {
  description = "Public IP of bastion"
  value       = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  description = "Private IP of bastion"
  value       = aws_instance.bastion.private_ip
}
