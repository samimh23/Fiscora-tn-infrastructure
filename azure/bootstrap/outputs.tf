output "state_resource_group_name" {
  value = azurerm_resource_group.state.name
}

output "state_storage_account_name" {
  value = azurerm_storage_account.state.name
}

output "state_container_name" {
  value = azurerm_storage_container.state.name
}

output "github_terraform_plan_client_id" {
  value = azurerm_user_assigned_identity.terraform_plan.client_id
}

output "azure_tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}
