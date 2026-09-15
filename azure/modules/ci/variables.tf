variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "resource_group_id" { type = string }
variable "location" { type = string }
variable "github_owner" { type = string }
variable "github_owner_id" { type = string }
variable "github_backend_repository" { type = string }
variable "github_backend_repository_id" { type = string }
variable "github_frontend_repository" { type = string }
variable "github_frontend_repository_id" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
