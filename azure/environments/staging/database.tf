# database: unchanged services, declared directly in staging.
resource "azurerm_postgresql_flexible_server" "postgres" {
  depends_on                    = [azurerm_private_dns_zone_virtual_network_link.postgres, azurerm_subnet.container_apps]
  name                          = substr("psql-${local.name_prefix}-${var.deployment_suffix}", 0, 63)
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  version                       = var.postgres_version
  delegated_subnet_id           = azurerm_subnet.postgres.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false
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
  value     = join(",", ["uuid-ossp", "vector"])
}
