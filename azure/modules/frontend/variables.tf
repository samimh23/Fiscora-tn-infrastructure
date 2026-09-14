variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "deployment_principal_id" { type = string }
variable "enable_custom_domain" {
  type    = bool
  default = false
}
variable "custom_domain" {
  type    = string
  default = "app.fiscora.me"
}
variable "tags" {
  type    = map(string)
  default = {}
}
