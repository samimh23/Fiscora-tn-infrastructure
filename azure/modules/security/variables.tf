variable "name_prefix" { type = string }
variable "key_vault_name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tenant_id" { type = string }
variable "terraform_principal_object_id" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
