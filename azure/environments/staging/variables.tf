variable "azure_subscription_id" {
  description = "Azure subscription receiving the Fiscora staging resources."
  type        = string
  sensitive   = true
}

variable "operator_object_id" {
  description = "Stable Microsoft Entra object ID for the human operator who applies Terraform and administers staging data."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.operator_object_id))
    error_message = "operator_object_id must be a Microsoft Entra object ID in UUID format."
  }
}

variable "location" {
  description = "Primary Azure region for the application and data."
  type        = string
  default     = "francecentral"
}

variable "static_web_app_location" {
  description = "Azure Static Web Apps region."
  type        = string
  default     = "eastus2"
}

variable "project_name" {
  description = "Project identifier used in names and tags."
  type        = string
  default     = "fiscora"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be staging or production."
  }
}

variable "deployment_suffix" {
  description = "Lowercase letters and digits used to make globally unique Azure names."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,10}$", var.deployment_suffix))
    error_message = "deployment_suffix must contain 3-10 lowercase letters or digits."
  }
}

variable "budget_amount_usd" {
  description = "Monthly staging cost-alert threshold. This is not a hard spending limit."
  type        = number
  default     = 40
}

variable "budget_start_date" {
  description = "Budget start at the first day of a month, in RFC3339 format."
  type        = string
  default     = "2026-09-01T00:00:00Z"
}

variable "budget_end_date" {
  description = "Budget end date. Azure budgets use month boundaries; the current startup credit expires during December 2026."
  type        = string
  default     = "2027-01-01T00:00:00Z"
}

variable "budget_contact_emails" {
  description = "Addresses receiving Azure cost alerts."
  type        = list(string)

  validation {
    condition     = length(var.budget_contact_emails) > 0
    error_message = "At least one budget contact email is required."
  }
}

variable "github_owner" {
  description = "GitHub organization or user owning the Fiscora repositories."
  type        = string
  default     = "samimh23"
}

variable "github_owner_id" {
  description = "Immutable numeric GitHub owner ID included in OIDC subject claims."
  type        = string
}

variable "github_infrastructure_repository" {
  type    = string
  default = "Fiscora-tn-infrastructure"
}

variable "github_backend_repository" {
  type    = string
  default = "Fiscora-tn-backend"
}

variable "github_backend_repository_id" {
  description = "Immutable numeric GitHub backend repository ID included in OIDC subject claims."
  type        = string
}

variable "github_frontend_repository" {
  type    = string
  default = "Fiscora-tn-web"
}

variable "github_frontend_repository_id" {
  description = "Immutable numeric GitHub frontend repository ID included in OIDC subject claims."
  type        = string
}

variable "postgres_sku_name" {
  description = "Low-cost burstable PostgreSQL SKU for staging."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_version" {
  description = "Azure PostgreSQL major version."
  type        = string
  default     = "16"
}

variable "deploy_application" {
  description = "Create the Container App only after an image and runtime secrets exist."
  type        = bool
  default     = false
}

variable "backend_image" {
  description = "Immutable backend image, preferably pinned by digest."
  type        = string
  default     = ""

  validation {
    condition     = !var.deploy_application || length(trimspace(var.backend_image)) > 0
    error_message = "backend_image is required when deploy_application is true."
  }
}

variable "frontend_public_url" {
  description = "Public frontend URL included in invitations and CORS."
  type        = string
  default     = "https://app.fiscora.me"
}

variable "smtp_host" {
  type    = string
  default = "smtp-relay.brevo.com"
}

variable "smtp_port" {
  type    = number
  default = 587
}

variable "smtp_user" {
  description = "Brevo SMTP login. This identifier is not the SMTP key."
  type        = string
  default     = ""
}

variable "smtp_from" {
  type    = string
  default = "Fiscora <invitations@fiscora.me>"
}

variable "smtp_password_secret_name" {
  description = "Key Vault secret populated out-of-band with the Brevo SMTP key."
  type        = string
  default     = "smtp-password"
}

variable "brevo_api_key_secret_name" {
  description = "Key Vault secret populated out-of-band with the Brevo REST API key."
  type        = string
  default     = "brevo-api-key"
}

variable "inbound_email_webhook_secret_name" {
  description = "Key Vault secret used to authenticate Brevo inbound webhooks."
  type        = string
  default     = "inbound-email-webhook-secret"
}

variable "email_ingestion_domain" {
  description = "Dedicated receiving subdomain delegated to Brevo Inbound Parse."
  type        = string
  default     = "inbox.fiscora.me"
}

variable "email_ingestion_max_attachment_bytes" {
  description = "Maximum size of one inbound accounting attachment."
  type        = number
  default     = 20971520
}

variable "malware_scan_enabled" {
  description = "Run ClamAV beside the API and reject uploads unless a clean scan succeeds."
  type        = bool
  default     = true
}

variable "clamav_image" {
  description = "ClamAV container image used by the API sidecar. Pin by digest before production."
  type        = string
  default     = "clamav/clamav:1.4"
}

variable "enable_custom_domains" {
  description = "Request Azure custom-domain bindings only after the required DNS records exist."
  type        = bool
  default     = false
}

variable "frontend_custom_domain" {
  type    = string
  default = "app.fiscora.me"
}

variable "document_extraction_enabled" {
  description = "Run the durable document-extraction worker in the API."
  type        = bool
  default     = false
}

variable "nuextract_service_url" {
  description = "Private Google Cloud Run NuExtract service URL."
  type        = string
  default     = ""
}

variable "azure_gcp_wif_app_id_uri" {
  description = "Stable Microsoft Entra Application ID URI used as the Google federation audience."
  type        = string
  default     = "api://c26cfc43-9c94-4f7b-813e-d23460d18aec/fiscora-google-wif"
}

variable "gcp_wif_provider_audience" {
  description = "Canonical Google Workload Identity provider audience."
  type        = string
  default     = ""
}

variable "gcp_wif_service_account" {
  description = "Google service account impersonated by the Azure API."
  type        = string
  default     = ""
}

variable "ai_assistant_enabled" {
  description = "Enable the permission-scoped dossier RAG assistant."
  type        = bool
  default     = false
}

variable "gcp_project_id" {
  description = "Google Cloud project used for Vertex AI."
  type        = string
  default     = "fiscora-ai"
}

variable "vertex_ai_location" {
  type    = string
  default = "global"
}

variable "vertex_ai_chat_model" {
  type    = string
  default = "gemini-2.5-flash"
}

variable "vertex_ai_embedding_model" {
  type    = string
  default = "gemini-embedding-001"
}

variable "ai_assistant_max_vector_distance" {
  description = "Maximum cosine distance accepted for semantic context before the assistant refuses to answer."
  type        = string
  default     = "0.8"
}
