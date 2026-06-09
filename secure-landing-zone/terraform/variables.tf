# various variables used in the terraform code
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}



variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "env has to be on of(e.g., dev, staging, prod)"
  }
}

variable "project_name" {
  description = "the project name"
  type        = string
  default     = "SomeSecureLandingZone"
}

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



variable "private_subnets_cidr" {
  description = "public subnets"
  type        = list(string)
  default     = ["192.168.101.0/24", "192.168.201.0/24"]

  validation {
    condition = alltrue([
      for cidr in var.private_subnets_cidr : can(cidrhost(cidr, 0))
    ])
    error_message = "must be one of the subnets"
  }
}



variable "enable_flow_logs" {
  description = "flow logs"
  type        = bool
  default     = true

}


variable "flow_logs_retention_in_days" {
  description = "flow logs retention in days"
  type        = number
  default     = 7

  validation {
    condition     = var.flow_logs_retention_in_days >= 1 && var.flow_logs_retention_in_days <= 3650
    error_message = "flow logs retention in days must be between 1 and 3650."
  }
}


variable "additional_tags" {
  description = "just additional tags"
  type        = map(string)
  default     = {}
}


variable "allowed_ssh_cidr" {
  description = "Your IP address for SSH access"
  type        = string
  default     = "154.161.98.163/32"

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "Must be a valid CIDR"
  }
}