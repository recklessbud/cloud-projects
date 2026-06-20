# outputs


output "s3_bucket" {
  description = "s3 bucket name"
  value       = aws_s3_bucket.CDP_bucket.bucket
}


output "s3_bucket_arn" {
  description = "s3 bucket arn"
  value       = aws_s3_bucket.CDP_bucket.arn
}

output "sns_topic" {
  description = "sns topic arn "
  value       = aws_sns_topic.detection_logs.arn
}


output "lambda_function" {
  description = "lambda function"
  value       = aws_lambda_function.detector.arn
}

output "lambda_function_name" {
  description = "lambda function name"
  value       = aws_lambda_function.detector.function_name
}



output "cloudwatch_log_group" {
  description = "cloudwatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.arn
}