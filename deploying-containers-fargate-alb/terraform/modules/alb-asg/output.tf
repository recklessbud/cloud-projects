output "fargate_tg" {
  value = aws_lb_target_group.fargate_tg.arn
}


output "fargate_listener" {
    value = aws_lb_listener.fargate_listener.arn
}