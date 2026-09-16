resource "azurerm_dns_zone" "email_ingestion" {
  name                = var.email_ingestion_domain
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_dns_mx_record" "brevo_inbound" {
  name                = "@"
  zone_name           = azurerm_dns_zone.email_ingestion.name
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 1800

  record {
    preference = 10
    exchange   = "inbound1.sendinblue.com"
  }

  record {
    preference = 20
    exchange   = "inbound2.sendinblue.com"
  }

  tags = local.tags
}
