output "fargate_security_group" {
  value = aws_security_group.ecs_tasks.id
}