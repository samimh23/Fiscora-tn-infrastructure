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
