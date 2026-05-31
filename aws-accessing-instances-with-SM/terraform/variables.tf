# variables configuration for terraform
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "SessionManagerDemo"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}


variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
  validation {
    condition     = can(regex("^[a-z][0-9][a-z]?\\.(nano|micro|small|medium|large|xlarge|[0-9]+xlarge)$", var.instance_type))
    error_message = "Instance type must be a valid EC2 instance type (e.g., t2.micro, m5.large)."
  }
}


variable "enable_logging" {
  description = "Enable CloudWatch Logs for Session Manager"
  type        = bool
  default     = true
}


variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}


variable "s3_log_prefix" {
  description = "S3 key prefix for session logs"
  type        = string
  default     = "session-logs/"
}

variable "allowed_users" {
  description = "List of IAM users/roles allowed to start sessions"
  type        = list(string)
  default     = []
}

variable "instance_tags" {
  description = "Additional tags to apply to EC2 instances"
  type        = map(string)
  default = {
    Purpose = "SessionManagerTesting"
  }
}

variable "vpc_id" {
  description = "VPC ID to deploy the instance into (optional - uses default VPC if not specified)"
  type        = string
  default     = null
}


variable "subnet_id" {
  description = "Subnet ID to deploy the instance into (optional - uses default subnet if not specified)"
  type        = string
  default     = null
}

variable "enable_cloudtrail_logging" {
  description = "Enable CloudTrail logging for Session Manager API calls"
  type        = bool
  default     = true
}

variable "kms_key_deletion_window" {
  description = "Number of days to wait before deleting KMS key"
  type        = number
  default     = 7

  validation {
    condition     = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "KMS key deletion window must be between 7 and 30 days."
  }
}


variable "vpc_cidr_block" {
  description = "Main cidr for the VPC"
  type        = string
  default     = "192.168.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "Must be a valid CIDR block"
  }
}



variable "subnet_cidr_block" {
  description = "Main cidr for the subnet"
  type        = string
  default     = "192.168.1.0/24"

  validation {
    condition     = can(cidrhost(var.subnet_cidr_block, 0))
    error_message = "Must be a valid CIDR block for the subnet"
  }
}