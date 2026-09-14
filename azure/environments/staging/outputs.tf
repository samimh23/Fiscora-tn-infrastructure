output "resource_group_name" { value = azurerm_resource_group.this.name }
output "azure_location" { value = azurerm_resource_group.this.location }
output "container_registry_name" { value = module.registry.name }
output "container_registry_login_server" { value = module.registry.login_server }
output "key_vault_name" { value = module.security.key_vault_name }
output "documents_storage_account_name" { value = module.storage.storage_account_name }
output "documents_container_name" { value = module.storage.container_name }
output "postgres_server_name" { value = module.database.server_name }
output "postgres_fqdn" {
  value     = module.database.fqdn
  sensitive = true
}
output "container_app_name" { value = module.application.api_name }
output "container_app_fqdn" { value = module.application.api_fqdn }
output "static_web_app_name" { value = module.frontend.name }
output "static_web_app_default_hostname" { value = module.frontend.default_hostname }
output "static_web_app_custom_domain_validation_token" {
  value     = module.frontend.custom_domain_validation_token
  sensitive = true
}
output "github_backend_client_id" { value = module.ci.backend_client_id }
output "github_frontend_client_id" { value = module.ci.frontend_client_id }
output "azure_tenant_id" { value = data.azurerm_client_config.current.tenant_id }
output "azure_subscription_id" {
  value     = data.azurerm_client_config.current.subscription_id
  sensitive = true
}
