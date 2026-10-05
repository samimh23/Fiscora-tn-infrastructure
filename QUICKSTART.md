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

These are normal refreshed plans, unlike the limited GitHub state-only plan.
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

## Earlier grouping refactor (before Qwen retirement)

The Azure application module now receives four grouped objects: `database`,
`storage`, `smtp`, and `ai`. Secret references remain separate sensitive inputs.
Root input names and defaults are unchanged, so local configuration and GitHub's
`AZURE_TERRAFORM_TFVARS` remain compatible. Resource/module addresses, cloud
names, IAM roles, state backends, deletion protections and runtime environment
values have not been intentionally changed.

For a **new** installation, follow [the full deployment guide](azure/DEPLOYMENT.md).
Do not use everyday commands to restart bootstrap on an existing deployment.

## Verification of the earlier grouping refactor — 5 October 2026

All four deployment configurations and the application module validated; ten
command/workflow tests and three mocked Terraform tests passed. A refreshed
Azure plan proposed no changes. A refreshed Google plan proposed only existing
PaddleOCR `client`/`client_version` metadata cleanup (zero creates/deletes); its
resource configuration in this refactor differs only in comments. No apply or
AI build was run. Existing local inputs, identities and deployment names remain
unchanged.
