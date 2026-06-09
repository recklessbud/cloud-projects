variable "aws_region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "public_subnets_cidr" {
  type = list(string)
}

variable "private_subnets_cidr" {
  type = list(string)
}

variable "enable_flow_logs" {
  type = bool
  default = false
}

variable "environment" {
  type = string
}
