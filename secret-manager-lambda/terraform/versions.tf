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

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}



provider "aws" {

  default_tags {
    tags = {
      Project   = "SecretManagementDemo"
      ManagedBy = "Terraform"
      Recipe    = "basic-secret-management-secrets-lambda"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}