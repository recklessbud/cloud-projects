# versions and providers configuration
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}



provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "GuardDutyEventBridgeSNS"
      Environment = var.environment
      ManagedBy   = "Kesmo-Terraform"
    }
  }
}