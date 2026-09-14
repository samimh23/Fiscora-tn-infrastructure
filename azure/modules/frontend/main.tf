resource "azurerm_static_web_app" "this" {
  name                               = var.name
  resource_group_name                = var.resource_group_name
  location                           = var.location
  sku_tier                           = "Free"
  sku_size                           = "Free"
  preview_environments_enabled       = false
  configuration_file_changes_enabled = false
  tags                               = var.tags
}

resource "azurerm_role_assignment" "deployment" {
  scope                = azurerm_static_web_app.this.id
  role_definition_name = "Contributor"
  principal_id         = var.deployment_principal_id
}

resource "azurerm_static_web_app_custom_domain" "this" {
  count = var.enable_custom_domain ? 1 : 0

  static_web_app_id = azurerm_static_web_app.this.id
  domain_name       = var.custom_domain
  validation_type   = "dns-txt-token"
}
