# default configs
variable "aws_region" {
  description = "aws region"
  type        = string
  default     = "us-east-1"
}


variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "serverless-containers-fargate-application-load-balancer"
  type        = string
  default     = "Fargate-Serverless-Containers"
}


# vpc configs
variable "vpc_cidr_block" {
  description = "VPC cidr block"
  type        = string
  default     = "192.168.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "must be this exact cidr block"
  }
}



variable "public_subnets_cidr" {
  description = "public subnets"
  type        = list(string)
  default     = ["192.168.10.0/24", "192.168.20.0/24"]

  validation {
    condition = alltrue([
      for cidr in var.public_subnets_cidr : can(cidrhost(cidr, 0))
    ])
    error_message = "must be one of the subnets"
  }
}


variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the container port"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.allowed_cidr_blocks) > 0
    error_message = "At least one CIDR block must be specified"
  }
}

# container and fargate configs
variable "container_image" {
  description = "container image URI to deploy"
  type        = string
  default     = "nginx:latest"
}

variable "container_port" {
  description = "container port"
  type        = number
  default     = "80"

  validation {
    condition     = var.container_port > 0 && var.container_port < 65536
    error_message = "must be a valid port number between 1 and 65535"
  }
}

variable "container_cpu" {
  description = "container cpu"
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "container memory"
  type        = number
  default     = 512
}



# ECS configuration
variable "task_cpu" {
  description = "CPU units for the ECS task"
  type        = number
  default     = 256
}


variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = "fargate-cluster"
}


variable "service_name" {
  description = "ECS service name"
  type        = string
  default     = ""
}

variable "desired_count" {
  description = "Number of tasks to run in the ECS service"
  type        = number
  default     = 2
}


variable "task_definition_family" {
  description = "ECS task definition name"
  type        = string
  default     = ""
}

variable "platform_version" {
  description = "ECS platform version"
  type        = string
  default     = "LATEST"
}



# Auto Scaling
variable "enable_auto_scaling" {
  description = "Enable auto scaling"
  type        = bool
  default     = true

}

variable "min_capacity" {
  description = "Minimum capacity for auto scaling"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum capacity for auto scaling"
  type        = number
  default     = 5
}

variable "cpu_target_value" {
  description = "Target CPU utilization for auto scaling"
  type        = number
  default     = 60

}


variable "memory_target_value" {
  description = "Target memory utilization for auto scaling"
  type        = number
  default     = 70
}

variable "scale_in_cooldown" {
  description = "Cooldown period in seconds for scale in operation"
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Cooldown period in seconds for scale out operation"
  type        = number
  default     = 300
}

# ALB configs
variable "alb_name" {
  description = "ALB name"
  type        = string
  default     = "fargate-alb"
}

variable "alb_internal" {
  description = "Alb is internal (true) or internet-facing(false)"
  type        = bool
  default     = false
}

variable "alb_deletion_protection" {
  description = "Enable deletion protection for the ALB"
  type        = bool
  default     = false
}


variable "health_check_path" {
  description = "Health check path for TG"
  type        = string
  default     = "/health"
}


variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive successful health checks before considering target healthy"
  type        = number
  default     = 2
}


variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive failed health checks before considering target unhealthy"
  type        = number
  default     = 3
}

variable "health_check_grace_period" {
  description = "Health check grace period in seconds"
  type        = number
  default     = 120
}


# ECR Configuration
variable "ecr_repository_name" {
  description = "Name of the ECR repository (if not provided, generates unique name)"
  type        = string
  default     = ""
}

variable "ecr_image_tag_mutability" {
  description = "Image tag mutability setting for ECR repository"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.ecr_image_tag_mutability)
    error_message = "Image tag mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "ecr_scan_on_push" {
  description = "Enable image scanning on push to ECR"
  type        = bool
  default     = true
}

variable "ecr_encryption_type" {
  description = "Encryption type for ECR repository"
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "KMS"], var.ecr_encryption_type)
    error_message = "Encryption type must be either AES256 or KMS."
  }
}





# Security Configuration
variable "enable_execute_command" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = false
}

variable "enable_fargate_spot" {
  description = "Enable Fargate Spot capacity provider"
  type        = bool
  default     = true
}

variable "fargate_spot_weight" {
  description = "Weight for Fargate Spot capacity provider"
  type        = number
  default     = 4
}

variable "fargate_weight" {
  description = "Weight for regular Fargate capacity provider"
  type        = number
  default     = 1
}


variable "fargate_base" {
  description = "Base number of tasks to run on regular Fargate"
  type        = number
  default     = 1
}







# cloudwatch log configs
variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period"
  }
}



# Additional Environment Variables
variable "container_environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default = {
    NODE_ENV = "production"
    PORT     = "3000"
  }
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}