
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  resource_suffix = random_id.suffix.hex
  cloudtrial_aws = "cloudtrail.amazonaws.com"
}



resource "aws_s3_bucket" "CDP_bucket" {
  bucket        = "cdp-bucket-${local.resource_suffix}"
  force_destroy = true

  tags = {
    Name        = "Cloudtrail detection pipeline storage"
    Description = "Bucket for cloudtrail detection pipeline"
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
  bucket = aws_s3_bucket.CDP_bucket.id

  rule {
    id     = "archive-logs"
    status = "Enabled"
    filter {
      prefix = "AWSLogs/"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}




resource "aws_sns_topic" "detection_logs" {
  name              = "detection_logs-${local.resource_suffix}"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name        = var.sns_topic_name
    description = "SNS topic for cloudtrail detection pipeline"
  }
}


resource "aws_sns_topic_subscription" "detection_logs_subscription" {
  topic_arn = aws_sns_topic.detection_logs.arn
  protocol  = "email"
  endpoint  = var.alert_email
}


# function to assume a role
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role-${local.resource_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "Lambda execution role"
    Description = "Role for lambda execution to assume"
  }
}

resource "aws_iam_role_policy" "lambda_exec_policy" {
  name   = "${var.project_name}-lambda-policy"
  role   = aws_iam_role.lambda_exec_role.id
  policy = data.aws_iam_policy_document.lambda_exec_policy.json
}

data "aws_iam_policy_document" "lambda_exec_policy" {
  statement {
    sid    = "GetObjectfromS3"
    effect = "Allow"

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.CDP_bucket.arn}/*"]
  }


  statement {
    sid    = "PublishtoSNS"
    effect = "Allow"

    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.detection_logs.arn]
  }

  statement {
    sid    = "CRUDCloudtrailLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}



data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/../src/lambda/detection.zip"
  source_file = "${path.module}/../src/lambda/detection.py"
}


resource "aws_lambda_function" "detector" {
  function_name    = "cloudtrail_detector-${local.resource_suffix}"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "detection.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  timeout          = 60
  memory_size      = 128
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN      = aws_sns_topic.detection_logs.arn
      SUSPICIOUS_ACTIONS = join(",", var.suspicious_actions)
    }
  }


}

resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.detector.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.CDP_bucket.arn
}

resource "aws_s3_bucket_notification" "log_trigger" {
  bucket = aws_s3_bucket.CDP_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.detector.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".json.gz"
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}


resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-detector"
  retention_in_days = var.log_retention_in_days
}




data "aws_iam_policy_document"  "cloudtrail_policy" {
  statement {
    sid = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [ "${local.cloudtrial_aws}" ]
    }

    actions = [
      "s3:GetBucketAcl"
    ]
    resources = [aws_s3_bucket.CDP_bucket.arn]
  }
  

  statement {
    sid = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [ "${local.cloudtrial_aws}" ]
    }
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.CDP_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}


resource "aws_s3_bucket_policy" "cloudtrail_policy" {
  bucket = aws_s3_bucket.CDP_bucket.id
  policy = data.aws_iam_policy_document.cloudtrail_policy.json
  depends_on = [ aws_s3_bucket_public_access_block.CDP_bucket_access_block ]
}



resource "aws_cloudtrail" "detection_trail" {
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = aws_s3_bucket.CDP_bucket.id
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  enable_logging                = true

  depends_on = [aws_s3_bucket_policy.cloudtrail_policy]

  tags = {
    Name = "${var.project_name}-trail"
  }
}