# Fiscora document extraction on Google Cloud

This stack keeps `Qwen/Qwen3.5-4B` and `numind/NuExtract-2.0-8B` in separate,
private, scale-to-zero Cloud Run services. PP-OCRv6-medium runs on a separate CPU
service and supplies trusted text coordinates for visual highlights.
The web application and API remain on Azure; Google Cloud provides only the
private financial-document inference endpoint. The existing Cloud Run service
name remains `fiscora-nuextract` for backward compatibility even though it runs
Qwen. The actual NuExtract candidate is `fiscora-nuextract-v2`.

## Safety defaults

- Minimum instances: `0` (scale to zero).
- Maximum instances: `1` (at most one L4).
- PaddleOCR is private, CPU-only, scale-to-zero, and limited to one request and
  one instance so it cannot create an uncontrolled fleet. It accepts JPEG, PNG
  and PDF documents, and renders PDF pages with PDFium in bounded four-page
  memory batches at 250 DPI before applying PaddleOCR.
- Qwen request concurrency and vLLM sequence ceiling: `4`; NuExtract: `2`.
- NestJS admits at most four Qwen calls at once; vLLM continuously batches those
  sequences. Multi-page OCR tokens are mapped in four-page Qwen batches and
  merged deterministically before accounting validation.
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
gcp/services/nuextract/            Pinned NuExtract 2.0 + vLLM image
gcp/services/paddleocr/            PP-OCRv6 coordinate service
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
.\gcp\scripts\build-nuextract.ps1 -ProjectId fiscora-ai
.\gcp\scripts\build-paddleocr.ps1 -ProjectId fiscora-ai
```

Copy the immutable digests printed by the scripts into
`gcp/environments/ai-staging/terraform.tfvars`. Qwen uses `extraction_image`,
NuExtract uses `nuextract_image`, and OCR uses `ocr_image`. Each service has an
independent enable flag:

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
.\gcp\scripts\smoke-paddleocr.ps1 `
  -ProjectId fiscora-ai `
  -DocumentPath C:\path\to\non-sensitive-test-document.pdf
.\gcp\scripts\smoke-extraction.ps1 `
  -ProjectId fiscora-ai `
  -ImagePath C:\path\to\non-sensitive-test-document.jpg
.\gcp\scripts\smoke-nuextract.ps1 `
  -ProjectId fiscora-ai `
  -ImagePath C:\path\to\non-sensitive-test-document.jpg
```

The extraction test checks authentication, image handling and JSON generation.
It does not certify accounting accuracy. The NestJS API still applies
deterministic validation and requires human review.

## Production integration

The Azure API exchanges its managed-identity token through Google Workload
Identity Federation. No Google service-account key is stored in Azure. Both
models use vLLM's OpenAI-compatible API. NuExtract receives the selected invoice
or bank-statement template; generic document categories continue to use Qwen.
The API accepts a visual highlight only when an extracted value has one unique,
high-confidence PaddleOCR match.
Printed numbers are kept verbatim; Fiscora normalizes and checks them after
extraction.

After applying GCP, copy the `ocr_service_uri` output into Azure staging as
`paddle_ocr_service_url`, then apply the Azure stack. If the URL is empty or OCR
fails, extraction still works but the review screen deliberately shows no
uncertain highlight.

## Provider switch and rollback

The Azure API selects the provider with one setting:

```hcl
document_extraction_provider = "nuextract" # or "qwen"
```

Keep both `qwen_service_url` and `nuextract_service_url` configured. Changing the
provider and applying the Azure stack creates a new API revision; it does not
delete either model service. Existing jobs keep the model name recorded when
they started, so a retry does not silently change providers.
