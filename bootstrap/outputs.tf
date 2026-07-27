output "state_bucket_name" {
  description = "S3 bucket to place in environments/staging/backend.hcl."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_region" {
  description = "AWS region of the Terraform state bucket."
  value       = var.aws_region
}

output "github_terraform_plan_role_arn" {
  description = "Read-only role assumed by the GitHub Actions Terraform plan workflow."
  value       = aws_iam_role.github_terraform_plan.arn
}

output "github_oidc_subject" {
  description = "Immutable GitHub OIDC subject trusted by the Terraform plan role."
  value       = local.github_main_subject
}
