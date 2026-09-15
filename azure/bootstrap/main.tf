data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "state" {
  name     = var.state_resource_group_name
  location = var.location

  tags = {
    Project     = "fiscora"
    Environment = "shared"
    ManagedBy   = "Terraform"
    Purpose     = "terraform-state"
  }
}

resource "azurerm_storage_account" "state" {
  name                            = var.state_storage_account_name
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  shared_access_key_enabled       = false
  public_network_access_enabled   = true
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  tags = azurerm_resource_group.state.tags
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "operator_state" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_user_assigned_identity" "terraform_plan" {
  name                = "id-fiscora-terraform-plan"
  resource_group_name = azurerm_resource_group.state.name
  location            = azurerm_resource_group.state.location
  tags                = azurerm_resource_group.state.tags
}

resource "azurerm_federated_identity_credential" "terraform_main" {
  name                      = "github-infrastructure-main"
  user_assigned_identity_id = azurerm_user_assigned_identity.terraform_plan.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_infrastructure_repository}@${var.github_infrastructure_repository_id}:ref:refs/heads/main"
}

resource "azurerm_federated_identity_credential" "terraform_pull_request" {
  name                      = "github-infrastructure-pull-request"
  user_assigned_identity_id = azurerm_user_assigned_identity.terraform_plan.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_infrastructure_repository}@${var.github_infrastructure_repository_id}:pull_request"
}

resource "azurerm_role_assignment" "terraform_plan_subscription_reader" {
  scope                = "/subscriptions/${var.azure_subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.terraform_plan.principal_id
}

resource "azurerm_role_assignment" "terraform_plan_state" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.terraform_plan.principal_id
}

resource "azurerm_management_lock" "state" {
  name       = "protect-fiscora-terraform-state"
  scope      = azurerm_storage_account.state.id
  lock_level = "CanNotDelete"
  notes      = "Remove only during a deliberate, separately reviewed platform teardown."
}
