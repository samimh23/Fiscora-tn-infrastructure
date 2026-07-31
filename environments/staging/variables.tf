variable "aws_region" {
  description = "AWS region where Fiscora staging resources are deployed."
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

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be staging or production."
  }
}

variable "vpc_cidr" {
  description = "CIDR block allocated to the staging VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block allocated to the public application subnet."
  type        = string
  default     = "10.20.10.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the initial low-cost staging instance."
  type        = string
  default     = "eu-north-1a"
}

variable "instance_type" {
  description = "EC2 instance type for the staging Docker host."
  type        = string
  default     = "t4g.small"
}

variable "ami_ssm_parameter" {
  description = "Public SSM parameter containing the Amazon Linux AMI for the instance architecture."
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

variable "root_volume_size" {
  description = "Encrypted root volume size in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 20
    error_message = "Root volume size must be at least 20 GiB."
  }
}
