variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "application_principal_id" { type = string }
variable "operator_principal_id" { type = string }
variable "container_name" {
  type    = string
  default = "accounting-documents"
}
variable "tags" {
  type    = map(string)
  default = {}
}
