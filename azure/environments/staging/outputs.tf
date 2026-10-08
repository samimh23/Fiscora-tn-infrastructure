output "resource_group_name" { value = azurerm_resource_group.this.name }
output "azure_location" { value = azurerm_resource_group.this.location }
output "container_registry_name" { value = azurerm_container_registry.backend.name }
output "container_registry_login_server" { value = azurerm_container_registry.backend.login_server }
output "key_vault_name" { value = azurerm_key_vault.secrets.name }
output "documents_storage_account_name" { value = azurerm_storage_account.documents.name }
output "documents_container_name" { value = azurerm_storage_container.documents.name }
output "postgres_server_name" { value = azurerm_postgresql_flexible_server.postgres.name }
output "postgres_fqdn" {
  value     = azurerm_postgresql_flexible_server.postgres.fqdn
  sensitive = true
}
output "backend_hosting" { value = "app-service" }
output "static_web_app_name" { value = azurerm_static_web_app.frontend.name }
output "static_web_app_default_hostname" { value = azurerm_static_web_app.frontend.default_host_name }
output "static_web_app_custom_domain_validation_token" {
  value     = try(azurerm_static_web_app_custom_domain.frontend[0].validation_token, null)
  sensitive = true
}
output "github_backend_client_id" { value = azurerm_user_assigned_identity.backend.client_id }
output "github_frontend_client_id" { value = azurerm_user_assigned_identity.frontend.client_id }
output "azure_tenant_id" { value = data.azurerm_client_config.current.tenant_id }
output "azure_subscription_id" {
  value     = data.azurerm_client_config.current.subscription_id
  sensitive = true
}
output "azure_gcp_wif_app_id_uri" { value = tolist(azuread_application.google_wif.identifier_uris)[0] }
output "azure_gcp_wif_application_client_id" { value = azuread_application.google_wif.client_id }
output "application_identity_principal_id" { value = azurerm_user_assigned_identity.application.principal_id }
