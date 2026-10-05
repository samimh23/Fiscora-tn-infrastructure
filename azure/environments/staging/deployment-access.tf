# ci: unchanged services, declared directly in staging.
resource "azurerm_user_assigned_identity" "backend" {
  name                = "id-${local.name_prefix}-backend"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.tags
}

resource "azurerm_user_assigned_identity" "frontend" {
  name                = "id-${local.name_prefix}-frontend"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "backend_main" {
  name                      = substr("github-${lower(replace(var.github_backend_repository, "_", "-"))}-main", 0, 120)
  user_assigned_identity_id = azurerm_user_assigned_identity.backend.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_backend_repository}@${var.github_backend_repository_id}:ref:refs/heads/main"
}

resource "azurerm_federated_identity_credential" "frontend_main" {
  name                      = substr("github-${lower(replace(var.github_frontend_repository, "_", "-"))}-main", 0, 120)
  user_assigned_identity_id = azurerm_user_assigned_identity.frontend.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_frontend_repository}@${var.github_frontend_repository_id}:ref:refs/heads/main"
}

resource "azurerm_role_assignment" "backend_container_apps" {
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Container Apps Contributor"
  principal_id         = azurerm_user_assigned_identity.backend.principal_id
}
