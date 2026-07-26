output "state_bucket_name" {
  description = "S3 bucket to place in environments/staging/backend.hcl."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_region" {
  description = "AWS region of the Terraform state bucket."
  value       = var.aws_region
}

