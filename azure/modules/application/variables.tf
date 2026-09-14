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
variable "smtp_host" { type = string }
variable "smtp_port" { type = number }
variable "smtp_user" { type = string }
variable "smtp_from" { type = string }
variable "application_insights_connection_string" {
  type      = string
  sensitive = true
}
variable "tags" {
  type    = map(string)
  default = {}
}
