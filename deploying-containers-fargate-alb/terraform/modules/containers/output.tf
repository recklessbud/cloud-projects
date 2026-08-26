output "ecs_cluster" {
  value = aws_ecs_cluster.ecs_cluster.name
}


output "ecs_service" {
    value = aws_ecs_service.ecs_service.name
}


output "ecr_repository_url" {
    value = aws_ecr_repository.ecr_repository.repository_url
}

output "container_image" {
  value = jsonencode(jsondecode(aws_ecs_task_definition.ecs_task_definition.container_definitions)[0].image)
}

output "container_port" {
  value = jsonencode(jsondecode(aws_ecs_task_definition.ecs_task_definition.container_definitions)[0].portMappings[0].containerPort)
}
