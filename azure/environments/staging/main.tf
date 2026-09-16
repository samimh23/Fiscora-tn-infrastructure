data "azurerm_client_config" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  compact     = substr(lower(replace("${var.project_name}${var.environment}${var.deployment_suffix}", "-", "")), 0, 19)
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Repository  = "Fiscora-tn-infrastructure"
    DataClass   = "confidential-accounting"
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "../../modules/network"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  daily_quota_gb      = 0.1
  tags                = local.tags
}

module "security" {
  source = "../../modules/security"

  name_prefix                   = local.name_prefix
  key_vault_name                = substr("kv-${local.compact}", 0, 24)
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  terraform_principal_object_id = var.operator_object_id
  tags                          = local.tags
}

module "google_wif" {
  source = "../../modules/google-wif"

  name_prefix                       = local.name_prefix
  application_id_uri                = var.azure_gcp_wif_app_id_uri
  application_identity_principal_id = module.security.application_identity_principal_id
}

module "ci" {
  source = "../../modules/ci"

  name_prefix                   = local.name_prefix
  resource_group_name           = azurerm_resource_group.this.name
  resource_group_id             = azurerm_resource_group.this.id
  location                      = azurerm_resource_group.this.location
  github_owner                  = var.github_owner
  github_owner_id               = var.github_owner_id
  github_backend_repository     = var.github_backend_repository
  github_backend_repository_id  = var.github_backend_repository_id
  github_frontend_repository    = var.github_frontend_repository
  github_frontend_repository_id = var.github_frontend_repository_id
  tags                          = local.tags
}

module "registry" {
  source = "../../modules/registry"

  name                     = substr("acr${local.compact}", 0, 50)
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  application_principal_id = module.security.application_identity_principal_id
  deployment_principal_id  = module.ci.backend_principal_id
  tags                     = local.tags
}

module "storage" {
  source = "../../modules/storage"

  name                     = substr("st${local.compact}docs", 0, 24)
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  application_principal_id = module.security.application_identity_principal_id
  operator_principal_id    = var.operator_object_id
  tags                     = local.tags
}

module "database" {
  source = "../../modules/database"

  name                   = substr("psql-${local.name_prefix}-${var.deployment_suffix}", 0, 63)
  resource_group_name    = azurerm_resource_group.this.name
  location               = azurerm_resource_group.this.location
  delegated_subnet_id    = module.network.postgres_subnet_id
  private_dns_zone_id    = module.network.postgres_private_dns_zone_id
  administrator_login    = "fiscora_admin"
  administrator_password = module.security.postgres_password
  database_name          = "accounting_nest"
  postgres_version       = var.postgres_version
  sku_name               = var.postgres_sku_name
  allowed_extensions     = ["uuid-ossp", "vector"]
  tags                   = local.tags

  depends_on = [module.network]
}

module "frontend" {
  source = "../../modules/frontend"

  name                    = "swa-${local.name_prefix}-${var.deployment_suffix}"
  resource_group_name     = azurerm_resource_group.this.name
  location                = var.static_web_app_location
  deployment_principal_id = module.ci.frontend_principal_id
  enable_custom_domain    = var.enable_custom_domains
  custom_domain           = var.frontend_custom_domain
  tags                    = local.tags
}

module "application" {
  source = "../../modules/application"

  name_prefix                            = local.name_prefix
  resource_group_name                    = azurerm_resource_group.this.name
  location                               = azurerm_resource_group.this.location
  container_apps_subnet_id               = module.network.container_apps_subnet_id
  log_analytics_workspace_id             = module.monitoring.log_analytics_workspace_id
  application_identity_id                = module.security.application_identity_id
  application_identity_client_id         = module.security.application_identity_client_id
  registry_login_server                  = module.registry.login_server
  deploy_application                     = var.deploy_application
  backend_image                          = var.backend_image
  database_host                          = module.database.fqdn
  database_name                          = module.database.database_name
  database_user                          = module.database.administrator_login
  database_password_secret_id            = module.security.postgres_password_secret_id
  jwt_signing_key_secret_id              = module.security.jwt_signing_key_secret_id
  smtp_password_secret_id                = "${module.security.key_vault_uri}secrets/${var.smtp_password_secret_name}"
  storage_account_url                    = module.storage.storage_account_url
  storage_container_name                 = module.storage.container_name
  frontend_public_url                    = var.frontend_public_url
  cors_allowed_origins                   = join(",", distinct([var.frontend_public_url, "https://${module.frontend.default_hostname}"]))
  smtp_host                              = var.smtp_host
  smtp_port                              = var.smtp_port
  smtp_user                              = var.smtp_user
  smtp_from                              = var.smtp_from
  malware_scan_enabled                   = var.malware_scan_enabled
  clamav_image                           = var.clamav_image
  application_insights_connection_string = module.monitoring.application_insights_connection_string
  document_extraction_enabled            = var.document_extraction_enabled
  nuextract_service_url                  = var.nuextract_service_url
  azure_gcp_wif_app_id_uri               = module.google_wif.application_id_uri
  gcp_wif_provider_audience              = var.gcp_wif_provider_audience
  gcp_wif_service_account                = var.gcp_wif_service_account
  ai_assistant_enabled                   = var.ai_assistant_enabled
  gcp_project_id                         = var.gcp_project_id
  vertex_ai_location                     = var.vertex_ai_location
  vertex_ai_chat_model                   = var.vertex_ai_chat_model
  vertex_ai_embedding_model              = var.vertex_ai_embedding_model
  tags                                   = local.tags

  depends_on = [module.database, module.registry, module.storage]
}

module "budget" {
  source = "../../modules/budget"

  name              = "budget-${local.name_prefix}-startup-credit"
  resource_group_id = azurerm_resource_group.this.id
  amount            = var.budget_amount_usd
  start_date        = var.budget_start_date
  end_date          = var.budget_end_date
  contact_emails    = var.budget_contact_emails
}
