

resource "random_password" "suffix" {
  length = 7
  special = false
  upper = true
}


data "aws_caller_identity" "current" {}


locals {
  # Use provided subnet IDs or default subnets
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : data.aws_subnets.default[0].ids
  
  # Resource naming with random suffix
  cluster_name     = "${var.project_name}-${random_password.suffix.result}"
  repository_name  = "${var.project_name}-app-${random_password.suffix.result}"
  service_name     = "${var.project_name}-service"
  task_family      = "${var.project_name}-task"
  execution_role_name = "ecsTaskExecutionRole-${random_password.suffix.result}"
}


# ECR repository for the app
resource "aws_ecr_repository" "fargate_repo" {
    name =  local.repository_name
    image_tag_mutability = "MUTABLE"
    force_delete = true
    image_scanning_configuration {
        scan_on_push = var.enable_ecr_scan
    }
    tags = {
        Name = local.repository_name
    }
}


# ECR repository lifecycle to manage img versions
resource "aws_ecr_lifecycle_policy" "fargate_repo_policy" {
    repository = aws_ecr_repository.fargate_repo.name
    policy = jsonencode({
        rules = [{
            rulePriority = 1
            description = "keep last 10 images"
            selection = {
                tagStatus = "tagged"
                tagPrefixList = ["v"]
                countType = "imageCountMoreThan"
                countNumber = 10
            }
            action = {
                type = "expire"
            }
        },
        {
            rulePriority =  2
            description = "Delete untagged images older than 1 day"
            selection = {
                tagStatus = "untagged"
                countType = "sinceImagePushed"
                countUnit = "days"
                countNumber = 1
            }
            action = {
                type = "expire"
            }
        }
        ]
    })
}


#ECS cluster with fargate
resource "aws_ecs_cluster" "fargate_cluster" {
    name = local.cluster_name

    setting {
        name = "ContainerInsights"
        value = "enabled"
    }

    tags = {
        Name = local.cluster_name
    }
}


# ecs providers
resource "aws_ecs_cluster_capacity_providers" "fargate_cluster_capacity" {
  cluster_name = aws_ecs_cluster.fargate_cluster.name
  capacity_providers = [ "FARGATE", "FARGATE_SPOT" ]

 default_capacity_provider_strategy {
   base = 1
   weight = 100
   capacity_provider = "FARGATE"
 }

}



# ECS Task definition
resource "aws_ecs_task_definition" "fargate_task_definition" {
    family = local.task_family
    network_mode = "awsvpc"
    requires_compatibilities = [ "FARGATE" ]
    cpu = var.task_cpu
    memory = var.task_memory
    execution_role_arn = var.execution_role_arn
    task_role_arn = var.task_role_arn


    container_definitions = jsonencode([{
        name = "${var.project_name}-container"
    }])
}