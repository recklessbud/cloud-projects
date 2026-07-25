output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.container_fargate.ecr_repository_url
}