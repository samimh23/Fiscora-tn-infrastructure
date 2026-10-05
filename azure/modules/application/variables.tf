variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "container_apps_subnet_id" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "application_identity_id" { type = string }
variable "application_identity_client_id" { type = string }
variable "registry_login_server" { type = string }
variable "deploy_application" { type = bool }
variable "backend_image" { type = string }
variable "database_password_secret_id" {
  type      = string
  sensitive = true
}
variable "jwt_signing_key_secret_id" {
  type      = string
  sensitive = true
}
variable "mfa_encryption_key_secret_id" {
  type      = string
  sensitive = true
}
variable "smtp_password_secret_id" {
  type      = string
  sensitive = true
}
variable "frontend_public_url" { type = string }
variable "google_oauth_client_id" { type = string }
variable "cors_allowed_origins" {
  description = "Comma-separated browser origins allowed to call the API."
  type        = string
}
variable "malware_scan_enabled" { type = bool }
variable "clamav_image" { type = string }
variable "application_insights_connection_string" {
  type      = string
  sensitive = true
}
variable "tags" {
  type    = map(string)
  default = {}
}
# Group connection settings. Secrets remain separate sensitive inputs.
variable "database" {
  description = "PostgreSQL connection details; the password is passed separately."
  type = object({
    host = string
    name = string
    user = string
  })
}
variable "storage" {
  description = "Document Blob Storage location, accessed with the runtime identity."
  type = object({
    account_url    = string
    container_name = string
  })
}
variable "smtp" {
  description = "Outgoing email settings; the SMTP key remains a Key Vault reference."
  type = object({
    host = string
    port = number
    user = string
    from = string
  })
}
variable "ai" {
  description = "Extraction, assistant and cross-cloud identity settings."
  type = object({
    extraction_enabled  = bool
    provider            = string
    qwen_url            = string
    nuextract_url       = string
    ocr_url             = string
    azure_audience      = string
    google_audience     = string
    service_account     = string
    assistant_enabled   = bool
    project_id          = string
    vertex_location     = string
    chat_model          = string
    embedding_model     = string
    max_vector_distance = optional(string, "0.8")
  })
  validation {
    condition     = contains(["qwen", "nuextract"], var.ai.provider)
    error_message = "ai.provider must be qwen or nuextract."
  }
}
