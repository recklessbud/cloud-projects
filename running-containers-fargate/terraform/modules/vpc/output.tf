output "vpc_id" {
  value = aws_vpc.fargate_vpc.id
}

output "public_subnet_ids" {
  value = aws_subnet.fargate_subnet[*].id
}

output "ecs_log_group_name" {
  value = aws_cloudwatch_log_group.fargate_cloud_watch.name
}