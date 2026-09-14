variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "resource_group_id" { type = string }
variable "location" { type = string }
variable "github_owner" { type = string }
variable "github_repositories" { type = set(string) }
variable "tags" {
  type    = map(string)
  default = {}
}
