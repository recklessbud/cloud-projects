

data "aws_caller_identity" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  resource_suffix = random_id.suffix.hex
  common_tags = {
    Project     = "EncryptedS3Bucket"
    Environment = var.environment
    Purpose     = "EcryptedS3Bucket"
  }
}



resource "aws_s3_bucket" "encrypted_bucket" {
  bucket        = "encrypted-bucket-${local.resource_suffix}"
  force_destroy = true
  tags          = local.common_tags
}



# enable s3 versioning
resource "aws_s3_bucket_versioning" "encrypted_bucket" {
  bucket = aws_s3_bucket.encrypted_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_public_access_block" "encrypted_bucket" {
  bucket                  = aws_s3_bucket.encrypted_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_kms_key" "encrypted_bucket" {
  description             = "Kms key for bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowS3Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }

        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
  tags = {
    Name = "encrypted-bucket-${local.resource_suffix}-kms-key"
  }
}


resource "aws_kms_alias" "encrypted_bucket" {
  name          = "alias/encrypted-bucket-${local.resource_suffix}-kms-key"
  target_key_id = aws_kms_key.encrypted_bucket.key_id
}



resource "aws_s3_bucket_server_side_encryption_configuration" "encrypted_bucket" {
  bucket = aws_s3_bucket.encrypted_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.encrypted_bucket.key_id
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }

}