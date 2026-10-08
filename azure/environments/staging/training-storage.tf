# Private, separate dataset container. The existing application identity already
# has Storage Blob Data Contributor on this storage account; no new identity or secret.
resource "azurerm_storage_container" "training_datasets" {
  name                  = "training-datasets"
  storage_account_id    = azurerm_storage_account.documents.id
  container_access_type = "private"
}
