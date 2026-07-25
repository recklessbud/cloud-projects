
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

variable "container_image" {
  type = string
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

variable "container_port"{
    type = number
}



variable "health_check_path" {
    type = string
}



variable "ecs_log_group_name" {
    type = string
}


variable "desired_count" {
    type = number
}


variable "fargate_security_group" {
  type = string
}