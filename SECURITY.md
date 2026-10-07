# Security policy

## Secrets

Never commit:

- Terraform state or plan files;
- `backend.hcl`;
- application passwords, JWT secrets or database credentials;
- production `.tfvars` files;
- Azure access tokens, service-principal secrets or managed-identity tokens;
- Google Application Default Credentials, service-account keys or identity tokens;

Application GitHub Actions must authenticate to Azure through OIDC; Google
access uses Workload Identity Federation. Infrastructure CI is offline and
requires no cloud credentials or state access. Do not create permanent cloud
access keys for CI.

The Google Cloud NuExtract document-extraction endpoint must remain authenticated. Azure-to-Google
access will use Workload Identity Federation; do not create or download a
long-lived Google service-account JSON key.

If a credential is committed, revoke or rotate it immediately before removing
it from Git history.

## Infrastructure changes

Infrastructure changes must be reviewed through a pull request. `terraform
plan` must be reviewed before any `terraform apply`. This repository deploys
staging only; plans and applies run locally under the authorized operator.
Production deployment is outside this project's current workflow and requires
a separately reviewed access/approval process.
