
module "vpc" {
  source = "../../running-containers-fargate/terraform/modules/vpc"

  log_retention_days  = var.log_retention_days
  aws_region          = var.aws_region
  environment         = var.environment
  project_name        = var.project_name
  public_subnets_cidr = var.public_subnets_cidr
  vpc_cidr_block      = var.vpc_cidr_block

}