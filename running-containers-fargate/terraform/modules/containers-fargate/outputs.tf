output "ecr_repository_url" {
    value = aws_ecr_repository.fargate_repo.repository_url
}

output "container_image" {
  value = jsonencode(jsondecode(aws_ecs_task_definition.fargate_task_definition.container_definitions)[0].image)
}

output "container_port" {
  value = jsonencode(jsondecode(aws_ecs_task_definition.fargate_task_definition.container_definitions)[0].portMappings[0].containerPort)
}
