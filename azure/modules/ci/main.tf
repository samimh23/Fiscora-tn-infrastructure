resource "azurerm_user_assigned_identity" "backend" {
  name                = "id-${var.name_prefix}-backend"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "frontend" {
  name                = "id-${var.name_prefix}-frontend"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "backend_main" {
  name                      = substr("github-${lower(replace(var.github_backend_repository, "_", "-"))}-main", 0, 120)
  user_assigned_identity_id = azurerm_user_assigned_identity.backend.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_owner}/${var.github_backend_repository}:ref:refs/heads/main"
}

resource "azurerm_federated_identity_credential" "frontend_main" {
  name                      = substr("github-${lower(replace(var.github_frontend_repository, "_", "-"))}-main", 0, 120)
  user_assigned_identity_id = azurerm_user_assigned_identity.frontend.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_owner}/${var.github_frontend_repository}:ref:refs/heads/main"
}

resource "azurerm_role_assignment" "backend_container_apps" {
  scope                = var.resource_group_id
  role_definition_name = "Container Apps Contributor"
  principal_id         = azurerm_user_assigned_identity.backend.principal_id
}
