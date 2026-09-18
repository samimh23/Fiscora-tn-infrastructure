# Fiscora Qwen3.5 extraction on Google Cloud

This stack hosts `Qwen/Qwen3.5-4B` in non-thinking mode on one NVIDIA L4 with Cloud Run.
The web application and API remain on Azure; Google Cloud provides only the
private financial-document inference endpoint. The existing Cloud Run service
name remains `fiscora-nuextract` during the migration so its authenticated URL
and Azure Workload Identity Federation integration do not change.

## Safety defaults

- Minimum instances: `0` (scale to zero).
- Maximum instances: `1` (at most one L4).
- Request concurrency and vLLM sequence ceiling: `4`.
- GPU zonal redundancy: disabled.
- Public/unauthenticated access: disabled.
- Monthly budget alerts: 50%, 80%, 100%, and forecasted 100%.
- Deletion protection: enabled.

Budgets are alerts, not hard caps. The single-instance limit is the enforced GPU
cost guard. Closing a browser or local computer does not stop Cloud Run.

## Explicit pause and resume

```powershell
.\gcp\scripts\pause-extraction.ps1
.\gcp\scripts\resume-extraction.ps1
```

## Layout

```text
gcp/bootstrap/                     Protected GCS Terraform-state bucket
gcp/environments/ai-staging/       Artifact Registry, IAM, budget and Cloud Run
gcp/services/qwen/                 Pinned Qwen3.5 + vLLM image
gcp/scripts/                       Build, pause, resume and smoke tests
```

## Build and in-place deployment

Authenticate first and keep the existing private service URL:

```powershell
gcloud auth login
gcloud auth application-default login
gcloud config set project fiscora-ai
```

Build the image. The model revision is pinned so the deployment is
reproducible, and the weights are embedded to avoid downloading them during a
scale-from-zero cold start.

```powershell
.\gcp\scripts\build-qwen.ps1 -ProjectId fiscora-ai
```

Copy the immutable digest printed by the script into
`gcp/environments/ai-staging/terraform.tfvars` as `extraction_image`. Then:

```powershell
cd gcp\environments\ai-staging
terraform init "-backend-config=backend.hcl"
terraform validate
terraform plan "-out=qwen.tfplan"
terraform apply qwen.tfplan
```

The change creates a new Cloud Run revision behind the same private service.
If startup or health checks fail, Cloud Run does not send traffic to it and the
previous revision remains available for rollback.

## Smoke tests

```powershell
cd ..\..\..
.\gcp\scripts\smoke-test.ps1 -ProjectId fiscora-ai
.\gcp\scripts\smoke-extraction.ps1 `
  -ProjectId fiscora-ai `
  -ImagePath C:\path\to\non-sensitive-test-document.jpg
```

The extraction test checks authentication, image handling and JSON generation.
It does not certify accounting accuracy. The NestJS API still applies
deterministic validation and requires human review.

## Production integration

The Azure API exchanges its managed-identity token through Google Workload
Identity Federation. No Google service-account key is stored in Azure. Qwen is
called through vLLM's OpenAI-compatible API with deterministic sampling and a
strict JSON schema. Printed numbers are kept verbatim; Fiscora normalizes and
checks them after extraction.
