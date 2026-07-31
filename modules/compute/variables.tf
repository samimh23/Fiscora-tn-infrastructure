variable "name_prefix" {
  description = "Prefix applied to compute resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC hosting the Docker instance."
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet hosting the initial staging instance."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the Docker host."
  type        = string
}

variable "ami_ssm_parameter" {
  description = "Public SSM parameter containing the Amazon Linux AMI for the selected architecture."
  type        = string
}

variable "root_volume_size" {
  description = "Encrypted root volume size in GiB."
  type        = number
}

variable "ecr_repository_arn" {
  description = "ARN of the backend ECR repository."
  type        = string
}

variable "documents_bucket_arn" {
  description = "ARN of the private accounting-document bucket."
  type        = string
}

variable "web_bucket_arn" {
  description = "ARN of the private bucket containing deployment artifacts."
  type        = string
}
