# Migration target: same services/data, no VNet integration on the new backend.
# Default stage is off. prepare creates quarantined hosting; active requires cutover gates.
locals {
  app_service_settings = merge({
    NODE_ENV                                  = "production"
    PORT                                      = "3000"
    CORS_ALLOWED_ORIGINS                      = join(",", distinct([var.frontend_public_url, "https://${azurerm_static_web_app.frontend.default_host_name}"]))
    DB_HOST                                   = azurerm_postgresql_flexible_server.postgres.fqdn
    DB_PORT                                   = "5432"
    DB_USER                                   = azurerm_postgresql_flexible_server.postgres.administrator_login
    DB_PASSWORD                               = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.postgres_password.versionless_id})"
    DB_NAME                                   = azurerm_postgresql_flexible_server_database.application.name
    DB_SSL                                    = "true"
    DB_MIGRATIONS_RUN                         = "true"
    JWT_SIGNING_KEY                           = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.jwt_signing_key.versionless_id})"
    MFA_ENCRYPTION_KEY                        = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.mfa_encryption_key.versionless_id})"
    MFA_ISSUER                                = "Fiscora"
    JWT_ISSUER                                = "fiscora"
    JWT_AUDIENCE                              = "fiscora-api"
    JWT_ACCESS_MINUTES                        = "30"
    JWT_REFRESH_DAYS                          = "14"
    GOOGLE_OAUTH_CLIENT_ID                    = var.google_oauth_client_id
    OBJECT_STORAGE_PROVIDER                   = "azure"
    AZURE_CLIENT_ID                           = azurerm_user_assigned_identity.application.client_id
    AZURE_STORAGE_ACCOUNT_URL                 = azurerm_storage_account.documents.primary_blob_endpoint
    AZURE_STORAGE_CONTAINER                   = azurerm_storage_container.documents.name
    MALWARE_SCAN_ENABLED                      = tostring(var.malware_scan_enabled)
    CLAMAV_HOST                               = "localhost"
    CLAMAV_PORT                               = "3310"
    CLAMAV_TIMEOUT_MS                         = "30000"
    APP_PUBLIC_URL                            = var.frontend_public_url
    INVITATION_EXPOSE_LINK                    = "false"
    SMTP_HOST                                 = var.smtp_host
    SMTP_PORT                                 = tostring(var.smtp_port)
    SMTP_SECURE                               = "false"
    SMTP_USER                                 = var.smtp_user
    SMTP_PASSWORD                             = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault.secrets.vault_uri}secrets/${var.smtp_password_secret_name})"
    SMTP_FROM                                 = var.smtp_from
    APPLICATIONINSIGHTS_CONNECTION_STRING     = sensitive(azurerm_application_insights.api.connection_string)
    DOCUMENT_EXTRACTION_ENABLED               = tostring(var.document_extraction_enabled)
    NUEXTRACT_SERVICE_URL                     = var.nuextract_service_url
    PADDLE_OCR_SERVICE_URL                    = var.paddle_ocr_service_url
    NUEXTRACT_MODEL                           = "numind/NuExtract3"
    DOCUMENT_EXTRACTION_WORKER_CONCURRENCY    = "4"
    DOCUMENT_EXTRACTION_NUEXTRACT_CONCURRENCY = "2"
    DOCUMENT_EXTRACTION_OCR_BATCH_PAGES       = "4"
    DOCUMENT_EXTRACTION_OCR_BATCH_MAX_CHARS   = "28000"
    PADDLE_OCR_TIMEOUT_MS                     = "900000"
    AZURE_GCP_WIF_APP_ID_URI                  = tolist(azuread_application.google_wif.identifier_uris)[0]
    GCP_WIF_PROVIDER_AUDIENCE                 = var.gcp_wif_provider_audience
    GCP_WIF_SERVICE_ACCOUNT                   = var.gcp_wif_service_account
    AI_ASSISTANT_ENABLED                      = tostring(var.ai_assistant_enabled)
    GCP_PROJECT_ID                            = var.gcp_project_id
    VERTEX_AI_LOCATION                        = var.vertex_ai_location
    VERTEX_AI_CHAT_MODEL                      = var.vertex_ai_chat_model
    VERTEX_AI_EMBEDDING_MODEL                 = var.vertex_ai_embedding_model
    VERTEX_AI_EMBEDDING_DIMENSIONS            = "768"
    AI_ASSISTANT_MAX_VECTOR_DISTANCE          = var.ai_assistant_max_vector_distance
    VERTEX_AI_TIMEOUT_MS                      = "60000"
    DOCUMENT_EXTRACTION_MAX_ATTEMPTS          = "4"
    DOCUMENT_EXTRACTION_LEASE_MINUTES         = "30"
    }, {
    # No migrations or workers are permitted while the candidate is quarantined.
    DB_MIGRATIONS_RUN                   = tostring(local.activate_app_service)
    DOCUMENT_EXTRACTION_ENABLED         = tostring(local.activate_app_service && var.document_extraction_enabled)
    AI_ASSISTANT_ENABLED                = tostring(local.activate_app_service && var.ai_assistant_enabled)
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
  })
}

resource "azurerm_service_plan" "backend" {
  count               = local.prepare_app_service ? 1 : 0
  name                = "asp-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  os_type             = "Linux"
  sku_name            = var.app_service_sku
  worker_count        = 1
  tags                = local.tags
  lifecycle { prevent_destroy = true }
}

# AzAPI owns the entire site and sidecars: no competing AzureRM site_config owner.
resource "azapi_resource" "app_service" {
  count     = local.prepare_app_service ? 1 : 0
  type      = "Microsoft.Web/sites@2024-04-01"
  name      = "app-${local.name_prefix}-${var.deployment_suffix}"
  parent_id = azurerm_resource_group.this.id
  location  = azurerm_resource_group.this.location
  tags      = local.tags
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.application.id]
  }
  body = {
    # sitecontainers uses app,linux; Azure removes the legacy container kind.
    kind = "app,linux"
    properties = {
      # App Service returns this path segment lowercase; avoid a casing-only plan.
      serverFarmId              = replace(azurerm_service_plan.backend[0].id, "serverFarms", "serverfarms")
      reserved                  = true
      enabled                   = local.activate_app_service
      httpsOnly                 = true
      clientAffinityEnabled     = false
      keyVaultReferenceIdentity = azurerm_user_assigned_identity.application.id
      siteConfig = {
        linuxFxVersion    = "sitecontainers"
        alwaysOn          = true
        webSocketsEnabled = true
        minTlsVersion     = "1.2"
        ftpsState         = "Disabled"
        healthCheckPath   = "/health"
        appSettings       = [for name, value in local.app_service_settings : { name = name, value = value }]
      }
    }
  }
  response_export_values = ["properties.defaultHostName", "properties.possibleOutboundIpAddresses", "properties.state"]
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = var.deploy_application && length(var.backend_image) > 0 && var.malware_scan_enabled
      error_message = "Prepare App Service only with the existing API image and malware scanning enabled."
    }
  }
  depends_on = [azurerm_role_assignment.application_key_vault_reader]
}

resource "azapi_resource" "app_service_clamav" {
  count     = local.prepare_app_service ? 1 : 0
  type      = "Microsoft.Web/sites/sitecontainers@2024-04-01"
  name      = "clamav"
  parent_id = azapi_resource.app_service[0].id
  body = {
    properties = {
      image      = var.clamav_image
      isMain     = false
      authType   = "Anonymous"
      targetPort = "3310"
    }
  }
}

resource "azapi_resource" "app_service_api" {
  count     = local.prepare_app_service ? 1 : 0
  type      = "Microsoft.Web/sites/sitecontainers@2024-04-01"
  name      = "api"
  parent_id = azapi_resource.app_service[0].id
  body = {
    properties = {
      image                       = var.backend_image
      isMain                      = true
      authType                    = "UserAssigned"
      userManagedIdentityClientId = azurerm_user_assigned_identity.application.client_id
      targetPort                  = "3000"
      # Defense in depth: even if the prepared site is started, NestJS cannot run.
      startUpCommand = local.activate_app_service ? "" : "node -e setInterval(Function(),60000)"
    }
  }
  lifecycle {
    prevent_destroy = true
    # GitHub owns only API image releases, not startup or sidecar configuration.
    ignore_changes = [body.properties.image]
  }
  depends_on = [
    azapi_resource.app_service_clamav,
    azurerm_role_assignment.application_pull,
    azurerm_role_assignment.application_documents,
    azurerm_postgresql_flexible_server_firewall_rule.app_service,
  ]
}

# Azure creates these policies with the site; update them rather than create duplicates.
resource "azapi_update_resource" "app_service_basic_auth" {
  for_each  = local.prepare_app_service ? toset(["ftp", "scm"]) : toset([])
  type      = "Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-04-01"
  name      = each.key
  parent_id = azapi_resource.app_service[0].id
  body      = { properties = { allow = false } }
}

resource "azurerm_role_assignment" "backend_app_service" {
  count                = local.prepare_app_service ? 1 : 0
  scope                = azapi_resource.app_service[0].id
  role_definition_name = "Website Contributor"
  principal_id         = azurerm_user_assigned_identity.backend.principal_id
}

output "app_service_name" { value = try(azapi_resource.app_service[0].name, null) }
output "app_service_url" { value = try("https://${azapi_resource.app_service[0].output.properties.defaultHostName}", null) }
output "app_service_database_ips" {
  value       = try(split(",", nonsensitive(azapi_resource.app_service[0].output.properties.possibleOutboundIpAddresses)), [])
  description = "Review and copy this exact list to app_service_database_ips before enabling migrated PostgreSQL networking."
}
