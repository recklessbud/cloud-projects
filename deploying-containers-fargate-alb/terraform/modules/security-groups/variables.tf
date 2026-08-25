variable "vpc_id" {
  description = "vpc id"
  type = string
}

variable "project_name" {
  type = string
}

variable "allowed_cidr_blocks" {
  type = list(string)
}


variable "alb_name" {
    type = string
}

variable "fargate_service"{
    type = string
}

variable "container_port" {
    type = number
}