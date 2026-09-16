output "state_bucket_name" {
  description = "GCS bucket used by the Google Cloud Terraform stacks."
  value       = google_storage_bucket.terraform_state.name
}

