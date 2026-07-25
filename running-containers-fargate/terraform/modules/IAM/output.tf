output "ecs_execution_role_arn" {
  value = aws_iam_role.ecs_execution_role.arn
}

output "ecs_tasks_role_name" {
  value = aws_iam_role.ecs_execution_role.name
}