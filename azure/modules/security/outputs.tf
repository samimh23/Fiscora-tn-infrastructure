output "application_identity_id" { value = azurerm_user_assigned_identity.application.id }
output "application_identity_client_id" { value = azurerm_user_assigned_identity.application.client_id }
output "application_identity_principal_id" { value = azurerm_user_assigned_identity.application.principal_id }
output "key_vault_id" { value = azurerm_key_vault.this.id }
output "key_vault_name" { value = azurerm_key_vault.this.name }
output "key_vault_uri" { value = azurerm_key_vault.this.vault_uri }
output "postgres_password" {
  value     = random_password.postgres.result
  sensitive = true
}
output "postgres_password_secret_id" {
  value     = azurerm_key_vault_secret.postgres_password.versionless_id
  sensitive = true
}
output "jwt_signing_key_secret_id" {
  value     = azurerm_key_vault_secret.jwt_signing_key.versionless_id
  sensitive = true
}
