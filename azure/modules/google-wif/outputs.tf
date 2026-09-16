output "application_id_uri" { value = tolist(azuread_application.google_wif.identifier_uris)[0] }
output "application_client_id" { value = azuread_application.google_wif.client_id }
output "service_principal_object_id" { value = azuread_service_principal.google_wif.object_id }
