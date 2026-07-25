# main config for vpc creaion

data "aws_caller_identity" "current" {}

resource "aws_vpc" "fargate_vpc" {
    cidr_block = var.vpc_cidr_block
    enable_dns_hostnames = true
    enable_dns_support = true

    tags = {
        Name = "${var.project_name}-vpc"
    }
}


resource "aws_subnet" "fargate_subnet" {
    count = length(var.public_subnets_cidr)
    cidr_block = var.public_subnets_cidr[count.index]
    vpc_id = aws_vpc.fargate_vpc.id
    availability_zone = "${var.aws_region}${["a", "b"][count.index]}"
    map_public_ip_on_launch = true

    tags = {
        Name = "${var.project_name}-public-subnet-${count.index + 1}"
    }
}


resource "aws_internet_gateway" "fargate_vpc_igw" {
  vpc_id = aws_vpc.fargate_vpc.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}



resource "aws_eip" "SLZ_eip" {
  domain = "vpc"
  depends_on = [ aws_internet_gateway.fargate_vpc_igw ]
  tags = {
    Name = "${var.project_name}-eip"
  }
}


resource "aws_route_table" "fargate_vpc_rt" {
  vpc_id = aws_vpc.fargate_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.fargate_vpc_igw.id
  }
  tags = {
    Name = "${var.project_name}-pub-rt"
  }
}


resource "aws_route_table_association" "fargate_vpc_rtb_association" {
    count = length(var.public_subnets_cidr)
    subnet_id = aws_subnet.fargate_subnet[count.index].id
    route_table_id = aws_route_table.fargate_vpc_rt.id
}


resource "aws_cloudwatch_log_group" "fargate_cloud_watch" {
  name              = "/aws/cloudtrail/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-cloudtrail-logs"
  }
}