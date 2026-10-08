# Address migration only: existing Azure IDs, secrets and data are retained.
# Keep these blocks so older staging state can upgrade without recreation.
# New installations ignore moves whose source address is absent.

moved {
  from = module.network.azurerm_virtual_network.this
  to   = azurerm_virtual_network.network
}

moved {
  from = module.network.azurerm_subnet.container_apps
  to   = azurerm_subnet.container_apps
}

moved {
  from = module.network.azurerm_subnet.postgres
  to   = azurerm_subnet.postgres
}

moved {
  from = module.network.azurerm_private_dns_zone.postgres
  to   = azurerm_private_dns_zone.postgres
}

moved {
  from = module.network.azurerm_private_dns_zone_virtual_network_link.postgres
  to   = azurerm_private_dns_zone_virtual_network_link.postgres
}

moved {
  from = module.security.azurerm_user_assigned_identity.application
  to   = azurerm_user_assigned_identity.application
}

moved {
  from = module.security.random_password.postgres
  to   = random_password.postgres
}

moved {
  from = module.security.random_password.jwt
  to   = random_password.jwt
}

moved {
  from = module.security.random_password.mfa_encryption
  to   = random_password.mfa_encryption
}

moved {
  from = module.security.azurerm_key_vault.this
  to   = azurerm_key_vault.secrets
}

moved {
  from = module.security.azurerm_role_assignment.terraform_key_vault_admin
  to   = azurerm_role_assignment.terraform_key_vault_admin
}

moved {
  from = module.security.azurerm_role_assignment.application_key_vault_reader
  to   = azurerm_role_assignment.application_key_vault_reader
}

moved {
  from = module.security.azurerm_key_vault_secret.postgres_password
  to   = azurerm_key_vault_secret.postgres_password
}

moved {
  from = module.security.azurerm_key_vault_secret.jwt_signing_key
  to   = azurerm_key_vault_secret.jwt_signing_key
}

moved {
  from = module.security.azurerm_key_vault_secret.mfa_encryption_key
  to   = azurerm_key_vault_secret.mfa_encryption_key
}

moved {
  from = module.ci.azurerm_user_assigned_identity.backend
  to   = azurerm_user_assigned_identity.backend
}

moved {
  from = module.ci.azurerm_user_assigned_identity.frontend
  to   = azurerm_user_assigned_identity.frontend
}

moved {
  from = module.ci.azurerm_federated_identity_credential.backend_main
  to   = azurerm_federated_identity_credential.backend_main
}

moved {
  from = module.ci.azurerm_federated_identity_credential.frontend_main
  to   = azurerm_federated_identity_credential.frontend_main
}

moved {
  from = module.ci.azurerm_role_assignment.backend_container_apps
  to   = azurerm_role_assignment.backend_container_apps
}

moved {
  from = module.google_wif.random_uuid.app_role
  to   = random_uuid.google_wif_role
}

moved {
  from = module.google_wif.azuread_application.google_wif
  to   = azuread_application.google_wif
}

moved {
  from = module.google_wif.azuread_service_principal.google_wif
  to   = azuread_service_principal.google_wif
}

moved {
  from = module.google_wif.azuread_app_role_assignment.application_identity
  to   = azuread_app_role_assignment.application_identity
}

moved {
  from = module.storage.azurerm_storage_account.documents
  to   = azurerm_storage_account.documents
}

moved {
  from = module.storage.azurerm_storage_container.documents
  to   = azurerm_storage_container.documents
}

moved {
  from = module.storage.azurerm_role_assignment.application_documents
  to   = azurerm_role_assignment.application_documents
}

moved {
  from = module.storage.azurerm_role_assignment.operator_documents
  to   = azurerm_role_assignment.operator_documents
}

moved {
  from = module.storage.azurerm_management_lock.documents
  to   = azurerm_management_lock.documents
}

moved {
  from = module.database.azurerm_postgresql_flexible_server.this
  to   = azurerm_postgresql_flexible_server.postgres
}

moved {
  from = module.database.azurerm_postgresql_flexible_server_database.application
  to   = azurerm_postgresql_flexible_server_database.application
}

moved {
  from = module.database.azurerm_postgresql_flexible_server_configuration.extensions
  to   = azurerm_postgresql_flexible_server_configuration.extensions
}

moved {
  from = module.registry.azurerm_container_registry.this
  to   = azurerm_container_registry.backend
}

moved {
  from = module.registry.azurerm_role_assignment.application_pull
  to   = azurerm_role_assignment.application_pull
}

moved {
  from = module.registry.azurerm_role_assignment.deployment_push
  to   = azurerm_role_assignment.deployment_push
}

moved {
  from = module.frontend.azurerm_static_web_app.this
  to   = azurerm_static_web_app.frontend
}

moved {
  from = module.frontend.azurerm_role_assignment.deployment
  to   = azurerm_role_assignment.deployment
}

moved {
  from = module.frontend.azurerm_static_web_app_custom_domain.this
  to   = azurerm_static_web_app_custom_domain.frontend
}

moved {
  from = module.monitoring.azurerm_log_analytics_workspace.this
  to   = azurerm_log_analytics_workspace.logs
}

moved {
  from = module.monitoring.azurerm_application_insights.this
  to   = azurerm_application_insights.api
}

moved {
  from = module.budget.azurerm_consumption_budget_resource_group.this
  to   = azurerm_consumption_budget_resource_group.monthly
}

# Final module flattening: preserve environment and counted API resource instances.
moved {
  from = module.application.azurerm_container_app_environment.this
  to   = azurerm_container_app_environment.application
}

moved {
  from = module.application.azurerm_container_app.api
  to   = azurerm_container_app.api
}
