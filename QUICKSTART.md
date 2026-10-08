# Everyday Terraform commands

Terraform configures infrastructure. GitHub deploys application code. These
commands do not apply infrastructure changes automatically.

## 1. Check the code

From the repository root, with Terraform >= 1.10 and Node installed:

```powershell
./scripts/check.ps1
```

Checks formatting, both cloud configurations, command guards and mocked API
ownership tests. It needs provider downloads, but no cloud credentials.

## 2. Preview a change

Keep one `terraform.tfvars` and `backend.hcl` in each deployed environment:

- Azure: `azure/environments/staging/`
- Google: `gcp/environments/ai-staging/`

Keep your existing files. Never replace them with examples. Authenticate using
the operator account (`az login` for Azure; Google Application Default
Credentials for Google). Then:

```powershell
./scripts/plan.ps1 -Cloud Azure
./scripts/plan.ps1 -Cloud Google
```

These are normal refreshed plans. GitHub now checks code only; it does not
authenticate to the cloud or run plans/applies.
To save a plan for a reviewed manual apply, use a new filename:

```powershell
./scripts/plan.ps1 -Cloud Azure -OutFile reviewed-azure.tfplan
```

The saved plan is inside the selected environment. Existing plan files are not
overwritten. Treat plans as sensitive. Read all actions, especially destruction
or replacement. Only after approval, from that environment, run
`terraform apply reviewed-azure.tfplan` yourself. No wrapper runs apply.

## 3. Prepare an AI release

Authenticate to Google Cloud, then choose one service:

```powershell
./scripts/deploy-ai.ps1 -Service nuextract -ProjectId YOUR-GCP-PROJECT
```

This builds/publishes an image with Cloud Build and can incur charges. It prints
an immutable digest. It does not update Cloud Run, change enable flags, edit
tfvars, or apply Terraform. Copy the digest to the corresponding setting in
Google's existing tfvars (`nuextract_image` or `ocr_image`), then preview with `plan.ps1 -Cloud Google` and review before apply.

NuExtract is now the only extraction model. Qwen and its build tooling are
retired. Generic categories are upload-only until categorized as an invoice or
bank statement. Completed extraction history stays unchanged.

## GitHub deployment settings (read-only)

After staging has been initialized and its foundation applied:

```powershell
./scripts/show-deployment-settings.ps1
```

Prints the frontend/backend Actions variables from selected Terraform outputs.
It changes neither GitHub nor Azure, and does not print passwords or keys.
Before the first API exists, it prints the planned API name and tells you to
wait before setting its URL/deploying the frontend. Run it again after API creation.

## First installation or bootstrap maintenance

For a **new** installation, follow [the one deployment guide](azure/DEPLOYMENT.md).
Do not replace existing inputs or restart bootstrap just to update the app.
Bootstrap has its own local state; retain it and its backups.
To preview a deliberate bootstrap change with existing local settings/state:

```powershell
./scripts/plan.ps1 -Cloud AzureBootstrap -OutFile reviewed-bootstrap.tfplan
```

Review before manually applying from `azure/bootstrap`. The retired GitHub plan
identity is removed from the configuration, but its cloud deletion requires a
separate reviewed bootstrap apply. See [the simplification record](azure/SIMPLIFICATION.md).

Azure resources are in staging topic files with no child modules. Start with
`application.tf` for the backend and `database.tf` for PostgreSQL and its network.
Keep all 43 mappings in `moved.tf`; they protect older state snapshots.
