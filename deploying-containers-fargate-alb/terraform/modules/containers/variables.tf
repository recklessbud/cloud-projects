variable "project_name" {
  type = string
}


variable "ecr_image_tag_mutability" {
  type = string
}

variable "ecr_scan_on_push" {
  type = bool
}

variable "ecr_encryption_type" {
  type = string
}

variable "cluster_name"{
    type = string
}

variable "fargate_weight" {
  type = number
}


variable "fargate_base" {
type = number
}

variable "enable_fargate_spot" {
  type = bool
}

variable "fargate_spot_weight" {
  type = number
}


variable "task_definition_family" {
  type = string
}


variable "container_cpu" {
  type = number
}

variable "container_memory" {
  type = number
}


variable "execution_role_arn" {
  type = string
}


variable "task_role_arn" {
  type = string
}

variable "container_port" {
  type = number
}

variable "container_image" {
  type = string
}


variable "container_environment_variables" {
  type = map(string)
}


variable "aws_region" {
  type = string
}


variable "cloudwatch_log_group_name" {
  type = string
}


variable "health_check_interval" {
  type = number
}

variable "health_check_timeout" {
  type = number
}

variable "health_check_unhealthy_threshold" {
  type = number
}


variable "health_check_path" {
  type = string
}



variable "service_name" {
  type = string
}


variable "desired_count" {
  type = number
}

variable "platform_version" {
type = string
}


variable "subnet_ids" {
  type = list(string)
}

variable "fargate_sg_id" {
    type = string
}

variable "alb_target_group_arn" {
    type = string
}

variable "health_check_grace_period" {
  type = number
}


variable "enable_execute_command" {
  type = bool
}

variable "fargate_listener" {
  type = string
}