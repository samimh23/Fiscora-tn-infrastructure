variable "project_id" {
  description = "Existing Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Cloud Run and Artifact Registry region."
  type        = string
  default     = "europe-west1"
}

variable "billing_account_id" {
  description = "Billing account ID used for the project-scoped alert budget."
  type        = string
  default     = null
  nullable    = true
}

variable "monthly_budget_usd" {
  description = "Monthly alert budget. This is not a hard spending cap."
  type        = number
  default     = 50

  validation {
    condition     = var.monthly_budget_usd >= 5
    error_message = "monthly_budget_usd must be at least 5 USD."
  }
}

variable "invoker_members" {
  description = "IAM principals allowed to invoke the private extraction service."
  type        = set(string)
  default     = []
}

variable "enable_extraction_service" {
  description = "Explicit cost gate. False creates no Cloud Run GPU service."
  type        = bool
  default     = false
}

variable "extraction_image" {
  description = "Immutable Artifact Registry image digest for the Qwen extractor."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      !var.enable_extraction_service ||
      (var.extraction_image != null && can(regex("@sha256:[0-9a-f]{64}$", var.extraction_image)))
    )
    error_message = "When enabled, extraction_image must use an immutable @sha256 digest."
  }
}

variable "service_name" {
  description = "Cloud Run service name."
  type        = string
  default     = "fiscora-nuextract"
}

variable "request_concurrency" {
  description = "Requests admitted per L4 instance. Keep low for long structured multimodal outputs."
  type        = number
  default     = 4

  validation {
    condition     = contains([1, 2, 4, 8], var.request_concurrency)
    error_message = "Use a reviewed concurrency value: 1, 2, 4, or 8."
  }
}

variable "max_num_seqs" {
  description = "vLLM scheduler ceiling. Keep aligned with request_concurrency."
  type        = number
  default     = 4
}

variable "deletion_protection" {
  description = "Protect the Cloud Run inference service from accidental deletion."
  type        = bool
  default     = true
}

variable "azure_tenant_id" {
  description = "Microsoft Entra tenant issuing the managed identity token."
  type        = string
}

variable "azure_managed_identity_object_id" {
  description = "Exact Azure API managed identity object ID allowed to federate."
  type        = string
}

variable "azure_application_id_uri" {
  description = "Audience exposed by the Microsoft Entra application used for federation."
  type        = string
  default     = "api://TENANT_ID/fiscora-google-wif"
}
