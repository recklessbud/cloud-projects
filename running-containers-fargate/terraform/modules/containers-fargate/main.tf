

resource "random_password" "suffix" {
  length = 7
  special = false
  upper = true
}


data "aws_caller_identity" "current" {}


locals {
  # Use provided subnet IDs or default subnets
  subnet_ids = var.subnet_ids
  
  # Resource naming with random suffix
  cluster_name     = "${var.project_name}-${random_password.suffix.result}"
  repository_name  = "${var.project_name}-app-repo"
  service_name     = "${var.project_name}-service"
  task_family      = "${var.project_name}-task"
  execution_role_name = "ecsTaskExecutionRole-${random_password.suffix.result}"
}


# ECR repository for the app
resource "aws_ecr_repository" "fargate_repo" {
    name =  local.repository_name
    image_tag_mutability = "IMMUTABLE"
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
        name = "containerInsights"
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
        image = var.container_image
        portMappings = [
          {
            containerPort = var.container_port
            protocol = "tcp"
          }
        ]

        essential = true

        healthCheck = {
        command = [
          "CMD-SHELL",
          # "echo ok",
        "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:3000/health')\" || exit 1"
         ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }


        logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.ecs_log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
        tags = {
            Name = local.task_family
        }
    }])
}



# ECS service
resource "aws_ecs_service" "fargate_service" {
    name = local.service_name
    cluster = aws_ecs_cluster.fargate_cluster.id
    task_definition = aws_ecs_task_definition.fargate_task_definition.arn
    desired_count = var.desired_count
    launch_type = "FARGATE"
    
  
    enable_execute_command = true


    network_configuration {
      subnets  = local.subnet_ids

      security_groups = [
        var.fargate_security_group
      ]

      assign_public_ip = true
    }


    # deployment_configuration {
    #   maximum_percent = 200
    #   minimum_healthy_percent = 100
    # }
    
    wait_for_steady_state = true
    health_check_grace_period_seconds = 60


    depends_on = [aws_ecs_cluster_capacity_providers.fargate_cluster_capacity]

  tags = {
    Name = local.service_name
  }
}