# Azure staging: start here, then read the topic files in this directory.
# Terraform reads all .tf files together; filenames are not execution order.
# Application Insights, runtime settings and service identities are preserved.

# Names for our current staging deployment (terraform.tfvars, 7 October 2026):
# project_name = "fiscora", environment = "staging"
# deployment_suffix = "sami090", location = "francecentral"
# var.<name> reads one of those input values; local.<name> reuses a value below.
# These comments show the current results. Changing the inputs changes the names.

# Read the Azure account/tenant information from the authenticated provider.
data "azurerm_client_config" "current" {}

locals {
  # Current result: "fiscora-staging".
  name_prefix = "${var.project_name}-${var.environment}"
  # Join the three naming inputs, remove hyphens, lowercase, keep 19 characters.
  # Current result: "fiscorastagingsami0" (used for storage/registry names).
  compact = substr(lower(replace("${var.project_name}${var.environment}${var.deployment_suffix}", "-", "")), 0, 19)
  # Azure labels: Project = "fiscora", Environment = "staging".
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Repository  = "Fiscora-tn-infrastructure"
    DataClass   = "confidential-accounting"
  }
}

resource "azurerm_resource_group" "this" {
  # Azure name: "rg-fiscora-staging". "this" is only Terraform's internal label.
  name = "rg-${local.name_prefix}"
  # Current region: "francecentral" (France Central).
  location = var.location
  # Apply the labels defined in locals.tags above.
  tags = local.tags
}

# File map:
# security.tf: API identity, Key Vault and generated secrets
# deployment-access.tf: GitHub OIDC deployment identities
# google-auth.tf: keyless Azure -> Google authentication (AI still uses GCP)
# database.tf: same PostgreSQL server, database and extensions
# database-firewall.tf: exact App Service IP access to PostgreSQL
# storage.tf: uploaded documents
# hosting.tf: image registry and React frontend
# app-service.tf: live NestJS/ClamAV runtime and direct service connections
# monitoring.tf: Log Analytics, Application Insights and cost alerts
# moved.tf: backward-compatible addresses; never delete these mappings casually
