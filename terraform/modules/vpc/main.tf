###############################################
# modules/vpc/main.tf
###############################################

variable "project_name" {}
variable "vpc_cidr" {}
variable "public_subnets" { type = list(string) }
variable "private_subnets" { type = list(string) }
variable "azs" { type = list(string) }

###############################################
# VPC
###############################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

###############################################
# Internet Gateway
###############################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

###############################################
# Public Subnets
###############################################
resource "aws_subnet" "public" {
  for_each = toset(var.public_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = var.azs[0]

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${replace(each.value, "/", "-")}"
    Type = "public"
  }
}

###############################################
# Private Subnets
###############################################
resource "aws_subnet" "private" {
  for_each = toset(var.private_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = var.azs[0]   # FIX: Same AZ as bastion/NAT

  tags = {
    Name = "${var.project_name}-private-${replace(each.value, "/", "-")}"
    Type = "private"
  }
}

###############################################
# NAT Gateway (for private → internet)
###############################################

# Allocate EIP
resource "aws_eip" "nat_eip" {

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# NAT gateway in first public subnet
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(values(aws_subnet.public)[*].id, 0)

  tags = {
    Name = "${var.project_name}-nat"
  }
}

###############################################
# Route Tables
###############################################

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associate public subnets
resource "aws_route_table_association" "public_assoc" {
  for_each = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Associate private subnets
resource "aws_route_table_association" "private_assoc" {
  for_each = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

###############################################
# Outputs
###############################################

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnets" {
  value = [for s in aws_subnet.private : s.id]
}

