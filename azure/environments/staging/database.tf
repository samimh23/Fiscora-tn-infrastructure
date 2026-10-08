# PostgreSQL in one place: private subnet/DNS, server, database and extensions.
# Existing names, passwords, networking and backups are unchanged.

resource "azurerm_subnet" "postgres" {
  name                 = "snet-postgresql"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = ["10.42.4.0/24"]

  delegation {
    name = "postgresql-flexible-server"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${local.name_prefix}-postgres-dns"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.network.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_postgresql_flexible_server" "postgres" {
  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres, azurerm_subnet.container_apps]
  # Current Azure server: psql-fiscora-staging-sami090.
  name                = substr("psql-${local.name_prefix}-${var.deployment_suffix}", 0, 63)
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  version             = var.postgres_version
  # Set the migration flag only AFTER the separately approved Azure CLI migration.
  # Before that operation, removing the subnet fields can propose replacement.
  delegated_subnet_id           = var.postgres_network_migrated ? null : azurerm_subnet.postgres.id
  private_dns_zone_id           = var.postgres_network_migrated ? null : azurerm_private_dns_zone.postgres.id
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
