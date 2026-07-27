variable "aws_region" {
  description = "AWS region used for the Terraform state bucket."
  type        = string
  default     = "eu-north-1"
}

variable "aws_profile" {
  description = "Local AWS SSO profile. CI overrides authentication with OIDC."
  type        = string
  default     = null
  nullable    = true
}

variable "project_name" {
  description = "Project identifier used in resource names and tags."
  type        = string
  default     = "fiscora"
}

variable "github_owner" {
  description = "GitHub repository owner allowed to request AWS credentials."
  type        = string
  default     = "samimh23"
}

variable "github_owner_id" {
  description = "Immutable GitHub numeric ID of the repository owner."
  type        = number
  default     = 80358238
}

variable "github_repository" {
  description = "GitHub infrastructure repository allowed to request AWS credentials."
  type        = string
  default     = "Fiscora-tn-infrastructure"
}

variable "github_repository_id" {
  description = "Immutable GitHub numeric ID of the infrastructure repository."
  type        = number
  default     = 1312800939
}
