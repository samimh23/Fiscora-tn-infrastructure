# Azure staging: start here, then read the topic files in this directory.
# Terraform reads all .tf files together; filenames are not execution order.
# Application Insights, runtime settings and service identities are preserved.

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

# File map:
# network.tf: private network and database DNS
# security.tf: API identity, Key Vault and generated secrets
# deployment-access.tf: GitHub OIDC deployment identities
# google-auth.tf: keyless Azure -> Google authentication (AI still uses GCP)
# database.tf / storage.tf: business data and uploaded documents
# hosting.tf: image registry, React frontend and NestJS/ClamAV runtime
# monitoring.tf: Log Analytics, Application Insights and cost alerts
# moved.tf: backward-compatible addresses; never delete these mappings casually
