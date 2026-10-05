# Fiscora infrastructure

Terraform and deployment tooling for the current Fiscora platform:

- **Azure** hosts the React frontend, NestJS API, PostgreSQL database, Blob
  Storage, Key Vault, container registry, monitoring and budget controls.
- **Google Cloud** hosts IAM-authenticated NuExtract3 financial-document
  extraction plus PaddleOCR on Cloud Run.
- **Brevo** provides outgoing SMTP delivery (invitations, password resets and document requests).
- **Namecheap** remains the registrar and DNS delegation point for the public
  application.

The web application and its primary data storage stay on Azure. Google Cloud receives
the document requests and assistant context needed for AI processing, authenticated through
Azure-to-Google Workload Identity Federation. No long-lived Google service
account key is used.

## Repository layout

```text
azure/bootstrap/                  Azure Terraform-state foundation
azure/environments/staging/       Azure resources grouped in readable topic files
azure/modules/application/        Tested NestJS/ClamAV runtime (only Azure module)
azure/scripts/                    Azure validation and secret configuration
gcp/bootstrap/                    Google Cloud Terraform-state foundation
gcp/environments/ai-staging/      NuExtract Cloud Run, IAM and budgets
gcp/services/nuextract/           Pinned NuExtract3 4B + vLLM container
gcp/services/paddleocr/           OCR and PDF rendering container
gcp/scripts/                      Build, pause, resume and smoke tests
scripts/                          Simple check, plan and AI-build entry points
.github/workflows/                Validation and Azure plan automation
```

Start with [three everyday commands](QUICKSTART.md), then the
[beginner-friendly Azure guide](azure/START-HERE.md). It explains
the topic files listed in staging/main.tf and the safe workflow for an existing deployment.
The Azure and GCP stacks remain separate.

The Azure layout now declares small components directly in staging instead of
ten single-purpose modules. Application Insights and all active services remain.
Compatibility mappings in `moved.tf` retain existing resources and secrets; see
[the refactor verification](azure/SIMPLIFICATION.md). A push never applies it.

For the exact first-deployment sequence and Terraform/GitHub responsibilities,
see [the deployment walkthrough](azure/DEPLOYMENT.md).
Incoming invoice email is retired. The configuration no longer includes its
obsolete DNS resources or API settings; pushing this repository never applies
infrastructure changes. The existing staging retirement was applied with
explicit approval; see [the verified cleanup record](azure/CLEANUP-STATUS.md)
for its status and remaining Namecheap housekeeping.

Detailed deployment instructions live in
[`azure/README.md`](azure/README.md) and [`gcp/README.md`](gcp/README.md).

## Local validation

```powershell
./scripts/check.ps1
```

Checks do not authenticate to the cloud. Plans read the selected deployment;
they never apply changes. Cloud Build and pause/resume helpers are explicit
cloud operations; they are not run by check or plan.

## Generated and sensitive files

Never commit:

- `.terraform/` provider caches;
- `*.tfplan` plan binaries;
- `terraform.tfstate` or state backups;
- `terraform.tfvars`;
- `backend.hcl`;
- cloud credentials, API keys or application secrets.

The repository contains examples for local configuration. Active values remain
untracked and secrets belong in Azure Key Vault or the relevant cloud secret
store.

## Change safety

1. Run `./scripts/check.ps1`.
2. Create and review a Terraform plan for the affected environment.
3. Apply only the reviewed plan from an authenticated operator session.
4. Run application and extraction smoke tests after deployment.

Never use an old saved plan after changing configuration. Create a fresh plan
for every deployment.
