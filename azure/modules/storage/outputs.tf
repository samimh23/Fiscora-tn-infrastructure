output "storage_account_id" { value = azurerm_storage_account.documents.id }
output "storage_account_name" { value = azurerm_storage_account.documents.name }
output "storage_account_url" { value = azurerm_storage_account.documents.primary_blob_endpoint }
output "container_name" { value = azurerm_storage_container.documents.name }
