# No firewall or public access is created by default.
# A reviewed, known IP list avoids unknown for_each keys during the cutover plan.
resource "azurerm_postgresql_flexible_server_firewall_rule" "app_service" {
  for_each = var.postgres_network_migrated ? {
    for index, ip in var.app_service_database_ips : format("app-service-%03d", index) => ip
  } : {}

  name             = each.key
  server_id        = azurerm_postgresql_flexible_server.postgres.id
  start_ip_address = each.value
  end_ip_address   = each.value

  lifecycle {
    precondition {
      condition = local.prepare_app_service ? toset(var.app_service_database_ips) == toset(split(",",
        nonsensitive(azapi_resource.app_service[0].output.properties.possibleOutboundIpAddresses)
      )) : false
      error_message = "Firewall IPs must exactly match the prepared App Service possible outbound IPs. Re-read the output after any plan/scale change."
    }
  }
}
