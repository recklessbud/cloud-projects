# resource configuration
# Get current AWS caller identity
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  resource_suffix = random_id.suffix.hex
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "SessionManagerDemo"
  }
}

# create vpc
resource "aws_vpc" "SSM_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}-vpc-${local.resource_suffix}"
  }
}


resource "aws_subnet" "SSM_subnet" {
  vpc_id     = aws_vpc.SSM_vpc.id
  cidr_block = var.subnet_cidr_block
  tags = {
    Name = "${var.project_name}-subnet-${local.resource_suffix}"
  }
}


resource "aws_internet_gateway" "SSM_igw" {
  vpc_id = aws_vpc.SSM_vpc.id
  tags = {
    Name = "${var.project_name}-igw-${local.resource_suffix}"

  }
}


resource "aws_route_table" "rtb_public" {
  vpc_id = aws_vpc.SSM_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.SSM_igw.id
  }
  tags = {
    Name = "${var.environment}-rtb-public"
  }
}


resource "aws_route_table_association" "assoc_public" {
  subnet_id      = aws_subnet.SSM_subnet.id
  route_table_id = aws_route_table.rtb_public.id

}

# get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# KMS key for encryption
resource "aws_kms_key" "session_manager" {
  count                   = var.enable_logging ? 1 : 0
  description             = "KMS key for Session Manager logging"
  deletion_window_in_days = var.kms_key_deletion_window
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
        Sid    = "AllowCloudwatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowS3Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowCloudTrail"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:DecryptDataKey"
        ]
        Resource = "*"
      }
    ]
  })
  tags = {
    Name = "session-manager-kms-key-${local.resource_suffix}"
  }
}

# KMS key alias
resource "aws_kms_alias" "session_manager" {
  count         = var.enable_logging ? 1 : 0
  name          = "alias/session-manager-kms-key-${local.resource_suffix}"
  target_key_id = aws_kms_key.session_manager[0].key_id
}


# create s3 bucket for logging 
resource "aws_s3_bucket" "session_logs" {
  count = var.enable_logging ? 1 : 0

  bucket        = "sessionmanager-logs-${local.resource_suffix}"
  force_destroy = true

  tags = {
    Name = "session-manager-logs-${local.resource_suffix}"
  }
}


# enable s3 versioning
resource "aws_s3_bucket_versioning" "session_logs" {
  count  = var.enable_logging ? 1 : 0
  bucket = aws_s3_bucket.session_logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}


# enable s3 encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "session_logs" {
  count  = var.enable_logging ? 1 : 0
  bucket = aws_s3_bucket.session_logs[0].id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.session_manager[0].arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}


# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "session_logs" {
  count = var.enable_logging ? 1 : 0

  bucket = aws_s3_bucket.session_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# cloudwatch log_group for session logs
resource "aws_cloudwatch_log_group" "session_manager" {
  count = var.enable_logging ? 1 : 0

  name              = "/aws/session-manager/session-${local.resource_suffix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.session_manager[0].arn

  tags = {
    Name = "session-manager-log-group-${local.resource_suffix}"
  }
}


# IAM role for EC2 instances to use Session Manager
resource "aws_iam_role" "session_manager_instance_role" {
  name = "SessionManagerInstanceRole-${local.resource_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = {
    Name = "SessionManagerInstanceRole-${local.resource_suffix}"
  }
}


# Attach AWS managed policy 
resource "aws_iam_policy_attachment" "session_manager_instance_role_policy" {
  name       = "session-manager-instance-role-policy-${local.resource_suffix}"
  roles      = [aws_iam_role.session_manager_instance_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# policy for cloudwatch logs
resource "aws_iam_role_policy" "cloudwatch_logs_policy" {

  role = aws_iam_role.session_manager_instance_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = aws_cloudwatch_log_group.session_manager[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.session_manager[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetEncryptionConfiguration"
        ]
        Resource = "${aws_s3_bucket.session_logs[0].arn}/*"
      }
    ]
  })
}


# resource profile for EC2 instances
resource "aws_iam_instance_profile" "session_manager_instance_profile" {
  name = "SessionManagerInstanceProfile-${local.resource_suffix}"
  role = aws_iam_role.session_manager_instance_role.name

  tags = {
    Name = "SessionManagerInstanceProfile-${local.resource_suffix}"
  }
}


# security group for ec2 instances

resource "aws_security_group" "session_manager_security_group" {
  name        = "session-manager-security-group-${local.resource_suffix}"
  vpc_id      = aws_vpc.SSM_vpc.id
  description = "Security group for Session Manager demo instances"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ssm-${local.resource_suffix}-securtiy-group"
  }
}

resource "aws_instance" "session_manager_demo" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.SSM_subnet.id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.session_manager_instance_profile.name
  vpc_security_group_ids      = [aws_security_group.session_manager_security_group.id] # fix 1
  disable_api_termination     = false

  # fix 2 — no base64encode() wrapper
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent

    # Install additional tools
    yum install -y htop nano tree

    chmod +rw /etc/motd
    echo "Session Manager Demo Instance"                        > /etc/motd
    echo "Access this instance using AWS Session Manager"      >> /etc/motd
    echo "No SSH keys or open ports required!"                 >> /etc/motd
  EOF

  # force re-run user_data when it changes
  user_data_replace_on_change = true

  root_block_device {
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
    volume_type           = "gp3"
  }

  tags = {
    Name = "session-manager-demo-${local.resource_suffix}"
  }
}


# IAM policy for users to access Session Manager
resource "aws_iam_policy" "session_manager_access_policy" {
  name        = "SessionManagerAccessPolicy-${local.resource_suffix}"
  description = "Policy to allow users to access Session Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StartSession"
        Effect = "Allow"
        Action = [
          "ssm:StartSession"
        ]
        Resource = [
          "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*"
        ]
        Condition = {
          StringEquals = {
            "ssm:resourceTag/Purpose" : "SessionManagerTesting"
          }
        }
      },
      {
        Sid    = "DescribeInstances"
        Effect = "Allow"
        Action = [
          "ssm:DescribeInstanceInformation",
          "ssm:GetConnectionStatus",
          "ssm:DescribeAssociationStatus"
        ]
        Resource = "*"
      },
      {
        Sid    = "GetParameters"
        Effect = "Allow"
        Action = [
          "ssm:DescribeDocumentParameters",
          "ssm:DescribeDocument",
          "ssm:GetDocuments",
        ]
        Resource = "arn:aws:ssm:*:*:document/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:TerminateSession",
          "ssm:ResumeSession"
        ]
        Resource = "*"
      }
    ]
  })
  tags = {
    Name = "SessionManagerAccessPolicy-${local.resource_suffix}"
  }
}

# Session Manager logging preferences (if logging enabled)
resource "aws_ssm_document" "session_manager_prefs" {
  count = var.enable_logging ? 1 : 0

  name            = "SSM-SessionManagerRunShell-${local.resource_suffix}"
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Session Manager preferences with logging"
    sessionType   = "Standard_Stream"
    inputs = {
      s3BucketName                = aws_s3_bucket.session_logs[0].id
      s3KeyPrefix                 = var.s3_log_prefix
      s3EncryptionEnabled         = true
      cloudWatchLogGroupName      = aws_cloudwatch_log_group.session_manager[0].name
      cloudWatchEncryptionEnabled = true
      cloudWatchStreamingEnabled  = true
      kmsKeyId                    = aws_kms_key.session_manager[0].key_id
      runAsEnabled                = false
      runAsDefaultUser            = ""
      idleSessionTimeout          = "20"
      maxSessionDuration          = "60"
      shellProfile = {
        linux = "cd $HOME; pwd"
      }
    }
  })

  tags = {
    Name = "session-manager-prefs-${local.resource_suffix}"
  }
}


# CloudTrail for Session Manager API logging (optional)
resource "aws_cloudtrail" "session_manager" {
  count = var.enable_cloudtrail_logging ? 1 : 0

  name                          = "session-manager-trail-${local.resource_suffix}"
  s3_bucket_name                = var.enable_logging ? aws_s3_bucket.session_logs[0].id : null
  s3_key_prefix                 = "cloudtrail-logs/"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  kms_key_id                    = var.enable_logging ? aws_kms_key.session_manager[0].arn : null

  event_selector {
    read_write_type                  = "All"
    include_management_events        = true
    exclude_management_event_sources = []

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::${aws_s3_bucket.session_logs[0].id}/"]
    }
  }

  tags = {
    Name = "session-manager-cloudtrail-${local.resource_suffix}"
  }
  depends_on = [aws_s3_bucket_policy.cloudtrail_logging]
}

resource "aws_s3_bucket_policy" "cloudtrail_logging" {
  count = var.enable_cloudtrail_logging && var.enable_logging ? 1 : 0

  bucket = aws_s3_bucket.session_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.session_logs[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/session-manager-trail-${local.resource_suffix}"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.session_logs[0].arn}/cloudtrail-logs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "AWS:SourceArn" = "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/session-manager-trail-${local.resource_suffix}"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailLookup"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.session_logs[0].arn
      }
    ]
  })
}
