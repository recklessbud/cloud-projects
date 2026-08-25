variable "alb_name" {
  type = string
}


variable "alb_internal" {
    type = bool
}

variable "alb_sg_id" {
    type = string
}

variable "subnet_ids"{
    type = list(string)
}

variable "alb_deletion_protection" {
    type = bool
}

variable "container_port" {
    type = number
}


variable "vpc_id" {
    type = string
}

variable "health_check_unhealthy_threshold" {
  type = number
}

variable "health_check_healthy_threshold" {
  type = number
}


variable "health_check_interval" {
  type = number
}


variable "health_check_path" {
  type = string
}


variable "health_check_timeout" {
  type = number
}

variable "enable_auto_scaling" {
  type = bool
}

variable "max_capacity" {
  type = number
}

variable "min_capacity" {
  type = number
}

variable "service_name" {
  type = string
}


variable "scale_out_cooldown" {
  type = number
}

variable "scale_in_cooldown" {
  type = number
}

variable "cpu_target_value" {
  type = number
}

# variable "enable_auto_scaling" {
#   type = bool
# }


variable "memory_target_value" {
  type = number
}