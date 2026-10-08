# Same PostgreSQL server, database, password and backups after network migration.
# Access is restricted by the exact App Service IP rules in database-firewall.tf.

resource "azurerm_postgresql_flexible_server" "postgres" {
  # Current Azure server: psql-fiscora-staging-sami090.
  name                = substr("psql-${local.name_prefix}-${var.deployment_suffix}", 0, 63)
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  version             = var.postgres_version
  # Production migration completed on 8 October 2026. Never restore old subnet IDs.
  delegated_subnet_id           = null
  private_dns_zone_id           = null
  public_network_access_enabled = var.postgres_network_migrated
  administrator_login           = "fiscora_admin"
  administrator_password        = random_password.postgres.result
  sku_name                      = var.postgres_sku_name
  storage_mb                    = 32768
  auto_grow_enabled             = false
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  tags                          = local.tags

  authentication {
    active_directory_auth_enabled = false
    password_auth_enabled         = true
  }

  maintenance_window {
    day_of_week  = 0
    start_hour   = 3
    start_minute = 0
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [zone]
    precondition {
      condition     = !var.postgres_network_migrated || local.prepare_app_service
      error_message = "Prepare App Service before reconciling migrated database networking."
    }
  }
}

resource "azurerm_postgresql_flexible_server_database" "application" {
  name      = "accounting_nest"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  value     = "uuid-ossp,vector"
}
