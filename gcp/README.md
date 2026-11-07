# Fiscora extraction on Google Cloud

NuExtract3 is the only extraction model for purchase invoices, sales invoices
and bank statements. Other categories remain upload-only until manually classified.
The former Qwen service and its build tooling are retired.

## Services

- fiscora-nuextract-v3: NuExtract3 + vLLM, minimum zero instances, maximum one
  L4 GPU instance, request concurrency eight and vLLM scheduler ceiling eight.
  Azure extraction workers and NuExtract request slots are also set to eight.
  The 7 November 2026 isolated benchmark processed 32 fictional documents at
  14.83 valid documents/minute versus 6.39 at concurrency two, with a higher
  p95 request latency (62.6s versus 47.1s). This is a throughput setting, not
  a guarantee of lower per-request latency or performance on every document.
- fiscora-paddleocr: CPU OCR supplies trusted highlight coordinates. Its PDFium
  POST /render endpoint supplies original PDF page images without OCR.
- Vertex AI provides the separate assistant and embeddings.

Cloud Run ingress is public HTTPS with IAM-authenticated invocation. The Azure
API uses Workload Identity Federation, not a Google service-account JSON key.
Existing NuExtract runtime identity and Terraform addresses are retained.

## Operations

Authenticate with Google CLI and Application Default Credentials first.
Use scripts/check.ps1, scripts/deploy-ai.ps1 -Service nuextract (or paddleocr),
and scripts/plan.ps1 -Cloud Google. See ../QUICKSTART.md for exact commands.
Build commands publish images only and can incur charges. Copy the immutable
digest into nuextract_image or ocr_image in existing private tfvars.
Model revisions are pinned, but the current vLLM nightly base does not guarantee
reproducible future builds. Review every plan before applying.
Deletion protection remains enabled for active services. Budgets are alerts,
not hard spending caps. Never reuse a saved plan after changing configuration.

## Smoke tests and cost controls

Use gcp/scripts/smoke-test.ps1, smoke-nuextract.ps1 (ImagePath), and
smoke-paddleocr.ps1 (DocumentPath), with -ProjectId fiscora-ai.
Tests can wake a GPU instance and incur charges. They do not certify accounting
correctness: deterministic controls and human review remain mandatory.
pause-extraction.ps1 and resume-extraction.ps1 now target NuExtract only.
They do not stop PaddleOCR or the assistant.

## Backend integration

Keep nuextract_service_url and paddle_ocr_service_url in Azure staging.
No provider switch or Qwen URL is needed. Images go directly to NuExtract.
PDFs are rendered and sent in bounded image batches. OCR text never replaces
extracted values. Image extraction can work without OCR mapping; PDF extraction
requires the rendering endpoint.

Completed extraction results remain unchanged. Pending legacy Qwen jobs for
supported categories use NuExtract. Unsupported jobs fail once with a category
message, without a model call. Reclassify and request extraction if needed.
