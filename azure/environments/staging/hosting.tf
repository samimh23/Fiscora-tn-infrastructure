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

# The only retained module: the API/ClamAV runtime has separate ownership tests.
module "application" {
  source = "../../modules/application"

  name_prefix                            = local.name_prefix
  resource_group_name                    = azurerm_resource_group.this.name
  location                               = azurerm_resource_group.this.location
  container_apps_subnet_id               = azurerm_subnet.container_apps.id
  log_analytics_workspace_id             = azurerm_log_analytics_workspace.logs.id
  application_identity_id                = azurerm_user_assigned_identity.application.id
  application_identity_client_id         = azurerm_user_assigned_identity.application.client_id
  registry_login_server                  = azurerm_container_registry.backend.login_server
  deploy_application                     = var.deploy_application
  backend_image                          = var.backend_image
  database_password_secret_id            = azurerm_key_vault_secret.postgres_password.versionless_id
  jwt_signing_key_secret_id              = azurerm_key_vault_secret.jwt_signing_key.versionless_id
  mfa_encryption_key_secret_id           = azurerm_key_vault_secret.mfa_encryption_key.versionless_id
  smtp_password_secret_id                = "${azurerm_key_vault.secrets.vault_uri}secrets/${var.smtp_password_secret_name}"
  frontend_public_url                    = var.frontend_public_url
  google_oauth_client_id                 = var.google_oauth_client_id
  cors_allowed_origins                   = join(",", distinct([var.frontend_public_url, "https://${azurerm_static_web_app.frontend.default_host_name}"]))
  malware_scan_enabled                   = var.malware_scan_enabled
  clamav_image                           = var.clamav_image
  application_insights_connection_string = azurerm_application_insights.api.connection_string
  tags                                   = local.tags

  database = {
    host = azurerm_postgresql_flexible_server.postgres.fqdn
    name = azurerm_postgresql_flexible_server_database.application.name
    user = azurerm_postgresql_flexible_server.postgres.administrator_login
  }

  storage = {
    account_url    = azurerm_storage_account.documents.primary_blob_endpoint
    container_name = azurerm_storage_container.documents.name
  }

  smtp = {
    host = var.smtp_host
    port = var.smtp_port
    user = var.smtp_user
    from = var.smtp_from
  }

  ai = {
    extraction_enabled  = var.document_extraction_enabled
    nuextract_url       = var.nuextract_service_url
    ocr_url             = var.paddle_ocr_service_url
    azure_audience      = tolist(azuread_application.google_wif.identifier_uris)[0]
    google_audience     = var.gcp_wif_provider_audience
    service_account     = var.gcp_wif_service_account
    assistant_enabled   = var.ai_assistant_enabled
    project_id          = var.gcp_project_id
    vertex_location     = var.vertex_ai_location
    chat_model          = var.vertex_ai_chat_model
    embedding_model     = var.vertex_ai_embedding_model
    max_vector_distance = var.ai_assistant_max_vector_distance
  }

  # Inputs already depend on the database and generated secrets.
  # Wait only for runtime preparation not referenced by those inputs.
  # Retain the intentional policy: protect document storage before starting the API.
  depends_on = [
    azurerm_postgresql_flexible_server_configuration.extensions,
    azurerm_role_assignment.application_pull,
    azurerm_role_assignment.application_documents,
    azurerm_role_assignment.application_key_vault_reader,
    azurerm_management_lock.documents,
  ]
}
