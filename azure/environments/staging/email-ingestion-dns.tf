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

resource "azurerm_dns_txt_record" "brevo_verification" {
  name                = "@"
  zone_name           = azurerm_dns_zone.email_ingestion.name
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 1800

  record {
    value = "brevo-code:1753947e2d761505660e27769db01ea6"
  }

  tags = local.tags
}

resource "azurerm_dns_cname_record" "brevo_dkim_1" {
  name                = "brevo1._domainkey"
  zone_name           = azurerm_dns_zone.email_ingestion.name
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 1800
  record              = "b1.inbox-fiscora-me.dkim.brevo.com"
  tags                = local.tags
}

resource "azurerm_dns_cname_record" "brevo_dkim_2" {
  name                = "brevo2._domainkey"
  zone_name           = azurerm_dns_zone.email_ingestion.name
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 1800
  record              = "b2.inbox-fiscora-me.dkim.brevo.com"
  tags                = local.tags
}

resource "azurerm_dns_txt_record" "brevo_dmarc" {
  name                = "_dmarc"
  zone_name           = azurerm_dns_zone.email_ingestion.name
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 1800

  record {
    value = "v=DMARC1; p=none; rua=mailto:rua@dmarc.brevo.com"
  }

  tags = local.tags
}
