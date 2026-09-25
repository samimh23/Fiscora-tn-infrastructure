locals {
  required_services = toset([
    "aiplatform.googleapis.com",
    "artifactregistry.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudbuild.googleapis.com",
    "logging.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "run.googleapis.com",
    "serviceusage.googleapis.com",
    "sts.googleapis.com",
  ])
}

data "google_project" "current" {
  project_id = var.project_id
}

resource "google_project_service" "required" {
  for_each = local.required_services

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "ai" {
  project       = var.project_id
  location      = var.region
  repository_id = "fiscora-ai"
  description   = "Private Fiscora document-inference images"
  format        = "DOCKER"

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "1209600s"
    }
  }

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 3
    }
  }

  depends_on = [google_project_service.required]
}

resource "google_service_account" "nuextract" {
  project      = var.project_id
  account_id   = "fiscora-nuextract"
  display_name = "Fiscora Qwen extraction runtime"

  depends_on = [google_project_service.required]
}

resource "google_service_account" "paddleocr" {
  project      = var.project_id
  account_id   = "fiscora-paddleocr"
  display_name = "Fiscora PaddleOCR runtime"

  depends_on = [google_project_service.required]
}

resource "google_service_account" "azure_api" {
  project      = var.project_id
  account_id   = "fiscora-azure-api"
  display_name = "Fiscora Azure API federated invoker"

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool" "azure" {
  project                   = var.project_id
  workload_identity_pool_id = "fiscora-azure"
  display_name              = "Fiscora Azure workloads"
  description               = "Keyless federation for the Fiscora Azure Container App managed identity."

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool_provider" "azure_container_apps" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.azure.workload_identity_pool_id
  workload_identity_pool_provider_id = "azure-container-apps"
  display_name                       = "Fiscora Azure Container Apps"
  description                        = "Accepts only the production API managed identity from the configured Entra tenant."

  attribute_mapping = {
    "google.subject"           = "assertion.sub"
    "attribute.azure_tenant"   = "assertion.tid"
    "attribute.azure_identity" = "assertion.sub"
  }
  attribute_condition = "assertion.sub == '${var.azure_managed_identity_object_id}' && assertion.tid == '${var.azure_tenant_id}'"

  oidc {
    issuer_uri        = "https://sts.windows.net/${var.azure_tenant_id}/"
    allowed_audiences = [var.azure_application_id_uri]
  }
}

resource "google_service_account_iam_member" "azure_api_workload_identity" {
  service_account_id = google_service_account.azure_api.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.azure.workload_identity_pool_id}/subject/${var.azure_managed_identity_object_id}"
}

resource "google_project_iam_member" "azure_api_vertex_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.azure_api.email}"

  depends_on = [google_project_service.required]
}

resource "google_billing_budget" "project" {
  count = var.billing_account_id == null ? 0 : 1

  billing_account = var.billing_account_id
  display_name    = "Fiscora AI monthly alert"

  budget_filter {
    projects = ["projects/${data.google_project.current.number}"]
    # Alert on gross usage even while the $300 trial credit masks the invoice.
    credit_types_treatment = "EXCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.monthly_budget_usd)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.8
  }
  threshold_rules {
    threshold_percent = 1.0
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = []
    enable_project_level_recipients  = true
  }

  depends_on = [google_project_service.required]
}

resource "google_cloud_run_v2_service" "nuextract" {
  provider = google-beta
  count    = var.enable_extraction_service ? 1 : 0

  project             = var.project_id
  name                = var.service_name
  location            = var.region
  deletion_protection = var.deletion_protection
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account                  = google_service_account.nuextract.email
    timeout                          = "600s"
    max_instance_request_concurrency = var.request_concurrency
    gpu_zonal_redundancy_disabled    = true

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    containers {
      name  = "qwen-extractor"
      image = var.extraction_image

      ports {
        name           = "http1"
        container_port = 8080
      }

      env {
        name  = "MAX_NUM_SEQS"
        value = tostring(var.max_num_seqs)
      }

      resources {
        cpu_idle          = false
        startup_cpu_boost = true
        limits = {
          cpu              = "4"
          memory           = "16Gi"
          "nvidia.com/gpu" = "1"
        }
      }

      startup_probe {
        failure_threshold     = 1800
        initial_delay_seconds = 0
        period_seconds        = 1
        timeout_seconds       = 1

        tcp_socket {
          port = 8080
        }
      }
    }

    node_selector {
      accelerator = "nvidia-l4"
    }
  }

  depends_on = [
    google_artifact_registry_repository.ai,
    google_project_service.required,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  provider = google-beta
  for_each = var.enable_extraction_service ? var.invoker_members : []

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.nuextract[0].name
  role     = "roles/run.invoker"
  member   = each.value
}

resource "google_cloud_run_v2_service_iam_member" "azure_api_invoker" {
  provider = google-beta
  count    = var.enable_extraction_service ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.nuextract[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.azure_api.email}"
}

resource "google_cloud_run_v2_service" "nuextract_candidate" {
  provider = google-beta
  count    = var.enable_nuextract_service ? 1 : 0

  project             = var.project_id
  name                = var.nuextract_service_name
  location            = var.region
  deletion_protection = var.deletion_protection
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account                  = google_service_account.nuextract.email
    timeout                          = "600s"
    max_instance_request_concurrency = var.nuextract_request_concurrency
    gpu_zonal_redundancy_disabled    = true

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    containers {
      name  = "nuextract-extractor"
      image = var.nuextract_image

      ports {
        name           = "http1"
        container_port = 8080
      }

      env {
        name  = "MAX_NUM_SEQS"
        value = tostring(var.nuextract_max_num_seqs)
      }

      resources {
        cpu_idle          = false
        startup_cpu_boost = true
        limits = {
          cpu              = "4"
          memory           = "16Gi"
          "nvidia.com/gpu" = "1"
        }
      }

      startup_probe {
        failure_threshold     = 1800
        initial_delay_seconds = 0
        period_seconds        = 1
        timeout_seconds       = 1

        tcp_socket {
          port = 8080
        }
      }
    }

    node_selector {
      accelerator = "nvidia-l4"
    }
  }

  depends_on = [
    google_artifact_registry_repository.ai,
    google_project_service.required,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "nuextract_candidate_invoker" {
  provider = google-beta
  for_each = var.enable_nuextract_service ? var.invoker_members : []

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.nuextract_candidate[0].name
  role     = "roles/run.invoker"
  member   = each.value
}

resource "google_cloud_run_v2_service_iam_member" "azure_api_nuextract_candidate_invoker" {
  provider = google-beta
  count    = var.enable_nuextract_service ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.nuextract_candidate[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.azure_api.email}"
}

resource "google_cloud_run_v2_service" "paddleocr" {
  provider = google-beta
  count    = var.enable_ocr_service ? 1 : 0

  project             = var.project_id
  name                = var.ocr_service_name
  location            = var.region
  deletion_protection = var.deletion_protection
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account                  = google_service_account.paddleocr.email
    timeout                          = "900s"
    max_instance_request_concurrency = 1

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    containers {
      name  = "paddleocr"
      image = var.ocr_image

      ports {
        name           = "http1"
        container_port = 8080
      }

      env {
        name  = "OCR_MAX_PDF_PAGES"
        value = "100"
      }

      env {
        name  = "OCR_PDF_RENDER_DPI"
        value = "250"
      }

      env {
        name  = "OCR_PAGE_BATCH_SIZE"
        value = "4"
      }

      resources {
        cpu_idle          = false
        startup_cpu_boost = true
        limits = {
          cpu    = "4"
          memory = "8Gi"
        }
      }

      startup_probe {
        failure_threshold     = 180
        initial_delay_seconds = 0
        period_seconds        = 2
        timeout_seconds       = 2

        http_get {
          path = "/health"
          port = 8080
        }
      }
    }
  }

  depends_on = [
    google_artifact_registry_repository.ai,
    google_project_service.required,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "paddleocr_invoker" {
  provider = google-beta
  for_each = var.enable_ocr_service ? var.invoker_members : []

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.paddleocr[0].name
  role     = "roles/run.invoker"
  member   = each.value
}

resource "google_cloud_run_v2_service_iam_member" "azure_api_paddleocr_invoker" {
  provider = google-beta
  count    = var.enable_ocr_service ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.paddleocr[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.azure_api.email}"
}
