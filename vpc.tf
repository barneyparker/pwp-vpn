# VPC
resource "aws_vpc" "vpn_vpc" {
  cidr_block           = "10.0.0.0/24" # Larger CIDR to accommodate multiple subnets
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Internet Gateway
resource "aws_internet_gateway" "vpn_igw" {
  vpc_id = aws_vpc.vpn_vpc.id
}

# Data source to get all available AZs
data "aws_availability_zones" "available" {
  state = "available"
}



# Calculate number of AZs and subnet size
locals {
  all_azs = data.aws_availability_zones.available.names
  # Limit to maximum 6 AZs for safety and practicality
  # /24 VPC with /28 subnets can support up to 16 subnets, so 6 is very safe
  max_azs_to_use = 6
  az_count       = min(length(local.all_azs), local.max_azs_to_use)
  azs            = slice(local.all_azs, 0, local.az_count)

  # Each subnet gets a /28 (16 IPs) from the /24 VPC CIDR
  subnet_cidr_bits = 4 # This gives us /28 subnets from /24 VPC
}

# Public Subnets - one per AZ (up to max_azs_to_use)
resource "aws_subnet" "vpn_public_subnets" {
  count = local.az_count

  vpc_id                  = aws_vpc.vpn_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.vpn_vpc.cidr_block, local.subnet_cidr_bits, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
}

# Route Table
resource "aws_route_table" "vpn_public_rt" {
  vpc_id = aws_vpc.vpn_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpn_igw.id
  }
}

# Route Table Associations - one per subnet
resource "aws_route_table_association" "vpn_public_rta" {
  count = local.az_count

  subnet_id      = aws_subnet.vpn_public_subnets[count.index].id
  route_table_id = aws_route_table.vpn_public_rt.id
}

# Elastic IP for persistent public IP address
resource "aws_eip" "vpn_eip" {
  domain = "vpc"

  # Ensure the EIP is created before the internet gateway
  depends_on = [aws_internet_gateway.vpn_igw]

  tags = {
    Name = "pwp-vpn-eip"
  }
}
