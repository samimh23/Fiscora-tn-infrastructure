variable "name" { type = string }
variable "resource_group_id" { type = string }
variable "amount" { type = number }
variable "start_date" { type = string }
variable "end_date" { type = string }
variable "contact_emails" { type = list(string) }
