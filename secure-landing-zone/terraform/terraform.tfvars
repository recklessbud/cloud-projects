aws_region     = "us-east-1"
environment    = "dev"
project_name   = "secure-landing-zone"
vpc_cidr_block = "192.168.0.0/16"

public_subnets_cidr  = ["192.168.10.0/24", "192.168.20.0/24"]
private_subnets_cidr = ["192.168.101.0/24", "192.168.201.0/24"]

enable_flow_logs = true