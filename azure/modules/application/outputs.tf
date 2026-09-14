output "environment_id" { value = azurerm_container_app_environment.this.id }
output "api_id" { value = try(azurerm_container_app.api[0].id, null) }
output "api_name" { value = try(azurerm_container_app.api[0].name, null) }
output "api_fqdn" { value = try(azurerm_container_app.api[0].ingress[0].fqdn, null) }
