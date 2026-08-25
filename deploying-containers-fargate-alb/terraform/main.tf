
module "vpc" {
  source = "../../running-containers-fargate/terraform/modules/vpc"

  log_retention_days  = var.log_retention_days
  aws_region          = var.aws_region
  environment         = var.environment
  project_name        = var.project_name
  public_subnets_cidr = var.public_subnets_cidr
  vpc_cidr_block      = var.vpc_cidr_block

}


module "sg" {
  source              = "./modules/security-groups"
  project_name        = var.project_name
  vpc_id              = module.vpc.vpc_id
  allowed_cidr_blocks = var.allowed_cidr_blocks
  container_port      = var.container_port
  alb_name            = var.alb_name
  fargate_service     = var.service_name
}



module "iam" {
  source = "./modules/IAM"
}


module "alb-asg" {
  source                           = "./modules/alb-asg"
  health_check_path                = var.health_check_path
  memory_target_value              = var.memory_target_value
  alb_internal                     = var.alb_internal
  alb_deletion_protection          = var.alb_deletion_protection
  alb_name                         = var.alb_name
  container_port                   = var.container_port
  vpc_id                           = module.vpc.vpc_id
  subnet_ids                       = module.vpc.public_subnet_ids
  cpu_target_value                 = var.cpu_target_value
  health_check_interval            = var.health_check_interval
  health_check_timeout             = var.health_check_timeout
  max_capacity                     = var.max_capacity
  min_capacity                     = var.min_capacity
  health_check_healthy_threshold   = var.health_check_healthy_threshold
  health_check_unhealthy_threshold = var.health_check_unhealthy_threshold
  scale_in_cooldown                = var.scale_in_cooldown
  scale_out_cooldown               = var.scale_out_cooldown
  service_name                     = var.service_name
  enable_auto_scaling              = var.enable_auto_scaling
  alb_sg_id                        = module.sg.alb

}

module "containers" {
  source                           = "./modules/containers"
  cloudwatch_log_group_name        = module.vpc.ecs_log_group_name
  aws_region                       = var.aws_region
  task_role_arn                    = module.iam.ecs_execution_role_arn.arn
  execution_role_arn               = module.iam.ecs_execution_role_arn.arn
  desired_count                    = var.desired_count
  container_image                  = var.container_image
  container_port                   = var.container_port
  enable_execute_command           = var.enable_execute_command
  health_check_grace_period        = var.health_check_grace_period
  fargate_listener                 = module.alb-asg.fargate_listener
  fargate_base                     = var.fargate_base
  fargate_weight                   = var.fargate_weight
  enable_fargate_spot              = var.enable_fargate_spot
  fargate_spot_weight              = var.fargate_spot_weight
  platform_version                 = var.platform_version
  subnet_ids                       = module.vpc.public_subnet_ids
  container_cpu                    = var.container_cpu
  health_check_interval            = var.health_check_interval
  service_name                     = var.service_name
  ecr_image_tag_mutability         = var.ecr_image_tag_mutability
  health_check_unhealthy_threshold = var.health_check_unhealthy_threshold
  project_name                     = var.project_name
  ecr_scan_on_push                 = var.ecr_scan_on_push
  ecr_encryption_type              = var.ecr_encryption_type
  alb_target_group_arn             = module.alb-asg.alb_target_group_arn
  container_environment_variables  = var.container_environment_variables
  fargate_sg_id                    = module.sg.fargate_security_group.id
  container_memory                 = var.container_memory
  health_check_path                = var.health_check_path
  health_check_timeout             = var.health_check_timeout
  task_definition_family           = var.task_definition_family
  cluster_name                     = var.cluster_name
}