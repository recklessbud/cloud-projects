module "vpc" {
  source              = "./modules/vpc"
  aws_region          = var.aws_region
  environment         = var.environment
  project_name        = var.project_name
  vpc_cidr_block      = var.vpc_cidr_block
  public_subnets_cidr = var.public_subnets_cidr
  log_retention_days  = var.log_retention_days
}



module "IAM" {
  source = "./modules/IAM"
}

module "security_group" {
  source              = "./modules/security-group"
  project_name        = var.project_name
  vpc_id              = module.vpc.vpc_id
  container_port      = var.container_port
  allowed_cidr_blocks = var.allowed_cidr_blocks
}

module "container_fargate" {
  source                 = "./modules/containers-fargate"
  aws_region             = var.aws_region
  project_name           = var.project_name
  environment            = var.environment
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = module.vpc.public_subnet_ids
  enable_ecr_scan        = var.enable_ecr_scan
  task_cpu               = var.task_cpu
  task_memory            = var.task_memory
  task_role_arn          = module.IAM.ecs_execution_role_arn
  execution_role_arn     = module.IAM.ecs_execution_role_arn
  ecs_log_group_name     = module.vpc.ecs_log_group_name
  desired_count          = var.desired_count
  fargate_security_group = module.security_group.fargate_security_group
  health_check_path      = var.health_check_path
  container_port         = var.container_port
  container_image = var.container_image
}