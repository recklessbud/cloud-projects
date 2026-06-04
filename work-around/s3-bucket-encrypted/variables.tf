variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"

}


variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}