output "s3BucketName" {
  description = "s3 bucket name"
  value       = aws_s3_bucket.encrypted_bucket.bucket
}

output "callerID" {
  description = "AWS caller identity"
  value       = data.aws_caller_identity.current.arn
}

output "kms_key_id" {
  description = "kms key id"
  value       = aws_kms_key.encrypted_bucket.key_id
}