# networking.tf

# 1. Base VPC Layout
resource "aws_vpc" "data_platform_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${terraform.workspace}-data-platform-vpc" }
}

# 2. Private Subnet for Compute Clusters (Databricks/Airflow)
resource "aws_subnet" "private_compute_a" {
  vpc_id            = aws_vpc.data_platform_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "${terraform.workspace}-private-compute-1a" }
}

# 3. Route Table for Private Subnets
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.data_platform_vpc.id
  tags   = { Name = "${terraform.workspace}-private-rt" }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_compute_a.id
  route_table_id = aws_route_table.private_rt.id
}

# 4. S3 VPC Gateway Endpoint (Routes traffic internally to your S3 storage tiers)
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id            = aws_vpc.data_platform_vpc.id
  service_name      = "com.amazonaws.us-east-1s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_rt.id]
  tags              = { Name = "${terraform.workspace}-s3-vpc-endpoint" }
}
