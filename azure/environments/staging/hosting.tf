# registry: unchanged services, declared directly in staging.
resource "azurerm_container_registry" "backend" {
  name                = substr("acr${local.compact}", 0, 50)
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"
  # Keep authentication choices explicit; use provider defaults for networking/HA.
  admin_enabled          = false
  anonymous_pull_enabled = false
  tags                   = local.tags
}

resource "azurerm_role_assignment" "application_pull" {
  scope                = azurerm_container_registry.backend.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.application.principal_id
}

resource "azurerm_role_assignment" "deployment_push" {
  scope                = azurerm_container_registry.backend.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.backend.principal_id
}

# frontend: unchanged services, declared directly in staging.
resource "azurerm_static_web_app" "frontend" {
  name                         = "swa-${local.name_prefix}-${var.deployment_suffix}"
  resource_group_name          = azurerm_resource_group.this.name
  location                     = var.static_web_app_location
  sku_tier                     = "Free"
  preview_environments_enabled = false
  tags                         = local.tags

  lifecycle {
    # The Static Web Apps deployment service records the source repository
    # after an upload. Delivery remains owned by the OIDC GitHub workflow.
    ignore_changes = [repository_url, repository_branch]
  }
}

resource "azurerm_role_assignment" "deployment" {
  scope                = azurerm_static_web_app.frontend.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.frontend.principal_id
}

resource "azurerm_static_web_app_custom_domain" "frontend" {
  count = var.enable_custom_domains ? 1 : 0

  static_web_app_id = azurerm_static_web_app.frontend.id
  domain_name       = var.frontend_custom_domain
  validation_type   = "cname-delegation"
}

# NestJS/ClamAV hosting is declared directly in application.tf.
