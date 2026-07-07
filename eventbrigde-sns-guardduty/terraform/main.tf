data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  resource_suffix = random_id.suffix.hex
}


resource "aws_guardduty_detector" "EDS_GuardDuty" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"


  tags = {
    Name = "${local.resource_suffix}-GuardDuty"
  }
}


# resource "aws_guardduty_organization_configuration" "EDS_GuardDuty" {
#   auto_enable = true
#   detector_id = aws_guardduty_detector.EDS_GuardDuty.id
# }



resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "${local.resource_suffix}-guardduty-findings"
  description = "Capture GuardDuty Medium and High findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 4] }]
    }
  })

  tags = {
    Name = "${local.resource_suffix}-guardduty-rule"
  }
}


resource "aws_sns_topic" "detection_alerts" {
  name              = "detection-alerts-${local.resource_suffix}"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name = "${local.resource_suffix}-detection-alerts-topic"
  }
}


resource "aws_sns_topic_subscription" "detection_logs_subscription" {
  topic_arn = aws_sns_topic.detection_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_event_target" "guardduty_to_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  arn       = aws_sns_topic.detection_alerts.arn
  target_id = "GuardDutyToSNS"
}


data "aws_iam_policy_document" "sns_eventbridge_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.detection_alerts.arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.guardduty_findings.arn]
    }
  }
}

resource "aws_sns_topic_policy" "detection_alerts_policy" {
  arn    = aws_sns_topic.detection_alerts.arn
  policy = data.aws_iam_policy_document.sns_eventbridge_policy.json
}



