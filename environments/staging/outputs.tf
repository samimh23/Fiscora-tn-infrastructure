output "aws_region" {
  description = "AWS region hosting staging."
  value       = var.aws_region
}

output "backend_ecr_repository_name" {
  description = "Repository used by the backend deployment workflow."
  value       = module.registry.repository_name
}

output "backend_ecr_repository_url" {
  description = "Repository URL used to push backend images."
  value       = module.registry.repository_url
}

output "documents_bucket_name" {
  description = "Private S3 bucket used for accounting documents."
  value       = module.storage.documents_bucket_name
}

output "web_bucket_name" {
  description = "Private S3 bucket receiving the React build."
  value       = module.storage.web_bucket_name
}

output "cloudfront_distribution_id" {
  description = "Distribution ID used by the web deployment workflow."
  value       = module.storage.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "Temporary HTTPS hostname of the Fiscora frontend."
  value       = module.storage.cloudfront_domain_name
}

output "backend_instance_id" {
  description = "EC2 instance ID used by Systems Manager deployments."
  value       = module.compute.instance_id
}

output "backend_public_dns" {
  description = "Public hostname of the staging Docker host."
  value       = module.compute.public_dns
}

output "backend_public_ip" {
  description = "Stable Elastic IP to configure as app.fiscora.me in DNS."
  value       = module.compute.public_ip
}
