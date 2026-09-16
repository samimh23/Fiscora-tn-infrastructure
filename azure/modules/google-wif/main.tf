resource "random_uuid" "app_role" {}

resource "azuread_application" "google_wif" {
  display_name     = "${var.name_prefix}-google-workload-identity"
  sign_in_audience = "AzureADMyOrg"
  identifier_uris  = [var.application_id_uri]

  api {
    requested_access_token_version = 1
  }

  app_role {
    allowed_member_types = ["Application"]
    description          = "Allows the Fiscora API managed identity to federate into Google Cloud."
    display_name         = "Google Cloud workload identity"
    enabled              = true
    id                   = random_uuid.app_role.result
    value                = "GcpWorkloadIdentity"
  }
}

resource "azuread_service_principal" "google_wif" {
  client_id                    = azuread_application.google_wif.client_id
  app_role_assignment_required = true
}

resource "azuread_app_role_assignment" "application_identity" {
  app_role_id         = random_uuid.app_role.result
  principal_object_id = var.application_identity_principal_id
  resource_object_id  = azuread_service_principal.google_wif.object_id
}
