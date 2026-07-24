
variable "aws_region" {
  description = "aws region"
  type = string
}

variable "project_name" {
  description = "the project name"
  type = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type = string
}


variable "vpc_id" {
    type = string
}

variable "subnet_ids"{
    type = list(string)
}

variable "enable_ecr_scan" {
    type = bool
}

variable "task_cpu"{
    type = number
}

variable "task_memory"{
    type = number
  
}


variable "execution_role_arn" {
  type = string
}

variable "task_role_arn"{
    type = string
}