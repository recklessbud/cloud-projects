data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  resource_suffix = random_id.suffix.hex
}

# ── GuardDuty ─────────────────────────────────────────
resource "aws_guardduty_detector" "remediation_guardduty" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = {
    Name = "${var.project_name}-guardduty-${local.resource_suffix}"
  }
}

resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "${var.project_name}-guardduty-${local.resource_suffix}"
  description = "Capture GuardDuty medium and high findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 4] }]
    }
  })

  tags = {
    Name = "${var.project_name}-guardduty-rule"
  }
}

resource "aws_cloudwatch_event_target" "guardduty_to_lambda" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  arn       = aws_lambda_function.remediation_alerts.arn
  target_id = "RemediationLambda"
}

# ── EventBridge — Config rule breaches ───────────────
resource "aws_cloudwatch_event_rule" "config_findings" {
  name        = "${var.project_name}-config-breach-${local.resource_suffix}"
  description = "Capture AWS Config non-compliant resources"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })

  tags = {
    Name = "${var.project_name}-config-rule"
  }
}

resource "aws_cloudwatch_event_target" "config_to_lambda" {
  rule      = aws_cloudwatch_event_rule.config_findings.name
  arn       = aws_lambda_function.remediation_alerts.arn
  target_id = "ConfigRemediationLambda"
}

# ── EventBridge — Scheduled full scan ────────────────
resource "aws_cloudwatch_event_rule" "scheduled_scan" {
  name                = "${var.project_name}-scheduled-scan-${local.resource_suffix}"
  description         = "Trigger full account security scan daily"
  schedule_expression = "rate(24 hours)"

  tags = {
    Name = "${var.project_name}-scheduled-scan"
  }
}

resource "aws_cloudwatch_event_target" "scheduled_to_lambda" {
  rule      = aws_cloudwatch_event_rule.scheduled_scan.name
  arn       = aws_lambda_function.remediation_alerts.arn
  target_id = "ScheduledRemediation"

  input = jsonencode({
    source      = "custom.remediation"
    detail-type = "Scheduled Security Scan"
    detail      = {}
  })
}

# ── SNS topic ─────────────────────────────────────────
resource "aws_sns_topic" "remediation_alerts" {
  name              = "${var.project_name}-sns-topic-${local.resource_suffix}"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name = "${var.project_name}-remediation-alerts"
  }
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.remediation_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_policy" "remediation_alerts_policy" {
  arn    = aws_sns_topic.remediation_alerts.arn
  policy = data.aws_iam_policy_document.sns_eventbridge_policy.json
}

# ── SNS policy — allow EventBridge to publish ─────────
data "aws_iam_policy_document" "sns_eventbridge_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.remediation_alerts.arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        aws_cloudwatch_event_rule.guardduty_findings.arn,
        aws_cloudwatch_event_rule.config_findings.arn,
        aws_cloudwatch_event_rule.scheduled_scan.arn
      ]
    }
  }
}

# ── Lambda IAM role ───────────────────────────────────
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-exec-role-${local.resource_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "Lambda execution role"
  }
}

data "aws_iam_policy_document" "lambda_exec_policy" {
  statement {
    sid    = "EC2Remediation"
    effect = "Allow"
    actions = [
      "ec2:DescribeSecurityGroups",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DescribeInstances"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "S3Remediation"
    effect = "Allow"
    actions = [
      "s3:PutPublicAccessBlock",
      "s3:GetBucketPublicAccessBlock"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IAMRemediation"
    effect = "Allow"
    actions = [
      "iam:PutUserPolicy",
      "iam:GetUserPolicy"
    ]
    resources = ["arn:aws:iam::*:user/*"]
  }

  statement {
    sid       = "PublishToSNS"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.remediation_alerts.arn]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "lambda_exec_policy" {
  name   = "${var.project_name}-lambda-policy"
  role   = aws_iam_role.lambda_exec_role.id
  policy = data.aws_iam_policy_document.lambda_exec_policy.json
}

# ── Lambda function ───────────────────────────────────
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/../src/lambda/remediation.zip"
  source_file = "${path.module}/../src/lambda/remediation.py"
}

resource "aws_lambda_function" "remediation_alerts" {
  function_name    = "${var.project_name}-function-${local.resource_suffix}"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "remediation.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 60
  memory_size      = 128

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.remediation_alerts.arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_logs]

  tags = {
    Name = "${var.project_name}-remediation-function"
  }
}

# ── Lambda permissions ────────────────────────────────
resource "aws_lambda_permission" "eventbridge_guardduty_invoke" {
  statement_id  = "AllowGuardDutyEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediation_alerts.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_findings.arn
}

resource "aws_lambda_permission" "eventbridge_config_invoke" {
  statement_id  = "AllowConfigEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediation_alerts.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.config_findings.arn
}

resource "aws_lambda_permission" "eventbridge_scheduled_invoke" {
  statement_id  = "AllowScheduledInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediation_alerts.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduled_scan.arn
}

# ── CloudWatch log group ──────────────────────────────
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-function-${local.resource_suffix}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-lambda-logs"
  }
}