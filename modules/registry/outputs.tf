output "repository_arn" {
  description = "ARN of the backend ECR repository."
  value       = aws_ecr_repository.backend.arn
}

output "repository_name" {
  description = "Name of the backend ECR repository."
  value       = aws_ecr_repository.backend.name
}

output "repository_url" {
  description = "URL used to push and pull backend Docker images."
  value       = aws_ecr_repository.backend.repository_url
}

