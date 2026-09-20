# Security policy

## Secrets

Never commit:

- Terraform state or plan files;
- `backend.hcl`;
- application passwords, JWT secrets or database credentials;
- production `.tfvars` files;
- Azure access tokens, service-principal secrets or managed-identity tokens;
- Google Application Default Credentials, service-account keys or identity tokens;

GitHub Actions must authenticate to Azure and Google Cloud through OIDC or
Workload Identity Federation. Do not create permanent cloud access keys for CI.

The Google Cloud Qwen document-extraction endpoint must remain authenticated. Azure-to-Google
access will use Workload Identity Federation; do not create or download a
long-lived Google service-account JSON key.

If a credential is committed, revoke or rotate it immediately before removing
it from Git history.

## Infrastructure changes

Infrastructure changes must be reviewed through a pull request. `terraform
plan` must be reviewed before any `terraform apply`. Production applies require
an explicitly protected GitHub environment.
