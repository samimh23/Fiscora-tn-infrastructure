variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "vnet_cidr" {
  type    = string
  default = "10.42.0.0/16"
}
variable "container_apps_subnet_cidr" {
  type    = string
  default = "10.42.0.0/23"
}
variable "postgres_subnet_cidr" {
  type    = string
  default = "10.42.4.0/24"
}
variable "tags" {
  type    = map(string)
  default = {}
}
