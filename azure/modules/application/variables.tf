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
variable "database_host" { type = string }
variable "database_name" { type = string }
variable "database_user" { type = string }
variable "database_password_secret_id" {
  type      = string
  sensitive = true
}
variable "jwt_signing_key_secret_id" {
  type      = string
  sensitive = true
}
variable "smtp_password_secret_id" {
  type      = string
  sensitive = true
}
variable "storage_account_url" { type = string }
variable "storage_container_name" { type = string }
variable "frontend_public_url" { type = string }
variable "cors_allowed_origins" {
  description = "Comma-separated browser origins allowed to call the API."
  type        = string
}
variable "smtp_host" { type = string }
variable "smtp_port" { type = number }
variable "smtp_user" { type = string }
variable "smtp_from" { type = string }
variable "malware_scan_enabled" { type = bool }
variable "clamav_image" { type = string }
variable "application_insights_connection_string" {
  type      = string
  sensitive = true
}
variable "document_extraction_enabled" { type = bool }
variable "nuextract_service_url" { type = string }
variable "azure_gcp_wif_app_id_uri" { type = string }
variable "gcp_wif_provider_audience" { type = string }
variable "gcp_wif_service_account" { type = string }
variable "ai_assistant_enabled" { type = bool }
variable "gcp_project_id" { type = string }
variable "vertex_ai_location" { type = string }
variable "vertex_ai_chat_model" { type = string }
variable "vertex_ai_embedding_model" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
