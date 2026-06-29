variable "aws_region" {
  description = "aws_region"
  type        = string
  default     = "us-east-1"
}


variable "environment" {
  description = "env(dev, prod, stage)"
  type        = string
  default     = "dev"
}



variable "project_name" {
  description = "project name"
  type        = string
  default     = "auto-remediation"
}

variable "alert_email" {
  type        = string
  description = "alert email for sns"
}