# Mock providers only. No cloud authentication, live state or real resource changes.
mock_provider "azapi" {}
mock_provider "azurerm" {
  # Valid synthetic IDs let downstream provider validators run after mock apply.
  mock_resource "azurerm_resource_group" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/rg-test" }
  }
  mock_resource "azurerm_virtual_network" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/test" }
  }
  mock_resource "azurerm_subnet" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/test/subnets/test" }
  }
  mock_resource "azurerm_private_dns_zone" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/privatelink.postgres.database.azure.com" }
  }
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/test"
      client_id    = "00000000-0000-0000-0000-000000000004"
      principal_id = "00000000-0000-0000-0000-000000000005"
    }
  }
  mock_resource "azurerm_key_vault" {
    defaults = {
      id        = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/test"
      vault_uri = "https://kv-test.vault.azure.net/"
    }
  }
  mock_resource "azurerm_key_vault_secret" {
    defaults = {
      id             = "https://kv-test.vault.azure.net/secrets/test/version"
      versionless_id = "https://kv-test.vault.azure.net/secrets/test"
    }
  }
  mock_resource "azurerm_storage_account" {
    defaults = {
      id                    = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/test"
      primary_blob_endpoint = "https://test.blob.core.windows.net/"
    }
  }
  mock_resource "azurerm_postgresql_flexible_server" {
    defaults = {
      id   = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test"
      fqdn = "test.postgres.database.azure.com"
    }
  }
  mock_resource "azurerm_log_analytics_workspace" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/test" }
  }
  mock_resource "azurerm_container_registry" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/rg-test/providers/Microsoft.ContainerRegistry/registries/test"
      login_server = "test.azurecr.io"
    }
  }
  mock_resource "azurerm_static_web_app" {
    defaults = {
      id                = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/rg-test/providers/Microsoft.Web/staticSites/test"
      default_host_name = "test.azurestaticapps.net"
    }
  }
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000001"
      subscription_id = "00000000-0000-0000-0000-000000000002"
    }
  }
  mock_resource "azurerm_container_app_environment" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/rg-test/providers/Microsoft.App/managedEnvironments/test"
    }
  }
}
mock_provider "azuread" {
  mock_resource "azuread_application" {
    defaults = {
      client_id = "00000000-0000-0000-0000-000000000006"
      object_id = "00000000-0000-0000-0000-000000000007"
    }
  }
  mock_resource "azuread_service_principal" {
    defaults = { object_id = "00000000-0000-0000-0000-000000000008" }
  }
}
mock_provider "random" {
  mock_resource "random_uuid" {
    defaults = { result = "00000000-0000-0000-0000-000000000009" }
  }
  mock_resource "random_password" {
    defaults = { result = "SyntheticMockValueOnly1234567890" }
  }
}

variables {
  app_service_stage             = "off"
  postgres_network_migrated     = false
  legacy_backend_stopped        = false
  app_service_database_ips      = []
  azure_subscription_id         = "00000000-0000-0000-0000-000000000002"
  operator_object_id            = "00000000-0000-0000-0000-000000000003"
  deployment_suffix             = "test123"
  github_owner_id               = "1"
  github_backend_repository_id  = "2"
  github_frontend_repository_id = "3"
  budget_contact_emails         = ["test@example.invalid"]
  enable_custom_domains         = false
  deploy_application            = true
  backend_image                 = "test.azurecr.io/fiscora-backend@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  frontend_public_url           = "https://app.test.invalid"
  malware_scan_enabled          = true
  clamav_image                  = "clamav/clamav:1.4"
}

run "foundation_without_api" {
  command   = plan
  state_key = "foundation"
  variables {
    deploy_application = false
    backend_image      = ""
  }
  assert {
    condition     = length(azurerm_container_app.api) == 0
    error_message = "The foundation must be plannable before a backend image exists."
  }
}

run "first_image" {
  command = apply
  assert {
    condition = alltrue([
      one([for env in azurerm_container_app.api[0].template[0].container[0].env : env.value if env.name == "DB_HOST"]) == azurerm_postgresql_flexible_server.postgres.fqdn,
      one([for env in azurerm_container_app.api[0].template[0].container[0].env : env.value if env.name == "DB_NAME"]) == azurerm_postgresql_flexible_server_database.application.name,
      one([for env in azurerm_container_app.api[0].template[0].container[0].env : env.value if env.name == "AZURE_STORAGE_ACCOUNT_URL"]) == azurerm_storage_account.documents.primary_blob_endpoint,
      one([for env in azurerm_container_app.api[0].template[0].container[0].env : env.value if env.name == "SMTP_HOST"]) == var.smtp_host,
      one([for env in azurerm_container_app.api[0].template[0].container[0].env : env.value if env.name == "NUEXTRACT_SERVICE_URL"]) == var.nuextract_service_url,
      one([for env in azurerm_container_app.api[0].template[0].container[0].env : env.value if env.name == "AI_ASSISTANT_MAX_VECTOR_DISTANCE"]) == "0.8",
    ])
    error_message = "Direct resource references must preserve runtime connection values and defaults."
  }
  assert {
    condition     = azurerm_container_app.api[0].template[0].container[0].image == var.backend_image
    error_message = "Terraform must use the supplied image on first creation."
  }
  assert {
    condition = !anytrue([for env in azurerm_container_app.api[0].template[0].container[0].env :
      contains(["EMAIL_INGESTION_DOMAIN", "EMAIL_INGESTION_MAX_ATTACHMENT_BYTES", "BREVO_API_KEY", "INBOUND_EMAIL_WEBHOOK_SECRET"], env.name)
    ])
    error_message = "Retired incoming-email settings must not return."
  }
  assert {
    condition     = contains([for secret in azurerm_container_app.api[0].secret : secret.name], "smtp-password") && length(azurerm_container_app.api[0].secret) == 4
    error_message = "Keep outgoing SMTP and the three core secrets, not incoming-email secrets."
  }
}

run "infrastructure_update_preserves_api_release" {
  command = plan
  variables {
    backend_image       = "test.azurecr.io/fiscora-backend@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    frontend_public_url = "https://new.test.invalid"
    clamav_image        = "clamav/clamav:1.5"
  }
  assert {
    condition     = azurerm_container_app.api[0].template[0].container[0].image == "test.azurecr.io/fiscora-backend@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    error_message = "An infrastructure plan must not revert the API image owned by GitHub."
  }
  assert {
    condition     = azurerm_container_app.api[0].template[0].container[1].image == var.clamav_image
    error_message = "ClamAV image changes must remain managed by Terraform."
  }
  assert {
    condition     = one([for env in azurerm_container_app.api[0].template[0].container[0].env : env.value if env.name == "APP_PUBLIC_URL"]) == var.frontend_public_url
    error_message = "Ignoring the API image must not ignore API configuration changes."
  }
}
