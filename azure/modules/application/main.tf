resource "azurerm_container_app_environment" "this" {
  name                           = "cae-${var.name_prefix}"
  resource_group_name            = var.resource_group_name
  location                       = var.location
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  infrastructure_subnet_id       = var.container_apps_subnet_id
  internal_load_balancer_enabled = false
  tags                           = var.tags

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    minimum_count         = 0
    maximum_count         = 0
  }
}

resource "azurerm_container_app" "api" {
  count = var.deploy_application ? 1 : 0

  name                         = "ca-${var.name_prefix}-api"
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.this.id
  workload_profile_name        = "Consumption"
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.application_identity_id]
  }

  registry {
    server   = var.registry_login_server
    identity = var.application_identity_id
  }

  secret {
    name                = "database-password"
    key_vault_secret_id = var.database_password_secret_id
    identity            = var.application_identity_id
  }

  secret {
    name                = "jwt-signing-key"
    key_vault_secret_id = var.jwt_signing_key_secret_id
    identity            = var.application_identity_id
  }

  secret {
    name                = "smtp-password"
    key_vault_secret_id = var.smtp_password_secret_id
    identity            = var.application_identity_id
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
    min_replicas = 0
    max_replicas = 1

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
        value = var.cors_allowed_origins
      }
      env {
        name  = "DB_HOST"
        value = var.database_host
      }
      env {
        name  = "DB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_USER"
        value = var.database_user
      }
      env {
        name        = "DB_PASSWORD"
        secret_name = "database-password"
      }
      env {
        name  = "DB_NAME"
        value = var.database_name
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
        name  = "OBJECT_STORAGE_PROVIDER"
        value = "azure"
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = var.application_identity_client_id
      }
      env {
        name  = "AZURE_STORAGE_ACCOUNT_URL"
        value = var.storage_account_url
      }
      env {
        name  = "AZURE_STORAGE_CONTAINER"
        value = var.storage_container_name
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
        value = var.application_insights_connection_string
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
