variable "azure_subscription_id" {
  description = "Azure subscription that owns the Terraform state resources."
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Azure region for the Terraform state resources."
  type        = string
  default     = "francecentral"
}

variable "state_resource_group_name" {
  description = "Resource group dedicated to Terraform state."
  type        = string
  default     = "rg-fiscora-tfstate"
}

variable "state_storage_account_name" {
  description = "Globally unique, lowercase storage account name for Terraform state."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.state_storage_account_name))
    error_message = "The state storage account name must contain 3-24 lowercase letters or digits."
  }
}

variable "github_owner" {
  description = "GitHub owner allowed to request Terraform plan credentials."
  type        = string
  default     = "samimh23"
}

variable "github_owner_id" {
  description = "Immutable numeric GitHub owner ID included in OIDC subject claims."
  type        = string
}

variable "github_infrastructure_repository" {
  description = "Infrastructure repository allowed to plan the Azure stack from main and pull requests."
  type        = string
  default     = "Fiscora-tn-infrastructure"
}

variable "github_infrastructure_repository_id" {
  description = "Immutable numeric GitHub infrastructure repository ID included in OIDC subject claims."
  type        = string
}
