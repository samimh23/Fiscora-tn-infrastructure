# Fiscora NuExtract on Google Cloud

This stack hosts `numind/NuExtract3` on one NVIDIA L4 using Cloud Run. It is
separate from the Azure application stack: the Fiscora web application and API
remain on Azure, while Google Cloud provides only private document inference.

The service is intentionally disabled by default. Creating the Artifact
Registry repository, service account and budget does not start a GPU. A GPU is
created only after an immutable NuExtract image has been built and
`enable_nuextract_service` is explicitly set to `true`.

## Safety defaults

- Cloud Run minimum instances: `0` (scale to zero).
- Cloud Run maximum instances: `1` (at most one L4).
- GPU zonal redundancy: disabled.
- Public/unauthenticated access: disabled.
- Default request concurrency: `32`, matching the interactive benchmark mode.
- Monthly budget alerts: 50%, 80%, 100%, and 100% forecast.
- Deletion protection: enabled for the inference service.

Budgets are alerts, not hard spending caps. `max_instance_count = 1` is the
enforced compute-cost guard. A running instance is billed while it starts,
loads the model, and serves requests; scale-to-zero avoids GPU compute charges
when no instance is running.

## Explicit overnight pause

Automatic scaling already returns the service to zero instances after traffic
stops. To reject every new request while you are away, run:

```powershell
.\gcp\scripts\pause-nuextract.ps1
```

Resume it before processing documents:

```powershell
.\gcp\scripts\resume-nuextract.ps1
```

Closing Codex, the browser, or the local PC does not control Cloud Run. These
scripts do. Pausing affects inference compute; stored images and state may still
incur negligible storage charges.

## Layout

```text
gcp/bootstrap/                     Protected GCS Terraform-state bucket
gcp/environments/ai-staging/       Artifact Registry, IAM, budget and Cloud Run
gcp/services/nuextract/            Reproducible vLLM 0.22.1 image
gcp/scripts/                       Validation, build, deploy and smoke-test tools
```

## 1. Bootstrap remote state

Application Default Credentials must already be configured:

```powershell
gcloud auth application-default login
gcloud config set project fiscora-ai
```

Then create the state bucket:

```powershell
cd gcp/bootstrap
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init -backend=false
terraform plan
terraform apply
terraform output -raw state_bucket_name
```

On the very first bootstrap, the GCS backend block must be temporarily removed
because the destination bucket does not exist yet. After the first apply,
restore `backend.tf`, copy `backend.hcl.example` to `backend.hcl`, insert the
output bucket name, and migrate the local state. Do not delete the local state
until migration has succeeded:

```powershell
terraform init -migrate-state -backend-config=backend.hcl
```

Copy the same bucket name into
`environments/ai-staging/backend.hcl`. Both local files are ignored by Git.

## 2. Prepare the non-GPU resources

```powershell
cd ..\environments\ai-staging
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform plan
```

Review the plan before applying it. Keep
`enable_nuextract_service = false` during this step.

## 3. Build the NuExtract image

The image pins the exact vLLM version used in the L4 benchmark and an immutable
NuExtract3 model revision (`c99dc8f5641b866aa0192b6ea78f84bf9f3535f1`). It
embeds the public Apache-2.0 model so cold starts do not download about 9 GB
from Hugging Face. Building and storing the image consumes some Google Cloud
credit, but no GPU is started.

```powershell
.\gcp\scripts\build-nuextract.ps1 -ProjectId fiscora-ai
```

The script prints the immutable image digest. Put that full digest in the local
`terraform.tfvars` as `nuextract_image`, then set
`enable_nuextract_service = true`.

## 4. Deploy and test deliberately

```powershell
cd gcp\environments\ai-staging
terraform plan -out=nuextract.tfplan
terraform apply nuextract.tfplan
cd ..\..\..
.\gcp\scripts\smoke-test.ps1 -ProjectId fiscora-ai
```

The first request can take several minutes because Cloud Run must start an L4
instance and vLLM must load the model. The endpoint requires a Google identity
token. Do not make it public to avoid abuse and surprise GPU usage.

After the health check, exercise the real multimodal extraction path with a
non-sensitive test invoice:

```powershell
.\gcp\scripts\smoke-extraction.ps1 `
  -ProjectId fiscora-ai `
  -ImagePath C:\path\to\test-invoice.png
```

The extraction smoke test proves transport, authentication, image handling and
JSON generation. It does not certify that the returned accounting values are
correct; production requests must still pass deterministic validation and the
human-review policy.

## Production integration

The Azure NestJS API uses its user-assigned managed identity to obtain a
Microsoft Entra token. Google Workload Identity Federation exchanges it for
short-lived Google credentials and an identity token for this private endpoint.
No Google service-account key is stored in Azure.

Extraction requests are persisted in PostgreSQL, leased with `SKIP LOCKED`,
retried with bounded exponential backoff, validated with deterministic financial
rules and always sent to human review. Valid JSON is not proof that invoice
values are correct.
