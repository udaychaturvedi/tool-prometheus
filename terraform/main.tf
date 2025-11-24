###############################################
# main.tf
###############################################

provider "aws" {
  region = var.aws_region
}

# VPC module (simple reusable module expected under modules/vpc)
module "vpc" {
  source          = "./modules/vpc"
  project_name    = var.project_name
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  azs             = var.azs
}

# Security module (security groups for bastion and private)
module "security" {
  source       = "./modules/security"
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  my_ip        = var.my_ip
  vpc_cidr     = var.vpc_cidr
}

# Bastion + Nginx EC2 (public subnet)
module "bastion" {
  source        = "./modules/bastion"
  project_name  = var.project_name
  public_subnet = module.vpc.public_subnets[0]
  bastion_sg    = module.security.bastion_sg
  instance_type = var.bastion_instance_type
  ami           = var.ami
  key_name      = var.key_name
}

output "bastion_public_ip" {
  description = "Public IP of bastion/nginx instance (use for SSH)"
  value       = module.bastion.bastion_public_ip
}


module "storage" {
  source       = "./modules/storage"
  project_name = var.project_name
  region       = var.aws_region
}


# Tools AutoScaling Group (Prometheus, Grafana, Alertmanager, node_exporter)
module "tools_asg" {
  source             = "./modules/tools_asg"
  project_name       = var.project_name
  private_subnets    = module.vpc.private_subnets
  security_group_ids = [module.security.private_sg]

  instance_type = var.tools_instance_type
  ami           = var.ami
  key_name      = var.key_name

  desired_capacity = var.tools_desired_capacity
  min_size         = var.tools_min_size
  max_size         = var.tools_max_size
  region           = var.aws_region
  monitoring_s3_policy_arn = module.storage.monitoring_s3_policy_arn

}

output "tools_private_ips" {
  description = "Private IP(s) of tools instance(s)"
  value       = module.tools_asg.tools_private_ips
}
