# Fiscora infrastructure

Terraform and deployment tooling for the current Fiscora platform:

- **Azure** hosts the React frontend, NestJS API, PostgreSQL database, Blob
  Storage, Key Vault, container registry, monitoring and budget controls.
- **Google Cloud** hosts the private Qwen3.5 financial-document extraction
  service on GPU-enabled Cloud Run.
- **Brevo** provides SMTP delivery and inbound email parsing.
- **Namecheap** remains the registrar and DNS delegation point for the public
  application and inbound-email subdomain.

The web application and its data stay on Azure. Google Cloud receives only the
document request needed for private AI inference and is authenticated through
Azure-to-Google Workload Identity Federation. No long-lived Google service
account key is used.

## Repository layout

```text
azure/bootstrap/                  Azure Terraform-state foundation
azure/environments/staging/       Deployed Azure staging composition
azure/modules/                    Reusable Azure infrastructure modules
azure/scripts/                    Azure validation and secret configuration
gcp/bootstrap/                    Google Cloud Terraform-state foundation
gcp/environments/ai-staging/      Qwen Cloud Run, IAM and budget resources
gcp/services/qwen/                Pinned Qwen3.5 + vLLM container
gcp/scripts/                      Build, pause, resume and smoke tests
.github/workflows/                Validation and Azure plan automation
```

Detailed deployment instructions live in
[`azure/README.md`](azure/README.md) and [`gcp/README.md`](gcp/README.md).

## Local validation

```powershell
.\azure\scripts\validate.ps1
.\gcp\scripts\validate.ps1
```

Validation and planning do not change cloud resources. Only `terraform apply`
changes infrastructure.

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

1. Run the Azure and GCP validation scripts.
2. Create and review a Terraform plan for the affected environment.
3. Apply only the reviewed plan from an authenticated operator session.
4. Run application and extraction smoke tests after deployment.

Never use an old saved plan after changing configuration. Create a fresh plan
for every deployment.
