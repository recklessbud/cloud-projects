

resource "aws_guardduty_detector" "SLZ_gd" {
    enable = true
    finding_publishing_frequency = "FIFTEEN_MINUTES"

}

resource "aws_sns_topic" "guardduty_alerts" {
    name = var.SNS_topic_name
    kms_master_key_id = "alias/aws/sns"


  tags = {
    Name = "${var.project_name}-guardduty-alerts"
  }
}


resource "aws_sns_topic_subscription" "guardduty_alerts" {
    topic_arn = aws_sns_topic.guardduty_alerts.arn
    protocol = "email"
    endpoint = var.alert_email
}


resource "aws_cloudwatch_event_rule" "guardduty_alerts" {
    name = "guardduty-findings"
    event_pattern= jsonencode({
        source: [
            "aws.guardduty"
        ],
        detail-type: [
            "GuardDuty Finding"
        ],
        detail = {
            severity = [
            { numeric = [">=", 4] }
      ]
    }
    })
}


resource "aws_cloudwatch_event_target" "guardduty_alerts" {
    rule = aws_cloudwatch_event_rule.guardduty_alerts.name
    arn = aws_sns_topic.guardduty_alerts.arn
    target_id = "SendToSNS"
}


resource "aws_sns_topic_policy" "sns_policy" {
    arn = aws_sns_topic.guardduty_alerts.arn
    policy = data.aws_iam_policy_document.sns_policy.json
}



data "aws_iam_policy_document" "sns_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.guardduty_alerts.arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.guardduty_alerts.arn]
    }
  }
}