variable "aws_region" {
  description = "ÄWS region"
  type        = string
  default     = "us-east-1"
}


variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}


variable "project_name" {
  description = "the project name"
  type        = string
  default     = "running-containers-fargate"
}


# container and fargate
variable "container_image" {
  description = "container image URI to deploy"
  type        = string
  default     = "nginx:latest"
}

variable "task_cpu" {
  description = "CPU units for the ECS task"
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.task_cpu)
    error_message = "CPU must be one of: 256, 512, 1024, 2048, 4096"
  }
}

variable "task_memory" {
  description = "Memory for the ECS task"
  type        = number
  default     = 512
}




variable "container_port" {
  description = "container port"
  type        = number
  default     = 80
}


variable "desired_count" {
  description = "desired count of tasks"
  type        = number
  default     = 2

  validation {
    condition     = var.desired_count >= 1 && var.desired_count <= 20
    error_message = "Desired count must be between 1 and 20"
  }

}

variable "enable_ecr_scan" {
  description = "Enable vulnerability scanning for ECR images"
  type        = bool
  default     = true
}

# Health check configuration
variable "health_check_path" {
  description = "Path for container health checks"
  type        = string
  default     = "/health"
}




# auto-scaling

variable "min_capacity" {
  description = "Minimum number of tasks for auto-scaling"
  type        = number
  default     = 1

}

variable "max_capacity" {
  description = "Maximum number of tasks for auto-scaling"
  type        = number
  default     = 10

  validation {
    condition     = var.max_capacity >= 1 && var.max_capacity <= 50
    error_message = "Max capacity must be between 1 and 50"
  }
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage for auto-scaling"
  type        = number
  default     = 50

  validation {
    condition     = var.cpu_target_value >= 10 && var.cpu_target_value <= 90
    error_message = "CPU target value must be between 10 and 90"
  }
}



# vpc-configs


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

# Log retention period
variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period"
  }
}
