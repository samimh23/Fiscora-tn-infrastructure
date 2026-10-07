# Mock providers only: no cloud credentials, remote state or Azure changes.
mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000001"
      subscription_id = "00000000-0000-0000-0000-000000000002"
    }
  }
}
mock_provider "azuread" {}
mock_provider "random" {}

variables {
  azure_subscription_id         = "00000000-0000-0000-0000-000000000002"
  operator_object_id            = "00000000-0000-0000-0000-000000000003"
  deployment_suffix             = "test123"
  github_owner_id               = "1"
  github_backend_repository_id  = "2"
  github_frontend_repository_id = "3"
  budget_contact_emails         = ["test@example.invalid"]
  deploy_application            = false
  enable_custom_domains         = false
}

run "pfe_foundation_preserves_services" {
  command = plan

  assert {
    # Mock providers do not execute the real provider's defaulting logic.
    # Check explicit security choices here; omitted defaults were verified
    # against the pinned AzureRM 4.81.0 schema/documentation.
    condition = (
      azurerm_container_registry.backend.admin_enabled == false &&
      azurerm_container_registry.backend.anonymous_pull_enabled == false
    )
    error_message = "Hosting cleanup must keep registry admin and anonymous access disabled."
  }
  assert {
    condition = (
      azurerm_static_web_app.frontend.sku_tier == "Free" &&
      azurerm_static_web_app.frontend.preview_environments_enabled == false
    )
    error_message = "Hosting cleanup must preserve the Free frontend with preview environments disabled."
  }
  assert {
    condition     = azurerm_application_insights.api.application_type == "web" && azurerm_application_insights.api.sampling_percentage == 25
    error_message = "Application Insights must be retained, with the original sampling."
  }
  assert {
    condition     = azurerm_postgresql_flexible_server.postgres.public_network_access_enabled == false && azurerm_postgresql_flexible_server.postgres.backup_retention_days == 7
    error_message = "Keep private PostgreSQL networking and backups."
  }
  assert {
    condition     = azurerm_storage_container.documents.container_access_type == "private" && azurerm_storage_account.documents.shared_access_key_enabled == false
    error_message = "Keep private, identity-authenticated document storage."
  }
  assert {
    condition     = azurerm_postgresql_flexible_server_database.application.name == "accounting_nest" && azurerm_storage_container.documents.name == "accounting-documents"
    error_message = "The database and document container names must not change."
  }
  assert {
    condition     = module.application.api_name == null
    error_message = "First installation must still work before an API image exists."
  }
}
