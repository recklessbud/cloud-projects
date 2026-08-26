output "ecs_task_role" {
  value = aws_iam_role.ecs_task_role.arn
}

output "ecs_task_execution" {
  value = aws_iam_role.ecs_task_execution.arn
}