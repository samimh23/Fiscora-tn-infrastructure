resource "azurerm_user_assigned_identity" "deployment" {
  name                = "id-${var.name_prefix}-github"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "main_branch" {
  for_each = var.github_repositories

  name                      = substr("github-${lower(replace(each.value, "_", "-"))}-main", 0, 120)
  user_assigned_identity_id = azurerm_user_assigned_identity.deployment.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_owner}/${each.value}:ref:refs/heads/main"
}

resource "azurerm_role_assignment" "resource_group_contributor" {
  scope                = var.resource_group_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.deployment.principal_id
}
