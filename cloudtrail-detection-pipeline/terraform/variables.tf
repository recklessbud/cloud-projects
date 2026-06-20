variable "environment" {
  description = "env(dev, stage, prod)"
  type        = string
  default     = "dev"
}



variable "aws_region" {
  description = "aws region"
  type        = string
  default     = "us-east-1"
}


variable "project_name" {
  description = "project name"
  type        = string
  default     = "cloudtrail-detection-pipeline"
}


variable "alert_email" {
  description = "email to receive alerts"
  type        = string
}


variable "lambda_function_name" {
  description = "lambda function name"
  type        = string
  default     = "cloudtrail-detection-pipeline-function"
}


variable "log_retention_in_days" {
  description = "log retention in days"
  type        = number
  default     = 7
}


variable "sns_topic_name" {
  description = "sns topic name"
  type        = string
  default     = "cloudtrail-detection-pipeline-sns-topic"
}


variable "suspicious_actions" {
  description = "suspicious actions"
  type        = list(string)
  default = [
    "DeleteTrail",
    "StopLogging",
    "DeleteBucket",
    "PutBucketPolicy",
    "CreateUser",
    "AttachUserPolicy",
    "AuthorizeSecurityGroupIngress",
    "DeleteSecurityGroup",
  "ConsoleLogin"]
}