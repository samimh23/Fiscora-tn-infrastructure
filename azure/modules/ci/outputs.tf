output "backend_identity_id" { value = azurerm_user_assigned_identity.backend.id }
output "backend_client_id" { value = azurerm_user_assigned_identity.backend.client_id }
output "backend_principal_id" { value = azurerm_user_assigned_identity.backend.principal_id }
output "frontend_identity_id" { value = azurerm_user_assigned_identity.frontend.id }
output "frontend_client_id" { value = azurerm_user_assigned_identity.frontend.client_id }
output "frontend_principal_id" { value = azurerm_user_assigned_identity.frontend.principal_id }
