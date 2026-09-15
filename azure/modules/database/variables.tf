variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "delegated_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }
variable "administrator_login" {
  type    = string
  default = "fiscora_admin"
}
variable "administrator_password" {
  type      = string
  sensitive = true
}
variable "database_name" {
  type    = string
  default = "accounting_nest"
}
variable "postgres_version" {
  type    = string
  default = "16"
}
variable "sku_name" {
  type    = string
  default = "B_Standard_B1ms"
}
variable "storage_mb" {
  type    = number
  default = 32768
}
variable "allowed_extensions" {
  description = "PostgreSQL extensions allow-listed through Azure's azure.extensions server parameter."
  type        = list(string)
  default     = ["uuid-ossp"]
}
variable "tags" {
  type    = map(string)
  default = {}
}
