# Mocked provider: these tests never authenticate to Azure or create resources.
mock_provider "azurerm" {
  mock_resource "azurerm_container_app_environment" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.App/managedEnvironments/test"
    }
  }
}

variables {
  name_prefix                            = "fsc-test"
  resource_group_name                    = "rg-test"
  location                               = "francecentral"
  container_apps_subnet_id               = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/test/subnets/apps"
  log_analytics_workspace_id             = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/test"
  application_identity_id                = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/test"
  application_identity_client_id         = "00000000-0000-0000-0000-000000000001"
  registry_login_server                  = "test.azurecr.io"
  deploy_application                     = true
  backend_image                          = "test.azurecr.io/fiscora-backend@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  database_password_secret_id            = "https://kv-test.vault.azure.net/secrets/database-password"
  jwt_signing_key_secret_id              = "https://kv-test.vault.azure.net/secrets/jwt-signing-key"
  mfa_encryption_key_secret_id           = "https://kv-test.vault.azure.net/secrets/mfa-encryption-key"
  smtp_password_secret_id                = "https://kv-test.vault.azure.net/secrets/smtp-password"
  frontend_public_url                    = "https://app.test.invalid"
  google_oauth_client_id                 = ""
  cors_allowed_origins                   = "https://app.test.invalid"
  malware_scan_enabled                   = true
  clamav_image                           = "clamav/clamav:1.4"
  application_insights_connection_string = ""

  database = {
    host = "test.postgres.database.azure.com"
    name = "accounting_nest"
    user = "fiscora_admin"
  }

  storage = {
    account_url    = "https://test.blob.core.windows.net"
    container_name = "accounting-documents"
  }

  smtp = {
    host = "smtp-relay.brevo.com"
    port = 587
    user = "test-smtp-user"
    from = "test@example.invalid"
  }

  ai = {
    extraction_enabled = false
    nuextract_url      = ""
    ocr_url            = ""
    azure_audience     = "api://test/fiscora-google-wif"
    google_audience    = ""
    service_account    = ""
    assistant_enabled  = false
    project_id         = "test-project"
    vertex_location    = "global"
    chat_model         = "test-chat-model"
    embedding_model    = "test-embedding-model"
  }
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
      one([for env in azurerm_container_app.api[0].template[0].container[0].env : env.value if env.name == "DB_HOST"]) == var.database.host,
      one([for env in azurerm_container_app.api[0].template[0].container[0].env : env.value if env.name == "DB_NAME"]) == var.database.name,
      one([for env in azurerm_container_app.api[0].template[0].container[0].env : env.value if env.name == "AZURE_STORAGE_ACCOUNT_URL"]) == var.storage.account_url,
      one([for env in azurerm_container_app.api[0].template[0].container[0].env : env.value if env.name == "SMTP_HOST"]) == var.smtp.host,
      one([for env in azurerm_container_app.api[0].template[0].container[0].env : env.value if env.name == "NUEXTRACT_SERVICE_URL"]) == var.ai.nuextract_url,
      one([for env in azurerm_container_app.api[0].template[0].container[0].env : env.value if env.name == "AI_ASSISTANT_MAX_VECTOR_DISTANCE"]) == "0.8",
    ])
    error_message = "Grouped settings must preserve runtime connection values and defaults."
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
