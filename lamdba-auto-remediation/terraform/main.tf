data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  resource_suffix = random_id.suffix.hex
}


resource "aws_cloudwatch_event_rule" "guardduty_findings" {
    name = "${var.project_name}-Guardduty-${local.resource_suffix}"
    description = "capture Guardduty findings meduim and high"

    event_pattern = jsonencode({
        source = ["aws.guardduty"]
        detail-type = ["GuardDuty Finding"]
        detail = {
            severity = [{numeric = [">=, 4"]}]
        }
    })
    tags = {
        Name = "${var.project_name}-guardduty-${local.resource_suffix}"
    }

}

resource "aws_sns_topic" "remediation_alerts" {
    name = "${var.project_name}-sns-topic-${local.resource_suffix}"
    kms_master_key_id = "alias/aws/sns"
    tags = {
        Name = "${var.project_name}-remediation-${local.resource_suffix}"
    }
}