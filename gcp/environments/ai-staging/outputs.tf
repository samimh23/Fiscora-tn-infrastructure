output "artifact_repository" {
  description = "Artifact Registry repository that stores document-inference images."
  value       = google_artifact_registry_repository.ai.name
}

output "extraction_service_uri" {
  description = "Private Cloud Run URI, or null while the GPU service is disabled."
  value = coalesce(
    try(google_cloud_run_v2_service.nuextract[0].uri, null),
    try(google_cloud_run_v2_service.nuextract[0].urls[0], null),
  )
}

output "ocr_service_uri" {
  description = "Private PaddleOCR Cloud Run URI, or null while disabled."
  value = coalesce(
    try(google_cloud_run_v2_service.paddleocr[0].uri, null),
    try(google_cloud_run_v2_service.paddleocr[0].urls[0], null),
  )
}

output "nuextract_service_uri" {
  description = "Private NuExtract 2.0 candidate URI, or null while disabled."
  value = coalesce(
    try(google_cloud_run_v2_service.nuextract_candidate[0].uri, null),
    try(google_cloud_run_v2_service.nuextract_candidate[0].urls[0], null),
  )
}

output "gpu_cost_gate" {
  description = "Whether Terraform is currently allowed to create the GPU service."
  value       = var.enable_extraction_service
}

output "runtime_service_account" {
  description = "Identity used by the private extraction service."
  value       = google_service_account.nuextract.email
}

output "azure_invoker_service_account" {
  description = "Google service account impersonated by the Azure API."
  value       = google_service_account.azure_api.email
}

output "azure_wif_provider_audience" {
  description = "Canonical provider audience configured in the Azure API."
  value       = "//iam.googleapis.com/${google_iam_workload_identity_pool_provider.azure_container_apps.name}"
}
