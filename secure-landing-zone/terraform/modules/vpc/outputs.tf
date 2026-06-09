

output "aws_vpc_id" {
    value = aws_vpc.SLZ_vpc.id
}


output "public_subnet_ids" {
    value = aws_subnet.SLZ_pub_subnet[*].id
}


output "private_subnet_ids" {
    value = aws_subnet.SLZ_priv_subnet[*].id
}


output "flow_log_bucket_id" {
    value = aws_s3_bucket.SLZ_flow_logs_bucket.id
}

output "vpc_id" {
  value = aws_vpc.SLZ_vpc.id
}