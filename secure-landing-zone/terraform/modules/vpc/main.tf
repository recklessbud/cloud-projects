# main config for vpc


resource "aws_vpc" "SLZ_vpc" {
    cidr_block = var.vpc_cidr_block
    enable_dns_hostnames = true
    enable_dns_support = true

    tags = {
      Name = "${var.project_name}-vpc"

    }
}


resource "aws_subnet" "SLZ_pub_subnet" {
  count = length(var.public_subnets_cidr)
  cidr_block = var.public_subnets_cidr[count.index]
  vpc_id = aws_vpc.SLZ_vpc.id
  availability_zone = "${var.aws_region}${["a", "b"][count.index]}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}




resource "aws_subnet" "SLZ_priv_subnet" {
  count = length(var.private_subnets_cidr)
  cidr_block = var.private_subnets_cidr[count.index]
  vpc_id = aws_vpc.SLZ_vpc.id
  availability_zone = "${var.aws_region}${["a", "b"][count.index]}"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}



resource "aws_internet_gateway" "SLZ_igw" {
  vpc_id = aws_vpc.SLZ_vpc.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}



resource "aws_eip" "SLZ_eip" {
  domain = "vpc"
  depends_on = [ aws_internet_gateway.SLZ_igw ]
  tags = {
    Name = "${var.project_name}-eip"
  }
}


resource "aws_nat_gateway" "SLZ_natgw" {
  allocation_id = aws_eip.SLZ_eip.id
  subnet_id = aws_subnet.SLZ_pub_subnet[0].id
  depends_on = [ aws_internet_gateway.SLZ_igw ]
  tags = {
    Name = "${var.project_name}-natgw"
  }
}



resource "aws_route_table" "SLZ_pub_rt" {
  vpc_id = aws_vpc.SLZ_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.SLZ_igw.id
  }
  tags = {
    Name = "${var.project_name}-pub-rt"
  }
}


resource "aws_route_table" "SLZ_priv_rt" {
    vpc_id = aws_vpc.SLZ_vpc.id
    route  {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_nat_gateway.SLZ_natgw.id
    }
    tags = {
        Name = "${var.project_name}-priv-rt"
    }
}


resource "aws_route_table_association" "SLZ_pub_rt_association" {
    count = length(var.public_subnets_cidr)
    subnet_id = aws_subnet.SLZ_pub_subnet[count.index].id
    route_table_id = aws_route_table.SLZ_pub_rt.id
}


resource "aws_route_table_association" "SLZ_priv_rt_association" {
    count = length(var.private_subnets_cidr)
    subnet_id = aws_subnet.SLZ_priv_subnet[count.index].id
    route_table_id = aws_route_table.SLZ_priv_rt.id
  
}



resource "aws_flow_log" "SLZ_vpc_flow_logs" {
    count = var.enable_flow_logs ? 1 : 0
    traffic_type = "ALL"
    log_destination_type = "s3"
    log_destination = aws_s3_bucket.SLZ_flow_logs_bucket.arn
    vpc_id = aws_vpc.SLZ_vpc.id

    depends_on = [ 
        aws_s3_bucket_server_side_encryption_configuration.SLZ_flow_logs_bucket_encryption,
        aws_s3_bucket_public_access_block.SLZ_flow_logs_bucket_access_block
     ]
}

resource "aws_s3_bucket" "SLZ_flow_logs_bucket" {
    bucket = "${var.project_name}-flow-logs"
    force_destroy = true
}


resource "aws_s3_bucket_server_side_encryption_configuration" "SLZ_flow_logs_bucket_encryption" {
    bucket = aws_s3_bucket.SLZ_flow_logs_bucket.id
    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }
}


resource "aws_s3_bucket_public_access_block" "SLZ_flow_logs_bucket_access_block" {
    bucket = aws_s3_bucket.SLZ_flow_logs_bucket.id
    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
}