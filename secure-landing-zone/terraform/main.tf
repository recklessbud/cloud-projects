# main configurations


module "vpc" {
  source = "./modules/vpc"

  aws_region           = var.aws_region
  environment          = var.environment
  project_name         = var.project_name
  vpc_cidr_block       = var.vpc_cidr_block
  public_subnets_cidr  = var.public_subnets_cidr
  private_subnets_cidr = var.private_subnets_cidr
  enable_flow_logs     = var.enable_flow_logs
}



module "security" {
  source = "./modules/security"

  aws_region     = var.aws_region
  vpc_id         = module.vpc.vpc_id
  project_name   = var.project_name
  vpc_cidr_block = var.vpc_cidr_block

  allowed_ssh_cidr = var.allowed_ssh_cidr
}