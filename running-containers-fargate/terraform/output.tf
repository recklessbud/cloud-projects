output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.container_fargate.ecr_repository_url
}

output "container_image" {
  description = "Container image URI"
  value       = module.container_fargate.container_image
}

output "container_port" {
  description = "Container port"
  value       = module.container_fargate.container_port
}