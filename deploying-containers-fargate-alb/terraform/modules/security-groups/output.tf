output "fargate_tasks" {
  value = aws_security_group.fargate_tasks.id
}


output "alb"{
    value = aws_security_group.alb.id
}