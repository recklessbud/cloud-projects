variable "aws_region" {
  description = "aws region"
  type = string
}

variable "project_name" {
  description = "the project name"
  type = string
}
variable "vpc_cidr_block" {
  type = string
}

variable "public_subnets_cidr" {
  type = list(string)
}


variable "enable_flow_logs" {
  type = bool
  default = false
}

variable "log_retention_days" {
  description = "log rentention days before rm"
  type = number
}
variable "environment" {
  type = string
}
