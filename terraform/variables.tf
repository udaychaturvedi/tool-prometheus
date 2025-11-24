###############################################
# variables.tf
###############################################

variable "project_name" {
  description = "Name prefix for all resources"
  default     = "tool-prometheus"
}

variable "aws_region" {
  description = "AWS region for all resources"
  default     = "ap-south-1"
}

variable "ami" {
  description = "Ubuntu AMI for EC2 instances"
  default     = "ami-0ade68f094cc81635"
}

variable "key_name" {
  description = "SSH key pair name (without .pem)"
  default     = "prometheus"
}

# Instance types
variable "bastion_instance_type" {
  default = "t3.micro"
}

variable "tools_instance_type" {
  default = "t3.medium"
}

# VPC CIDR blocks
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
}

variable "private_subnets" {
  default = [
    "10.0.101.0/24",
    "10.0.102.0/24"
  ]
}

variable "azs" {
  default = [
    "ap-south-1a",
    "ap-south-1b"
  ]
}

# Your public IP for SSH
variable "my_ip" {
  description = "Your public IPv4 address CIDR"
  type        = string
  default     = "49.36.242.28/32"
}

variable "tools_desired_capacity" {
  default = 2
}

variable "tools_min_size" {
  default = 2
}

variable "tools_max_size" {
  default = 4
}

