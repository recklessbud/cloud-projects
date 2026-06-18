
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  resource_suffix = random_id.suffix.hex
}



resource "aws_s3_bucket" "CDP_bucket" {
  bucket = "cdp-bucket-${local.resource_suffix}"
  force_destroy = true

  tags = {
    Name = "Cloudtrail detection pipeline storage"
    Description =  "Bucket for cloudtrail detection pipeline"
}
}

resource "aws_s3_bucket_public_access_block" "CDP_bucket_access_block" {
    bucket = aws_s3_bucket.CDP_bucket.id
    
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}


resource "aws_s3_bucket_server_side_encryption_configuration" "CDP_bucket_encryption" {
  bucket = aws_s3_bucket.CDP_bucket.id
  rule {
      apply_server_side_encryption_by_default {
          sse_algorithm = "AES256"
      }
  }
}


resource "aws_s3_bucket_versioning" "CDP_bucket_versioning" {
  bucket = aws_s3_bucket.CDP_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
  
}



resource "aws_s3_bucket_lifecycle_configuration" "logs_lifecycle" {
  bucket = aws_s3_bucket.detection_logs.id

  rule {
    id     = "archive-logs"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}



# function to assume a role
resource "aws_iam_role" "lambda_exec_role" {
    name = "lambda_exec_role-${local.resource_suffix}"

    assume_role_policy = jsonencode({
        version = "2012-10-17"
        statement = [
            {
                effect = "Allow"
                principal = {
                    service = "lambda.amazonaws.com"
                }
                action = "sts:AssumeRole"
            }
        ]
    })

    tags = {
        Name = "Lambda execution role"
        Description = "Role for lambda execution to assume"
    }
}