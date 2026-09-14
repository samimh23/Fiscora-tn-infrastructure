# Fiscora on Azure

This directory defines a reproducible Azure staging platform for Fiscora. It
does not replace or delete the current AWS environment. The two platforms stay
independent until data migration, smoke tests and DNS cutover have passed.

## Target architecture

- Azure Static Web Apps (Free) hosts the React frontend.
- Azure Container Apps runs the NestJS API and can scale to zero in staging.
- Azure Database for PostgreSQL Flexible Server stores relational data on a
  private delegated subnet.
- Azure Blob Storage stores accounting documents with versioning and 30-day
  soft deletion. Public container access and storage account keys are disabled.
- A user-assigned managed identity grants the API access to Blob Storage and
  Key Vault without long-lived Azure credentials.
- Azure Key Vault stores the generated database password, JWT signing key and
  the manually supplied Brevo SMTP key.
- Azure Container Registry stores immutable backend images.
- Log Analytics is capped at 0.5 GB/day and a resource-group budget notifies at
  25%, 50%, 75% actual usage and 90% forecasted usage.
- GitHub Actions authenticates through workload identity federation rather
  than an Azure client secret.

The current Azure startup balance is USD 200 and expires on 2026-12-13. The
budget resource ends on the next valid month boundary, 2027-01-01. Budget
notifications are warnings, not a hard spending stop. Always review the Azure
cost estimate and Terraform plan before an apply.

## Deliberate two-stage deployment

The first staging apply uses `deploy_application = false`. It creates the
platform but not the API. This prevents a broken revision from starting before
the container image and Brevo key exist.

The generated PostgreSQL and JWT values are marked sensitive and stored in the
encrypted remote Terraform state as well as Key Vault. Never download, commit,
print or share the state file.

## Prerequisites

- Azure CLI authenticated with the personal Microsoft account that owns the
  startup subscription;
- Terraform 1.10 or newer;
- permission to create role assignments in the selected subscription;
- an available `Microsoft.App`, `Microsoft.DBforPostgreSQL`, `Microsoft.Storage`,
  `Microsoft.KeyVault`, `Microsoft.ContainerRegistry`, `Microsoft.Web`,
  `Microsoft.OperationalInsights` and `Microsoft.Insights` resource provider;
- a unique lowercase `deployment_suffix` in `terraform.tfvars`.

Select the subscription explicitly:

```powershell
az login
az account list --output table
az account set --subscription <subscription-id>
az account show --output table
```

## 1. Bootstrap remote state

Bootstrap is the only stack that initially uses local state:

```powershell
cd azure/bootstrap
Copy-Item terraform.tfvars.example terraform.tfvars
# Replace the subscription ID and the globally unique storage account name.
terraform init -backend=false
terraform plan -out bootstrap.tfplan
terraform apply bootstrap.tfplan
```

Copy `environments/staging/backend.hcl.example` to `backend.hcl`, replace the
storage account placeholder with the bootstrap output and wait a few minutes
for its RBAC assignment to propagate. Set `operator_object_id` in staging
`terraform.tfvars` to the stable object ID returned by
`az ad signed-in-user show --query id --output tsv`; do not derive this value
from whichever GitHub or local identity happens to run a plan.

The bootstrap also creates a read-only GitHub OIDC identity for Terraform
plans. Store its `github_terraform_plan_client_id` output as the repository
variable `AZURE_TERRAFORM_CLIENT_ID`; it cannot apply infrastructure changes.
Store the same stable human object ID as the repository variable
`AZURE_OPERATOR_OBJECT_ID` for drift-free pull-request plans.

## 2. Review the staging plan

```powershell
cd ../environments/staging
Copy-Item terraform.tfvars.example terraform.tfvars
# Replace subscription ID, deployment suffix and Brevo SMTP login.
terraform init -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
terraform plan -out staging.tfplan
terraform show staging.tfplan
```

`terraform plan` and `terraform show` do not create Azure resources. Do not run
`terraform apply` until the plan and Azure pricing calculator have been
reviewed.

## 3. First platform apply and secrets

With `deploy_application = false`, apply the reviewed plan. Then store the
Brevo SMTP key without placing it in PowerShell history:

```powershell
$smtpKey = Read-Host 'Brevo SMTP key' -AsSecureString
..\..\scripts\set-runtime-secrets.ps1 `
  -KeyVaultName (terraform output -raw key_vault_name) `
  -BrevoSmtpKey $smtpKey
```

Build and push the backend as `linux/amd64`, set `backend_image` to its immutable
digest, set `deploy_application = true`, create a new plan and review it before
the second apply.

The backend's manual `Deploy backend to Azure staging` workflow supports this
bootstrap: leave `update_container_app` false to push the first image, then copy
the digest shown in the workflow summary into `backend_image`. After Terraform
has created the Container App, later runs can set the input to true. Store the
staging output `github_deployment_client_id` as `AZURE_CLIENT_ID` in both the
backend and frontend repository variables; this is the CI identity, not the
runtime application's managed identity.

## 4. Frontend and DNS

Build the frontend with `VITE_API_URL` set to the Container App HTTPS endpoint.
Deploy the `dist` directory to the Static Web App. Test on the Azure-generated
hostnames before enabling custom domains.

Only after smoke tests pass:

1. set `enable_custom_domains = true` and apply;
2. add the returned `_dnsauth.app` TXT record in Namecheap;
3. replace the current `app` A record with the Static Web App CNAME;
4. create a separate API CNAME/custom-domain binding if the stable Azure API
   hostname will not be used directly.

Never leave both the old A record and a new CNAME at host `app`.

## 5. Migration and rollback

See [`migration/README.md`](migration/README.md). AWS remains the source of
truth until the PostgreSQL restore, document manifest verification and complete
application smoke test succeed. Keep AWS available for a 48-72 hour rollback
window after DNS cutover. Its destruction is a separate, explicitly approved
operation.

## Current staging limitations

- Malware scanning is disabled to preserve the small staging footprint. Do not
  accept real customer documents until an asynchronous scanning service and
  quarantine flow are deployed.
- The PostgreSQL administrator password exists in encrypted Terraform state.
  Production should move the application to Microsoft Entra database
  authentication and use a separate migration identity.
- This stack is single-region and does not claim production availability.
