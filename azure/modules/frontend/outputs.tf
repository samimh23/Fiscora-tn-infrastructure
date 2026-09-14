output "id" { value = azurerm_static_web_app.this.id }
output "name" { value = azurerm_static_web_app.this.name }
output "default_hostname" { value = azurerm_static_web_app.this.default_host_name }
output "custom_domain_validation_token" {
  value     = try(azurerm_static_web_app_custom_domain.this[0].validation_token, null)
  sensitive = true
}
