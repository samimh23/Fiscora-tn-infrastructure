variable "project_id" {
  description = "Existing Google Cloud project that owns NuExtract resources."
  type        = string
}

variable "region" {
  description = "Region for the Terraform state bucket."
  type        = string
  default     = "europe-west1"
}

variable "state_bucket_name" {
  description = "Globally unique GCS bucket name. Null derives it from project_id."
  type        = string
  default     = null
}

