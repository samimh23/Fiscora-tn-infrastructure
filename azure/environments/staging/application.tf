# NestJS + ClamAV runtime. Direct resource references replace module input forwarding.
# Existing Azure resources are retained through moved.tf; GitHub still owns API releases.

resource "azurerm_container_app_environment" "application" {
  # Preserve the former module-wide preparation order for both runtime resources.
  depends_on = [
    azurerm_postgresql_flexible_server_configuration.extensions,
    azurerm_role_assignment.application_pull,
    azurerm_role_assignment.application_documents,
    azurerm_role_assignment.application_key_vault_reader,
    azurerm_management_lock.documents,
  ]

  name                           = "cae-${local.name_prefix}"
  resource_group_name            = azurerm_resource_group.this.name
  location                       = azurerm_resource_group.this.location
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.logs.id
  infrastructure_subnet_id       = azurerm_subnet.container_apps.id
  internal_load_balancer_enabled = false
  tags                           = local.tags

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    minimum_count         = 0
    maximum_count         = 0
  }
}

resource "azurerm_container_app" "api" {
  # Preserve the former module-wide preparation order for both runtime resources.
  depends_on = [
    azurerm_postgresql_flexible_server_configuration.extensions,
    azurerm_role_assignment.application_pull,
    azurerm_role_assignment.application_documents,
    azurerm_role_assignment.application_key_vault_reader,
    azurerm_management_lock.documents,
  ]

  count = var.deploy_application ? 1 : 0

  name                         = "ca-${local.name_prefix}-api"
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = azurerm_container_app_environment.application.id
  workload_profile_name        = "Consumption"
  revision_mode                = "Single"
  tags                         = local.tags

  lifecycle {
    # Terraform owns infrastructure/settings; GitHub owns API releases after creation.
    # Ignore only the API image, never the entire template or the ClamAV image.
    ignore_changes  = [template[0].container[0].image]
    prevent_destroy = true

    postcondition {
      condition     = self.template[0].container[0].name == "api"
      error_message = "The API must remain the first container for narrow image ownership."
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.application.id]
  }

  registry {
    server   = azurerm_container_registry.backend.login_server
    identity = azurerm_user_assigned_identity.application.id
  }

  secret {
    name                = "database-password"
    key_vault_secret_id = sensitive(azurerm_key_vault_secret.postgres_password.versionless_id)
    identity            = azurerm_user_assigned_identity.application.id
  }

  secret {
    name                = "jwt-signing-key"
    key_vault_secret_id = sensitive(azurerm_key_vault_secret.jwt_signing_key.versionless_id)
    identity            = azurerm_user_assigned_identity.application.id
  }

  secret {
    name                = "mfa-encryption-key"
    key_vault_secret_id = sensitive(azurerm_key_vault_secret.mfa_encryption_key.versionless_id)
    identity            = azurerm_user_assigned_identity.application.id
  }

  secret {
    name                = "smtp-password"
    key_vault_secret_id = sensitive("${azurerm_key_vault.secrets.vault_uri}secrets/${var.smtp_password_secret_name}")
    identity            = azurerm_user_assigned_identity.application.id
  }

  ingress {
    external_enabled           = true
    allow_insecure_connections = false
    target_port                = 3000
    transport                  = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas               = 0
    max_replicas               = 1
    cooldown_period_in_seconds = 600

    container {
      name   = "api"
      image  = var.backend_image
      cpu    = 1
      memory = "2Gi"

      env {
        name  = "NODE_ENV"
        value = "production"
      }
      env {
        name  = "PORT"
        value = "3000"
      }
      env {
        name  = "CORS_ALLOWED_ORIGINS"
        value = join(",", distinct([var.frontend_public_url, "https://${azurerm_static_web_app.frontend.default_host_name}"]))
      }
      env {
        name  = "DB_HOST"
        value = azurerm_postgresql_flexible_server.postgres.fqdn
      }
      env {
        name  = "DB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_USER"
        value = azurerm_postgresql_flexible_server.postgres.administrator_login
      }
      env {
        name        = "DB_PASSWORD"
        secret_name = "database-password"
      }
      env {
        name  = "DB_NAME"
        value = azurerm_postgresql_flexible_server_database.application.name
      }
      env {
        name  = "DB_SSL"
        value = "true"
      }
      env {
        name  = "DB_MIGRATIONS_RUN"
        value = "true"
      }
      env {
        name        = "JWT_SIGNING_KEY"
        secret_name = "jwt-signing-key"
      }
      env {
        name        = "MFA_ENCRYPTION_KEY"
        secret_name = "mfa-encryption-key"
      }
      env {
        name  = "MFA_ISSUER"
        value = "Fiscora"
      }
      env {
        name  = "JWT_ISSUER"
        value = "fiscora"
      }
      env {
        name  = "JWT_AUDIENCE"
        value = "fiscora-api"
      }
      env {
        name  = "JWT_ACCESS_MINUTES"
        value = "30"
      }
      env {
        name  = "JWT_REFRESH_DAYS"
        value = "14"
      }
      env {
        name  = "GOOGLE_OAUTH_CLIENT_ID"
        value = var.google_oauth_client_id
      }
      env {
        name  = "OBJECT_STORAGE_PROVIDER"
        value = "azure"
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.application.client_id
      }
      env {
        name  = "AZURE_STORAGE_ACCOUNT_URL"
        value = azurerm_storage_account.documents.primary_blob_endpoint
      }
      env {
        name  = "AZURE_STORAGE_CONTAINER"
        value = azurerm_storage_container.documents.name
      }
      env {
        name  = "MALWARE_SCAN_ENABLED"
        value = tostring(var.malware_scan_enabled)
      }
      env {
        name  = "CLAMAV_HOST"
        value = "localhost"
      }
      env {
        name  = "CLAMAV_PORT"
        value = "3310"
      }
      env {
        name  = "CLAMAV_TIMEOUT_MS"
        value = "30000"
      }
      env {
        name  = "APP_PUBLIC_URL"
        value = var.frontend_public_url
      }
      env {
        name  = "INVITATION_EXPOSE_LINK"
        value = "false"
      }
      env {
        name  = "SMTP_HOST"
        value = var.smtp_host
      }
      env {
        name  = "SMTP_PORT"
        value = tostring(var.smtp_port)
      }
      env {
        name  = "SMTP_SECURE"
        value = "false"
      }
      env {
        name  = "SMTP_USER"
        value = var.smtp_user
      }
      env {
        name        = "SMTP_PASSWORD"
        secret_name = "smtp-password"
      }
      env {
        name  = "SMTP_FROM"
        value = var.smtp_from
      }
      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = sensitive(azurerm_application_insights.api.connection_string)
      }
      env {
        name  = "DOCUMENT_EXTRACTION_ENABLED"
        value = tostring(var.document_extraction_enabled)
      }
      env {
        name  = "NUEXTRACT_SERVICE_URL"
        value = var.nuextract_service_url
      }


      env {
        name  = "PADDLE_OCR_SERVICE_URL"
        value = var.paddle_ocr_service_url
      }

      env {
        name  = "NUEXTRACT_MODEL"
        value = "numind/NuExtract3"
      }
      env {
        name  = "DOCUMENT_EXTRACTION_WORKER_CONCURRENCY"
        value = "4"
      }
      env {
        name  = "DOCUMENT_EXTRACTION_NUEXTRACT_CONCURRENCY"
        value = "2"
      }
      env {
        name  = "DOCUMENT_EXTRACTION_OCR_BATCH_PAGES"
        value = "4"
      }
      env {
        name  = "DOCUMENT_EXTRACTION_OCR_BATCH_MAX_CHARS"
        value = "28000"
      }
      env {
        name  = "PADDLE_OCR_TIMEOUT_MS"
        value = "900000"
      }
      env {
        name  = "AZURE_GCP_WIF_APP_ID_URI"
        value = tolist(azuread_application.google_wif.identifier_uris)[0]
      }
      env {
        name  = "GCP_WIF_PROVIDER_AUDIENCE"
        value = var.gcp_wif_provider_audience
      }
      env {
        name  = "GCP_WIF_SERVICE_ACCOUNT"
        value = var.gcp_wif_service_account
      }
      env {
        name  = "AI_ASSISTANT_ENABLED"
        value = tostring(var.ai_assistant_enabled)
      }
      env {
        name  = "GCP_PROJECT_ID"
        value = var.gcp_project_id
      }
      env {
        name  = "VERTEX_AI_LOCATION"
        value = var.vertex_ai_location
      }
      env {
        name  = "VERTEX_AI_CHAT_MODEL"
        value = var.vertex_ai_chat_model
      }
      env {
        name  = "VERTEX_AI_EMBEDDING_MODEL"
        value = var.vertex_ai_embedding_model
      }
      env {
        name  = "VERTEX_AI_EMBEDDING_DIMENSIONS"
        value = "768"
      }
      env {
        name  = "AI_ASSISTANT_MAX_VECTOR_DISTANCE"
        value = var.ai_assistant_max_vector_distance
      }
      env {
        name  = "VERTEX_AI_TIMEOUT_MS"
        value = "60000"
      }
      env {
        name  = "DOCUMENT_EXTRACTION_MAX_ATTEMPTS"
        value = "4"
      }
      env {
        name  = "DOCUMENT_EXTRACTION_LEASE_MINUTES"
        value = "30"
      }

      startup_probe {
        transport               = "HTTP"
        port                    = 3000
        path                    = "/health"
        interval_seconds        = 5
        timeout                 = 3
        failure_count_threshold = 20
      }

      readiness_probe {
        transport               = "HTTP"
        port                    = 3000
        path                    = "/health"
        interval_seconds        = 10
        timeout                 = 3
        failure_count_threshold = 3
      }

      liveness_probe {
        transport               = "HTTP"
        port                    = 3000
        path                    = "/health"
        initial_delay           = 10
        interval_seconds        = 30
        timeout                 = 5
        failure_count_threshold = 3
      }
    }

    dynamic "container" {
      for_each = var.malware_scan_enabled ? [1] : []

      content {
        name   = "clamav"
        image  = var.clamav_image
        cpu    = 1
        memory = "2Gi"

        startup_probe {
          transport               = "TCP"
          port                    = 3310
          interval_seconds        = 10
          timeout                 = 5
          failure_count_threshold = 30
        }

        readiness_probe {
          transport               = "TCP"
          port                    = 3310
          interval_seconds        = 10
          timeout                 = 5
          failure_count_threshold = 3
        }

        liveness_probe {
          transport               = "TCP"
          port                    = 3310
          initial_delay           = 60
          interval_seconds        = 30
          timeout                 = 5
          failure_count_threshold = 3
        }
      }
    }
  }
}
