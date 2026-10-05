resource "random_string" "suffix" {
  length = 8
  special = false
  upper = false
}


# ECR repository
resource "aws_ecr_repository" "ecr_repository" {
  name = "fargate-serverless-repo-${random_string.suffix.result}"
  image_tag_mutability = var.ecr_image_tag_mutability
  image_scanning_configuration {
    scan_on_push = var.ecr_scan_on_push
  }
  encryption_configuration {
    encryption_type = var.ecr_encryption_type
  }
}


resource "aws_ecr_lifecycle_policy" "ecr_lifecycle_policy" {
  repository = aws_ecr_repository.ecr_repository.name

  policy = jsonencode ({
    rules = [
        {
            rulePriority = 1
            description = "Keep last 10 images"
            action = {
                type = "expire"
            }
            selection = {
                tagStatus = "tagged"
                tagPrefixList = ["v"]
                countType = "imageCountMoreThan"
                countNumber = 10
            }
        },
        {
            rulePriority = 2
            description = "Delete untagged images older than 1 day"
            action = {
                type = "expire"
            }
            selection = {
                tagStatus = "untagged"
                countType = "sinceImagePushed"
                countUnit = "days"
                countNumber = 5
            }
        }
    ]
  })  
  
  }


resource "aws_ecs_cluster" "ecs_cluster" {
 name = "${var.cluster_name}-${random_string.suffix.result}"
 
 setting {
   name = "containerInsights"
   value = "enabled"
 }
 tags = {
     Name = "${var.cluster_name}-${random_string.suffix.result}"
 } 

}


resource "aws_ecs_cluster_capacity_providers" "ecs_cluster_capacity_provider" {
  cluster_name = aws_ecs_cluster.ecs_cluster.name
  capacity_providers =  var.enable_fargate_spot ? ["FARGATE", "FARGATE_SPOT"] : ["FARGATE"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight = var.fargate_weight
    base = var.fargate_base
  }

  dynamic "default_capacity_provider_strategy" {
    for_each = var.enable_fargate_spot ? [1] : []
    content {
      capacity_provider = "FARGATE_SPOT"
      weight = var.fargate_spot_weight
    #   base = var.fargate_spot_base
    }
  }
}

  
resource "aws_ecs_task_definition" "ecs_task_definition" {
  family = "${var.task_definition_family}-${random_string.suffix.result}"
  task_role_arn = var.task_role_arn
  execution_role_arn = var.execution_role_arn
  network_mode = "awsvpc"
  cpu = var.container_cpu
  memory = var.container_memory
  requires_compatibilities = ["FARGATE"]


  container_definitions = jsonencode([
    {
        name = "fargate-demo-container"
        image = "301301200252.dkr.ecr.us-east-1.amazonaws.com/fargate-serverless-repo-8wclgzy1:latest"
        essential = true

        portMappings = [
            {
                containerPort = 3000
                protocol = "tcp"
            }
        ]

    environment = [
        for key, value in var.container_environment_variables : {
          name  = key
          value = value
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.cloudwatch_log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential= true

       healthCheck = {
        command = [
          "CMD-SHELL",
          "wget -q -O /dev/null http://127.0.0.1:${var.container_port}${var.health_check_path} || exit 1"
          # "wget -q -o /dev/null  http://localhost:${var.container_port} || exit 1"
        ]
        interval    = var.health_check_interval
        timeout     = var.health_check_timeout
        retries     = var.health_check_unhealthy_threshold
        startPeriod = 60
      }
    }
  ])

}


resource "aws_ecs_service" "ecs_service" {
  name = "${var.service_name}-${random_string.suffix.result}"
  cluster = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count = var.desired_count
  launch_type = "FARGATE"
  platform_version = "1.4.0"

  network_configuration {
    subnets = var.subnet_ids
    assign_public_ip = true
    security_groups = [var.fargate_sg_id]
  
  }


  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name = "fargate-demo-container"
    container_port = 3000
  }

  health_check_grace_period_seconds = var.health_check_grace_period


 enable_execute_command = var.enable_execute_command

  depends_on = [
    var.fargate_listener
  ]
}