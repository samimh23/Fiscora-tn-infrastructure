# Temporary cutover controls. Defaults leave the existing deployment unchanged.
# Remove legacy resources/controls only after successful cutover and cleanup review.
variable "app_service_stage" {
  description = "off: current hosting only; prepare: quarantined App Service; active: run NestJS after DB migration and stopping the old backend."
  type        = string
  default     = "off"
  validation {
    condition     = contains(["off", "prepare", "active"], var.app_service_stage)
    error_message = "Use off, prepare or active."
  }
  validation {
    condition     = var.app_service_stage != "active" || (var.postgres_network_migrated && var.legacy_backend_stopped)
    error_message = "Activation requires completed PostgreSQL migration and confirmation that the legacy backend is stopped."
  }
}

variable "app_service_sku" {
  description = "Paid always-on Linux plan. B3 has 7 GB RAM for the existing 4 GB combined API/ClamAV allocation. Review regional price before apply."
  type        = string
  default     = "B3"
  validation {
    condition     = contains(["B3", "P1v3", "P2v3"], var.app_service_sku)
    error_message = "Choose a reviewed always-on SKU with enough memory for NestJS and ClamAV."
  }
}

variable "postgres_network_migrated" {
  description = "True only after Azure's network migration has completed and a refreshed plan confirms the existing server is not replaced."
  type        = bool
  default     = false
  validation {
    condition     = !var.postgres_network_migrated || length(var.app_service_database_ips) > 0
    error_message = "A migrated database requires prepared App Service and its reviewed outbound IP list."
  }
}

variable "app_service_database_ips" {
  description = "Exact possible outbound IPv4 list exported by the prepared App Service. Individual IPs only; no ranges, all-Azure rule or operator IPs."
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([for ip in var.app_service_database_ips :
      can(cidrhost("${ip}/32", 0)) && ip != "0.0.0.0" && ip != "255.255.255.255" && !strcontains(ip, "/") && !strcontains(ip, ":")
    ]) && length(distinct(var.app_service_database_ips)) == length(var.app_service_database_ips)
    error_message = "Use unique individual IPv4 addresses, never 0.0.0.0 or a CIDR/range."
  }
}

variable "legacy_backend_stopped" {
  description = "Operator acknowledgement that the old backend and workers are stopped before activating App Service. Never set merely to bypass validation."
  type        = bool
  default     = false
}

locals {
  prepare_app_service  = var.app_service_stage != "off"
  activate_app_service = var.app_service_stage == "active"
}
