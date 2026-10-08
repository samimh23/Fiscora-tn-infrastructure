# Mock providers only. No cloud authentication, live state or real resource changes.
mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id     = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/rg-test/providers/Microsoft.Web/sites/test"
      output = { properties = { defaultHostName = "test.azurewebsites.net", possibleOutboundIpAddresses = "203.0.113.10", state = "Stopped" } }
    }
  }
}
mock_provider "azurerm" {
  mock_resource "azurerm_service_plan" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/rg-test/providers/Microsoft.Web/serverfarms/test" }
  }
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


run "default_keeps_migration_off" {
  command   = plan
  state_key = "off"
  assert {
    condition     = length(azapi_resource.app_service) == 0 && length(azurerm_service_plan.backend) == 0 && length(azurerm_postgresql_flexible_server_firewall_rule.app_service) == 0
    error_message = "Default inputs must not create paid App Service or public database firewall rules."
  }
}

run "prepare_is_quarantined" {
  command   = apply
  state_key = "candidate"
  variables { app_service_stage = "prepare" }
  assert {
    condition     = azapi_resource.app_service[0].body.properties.enabled == false && strcontains(azapi_resource.app_service_api[0].body.properties.startUpCommand, "setInterval")
    error_message = "Prepared hosting must be disabled and unable to run NestJS even if started."
  }
  assert {
    condition     = local.app_service_settings.DB_MIGRATIONS_RUN == "false" && local.app_service_settings.DOCUMENT_EXTRACTION_ENABLED == "false" && local.app_service_settings.AI_ASSISTANT_ENABLED == "false"
    error_message = "Candidate hosting must not run migrations or workers."
  }
  assert {
    condition     = azapi_resource.app_service[0].body.properties.httpsOnly && azapi_resource.app_service[0].body.properties.siteConfig.alwaysOn && azurerm_service_plan.backend[0].sku_name == "B3"
    error_message = "Retain HTTPS and the reviewed paid always-on hosting baseline."
  }
  assert {
    condition     = azapi_resource.app_service_api[0].body.properties.image == var.backend_image && azapi_resource.app_service_clamav[0].body.properties.image == var.clamav_image && local.app_service_settings.CLAMAV_HOST == "localhost"
    error_message = "Keep the API image and local ClamAV sidecar."
  }
  assert {
    condition     = local.app_service_settings.DB_HOST == azurerm_postgresql_flexible_server.postgres.fqdn && local.app_service_settings.DB_NAME == "accounting_nest" && local.app_service_settings.DB_SSL == "true" && strcontains(local.app_service_settings.DB_PASSWORD, "@Microsoft.KeyVault(")
    error_message = "Reuse the existing database with TLS and Key Vault references, never a copied password."
  }
  assert {
    condition     = azurerm_postgresql_flexible_server.postgres.public_network_access_enabled == false && length(azurerm_postgresql_flexible_server_firewall_rule.app_service) == 0
    error_message = "Preparation must not alter database networking."
  }
}

run "candidate_release_ownership" {
  command   = plan
  state_key = "candidate"
  variables {
    app_service_stage = "prepare"
    backend_image     = "test.azurecr.io/fiscora-backend@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    clamav_image      = "clamav/clamav:1.5"
  }
  assert {
    condition     = azapi_resource.app_service_api[0].body.properties.image == "test.azurecr.io/fiscora-backend@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" && azapi_resource.app_service_clamav[0].body.properties.image == var.clamav_image
    error_message = "Only GitHub owns API releases; Terraform still owns ClamAV."
  }
}

# Isolated mock state: the external Azure network operation is NOT performed by this test.
run "reconciled_target_uses_exact_ip_firewall" {
  command   = plan
  state_key = "reconciled"
  variables {
    app_service_stage         = "active"
    postgres_network_migrated = true
    legacy_backend_stopped    = true
    app_service_database_ips  = ["203.0.113.10"]
  }
  assert {
    condition     = azurerm_postgresql_flexible_server.postgres.public_network_access_enabled && azurerm_postgresql_flexible_server.postgres.delegated_subnet_id == null && azurerm_postgresql_flexible_server.postgres.name == "psql-fiscora-staging-test123"
    error_message = "Reconcile the same named PostgreSQL server, not a differently named replacement."
  }
  assert {
    condition     = azapi_resource.app_service_api[0].body.properties.startUpCommand == "" && azapi_resource.app_service[0].body.properties.enabled && local.app_service_settings.DB_MIGRATIONS_RUN == "true"
    error_message = "Activate only after explicit migration and legacy-stop acknowledgements."
  }
  assert {
    condition     = length(azurerm_postgresql_flexible_server_firewall_rule.app_service) == 1 && azurerm_postgresql_flexible_server_firewall_rule.app_service["app-service-000"].start_ip_address == "203.0.113.10" && azurerm_postgresql_flexible_server_firewall_rule.app_service["app-service-000"].end_ip_address == "203.0.113.10"
    error_message = "The firewall must contain individual reviewed app IPs, not address ranges."
  }
}

run "activation_requires_completed_migration" {
  command   = plan
  state_key = "invalid-activation"
  variables { app_service_stage = "active" }
  expect_failures = [var.app_service_stage]
}

run "all_azure_firewall_rule_is_rejected" {
  command   = plan
  state_key = "invalid-firewall"
  variables { app_service_database_ips = ["0.0.0.0"] }
  expect_failures = [var.app_service_database_ips]
}

run "firewall_must_match_real_app_ip_list" {
  command   = apply
  state_key = "mismatched-firewall"
  variables {
    app_service_stage         = "prepare"
    postgres_network_migrated = true
    app_service_database_ips  = ["203.0.113.11"]
  }
  expect_failures = [azurerm_postgresql_flexible_server_firewall_rule.app_service]
}

run "activation_requires_stopping_old_workers" {
  command   = plan
  state_key = "old-workers-running"
  variables {
    app_service_stage         = "active"
    postgres_network_migrated = true
    app_service_database_ips  = ["203.0.113.10"]
  }
  expect_failures = [var.app_service_stage]
}
