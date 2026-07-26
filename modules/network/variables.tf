variable "name_prefix" {
  description = "Prefix applied to network resource names."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block assigned to the VPC."
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block assigned to the public subnet."
  type        = string
}

variable "availability_zone" {
  description = "Availability zone hosting the initial public subnet."
  type        = string
}

