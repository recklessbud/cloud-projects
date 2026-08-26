output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.containers.ecr_repository_url
}

output "container_image" {
  description = "Container image URI"
  value       = module.containers.container_image
}

output "container_port" {
  description = "Container port"
  value       = module.containers.container_port
}