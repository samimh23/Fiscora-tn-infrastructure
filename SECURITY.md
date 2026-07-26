# Security policy

## Secrets

Never commit:

- AWS access keys or session tokens;
- Terraform state or plan files;
- `backend.hcl`;
- application passwords, JWT secrets or database credentials;
- production `.tfvars` files.

Human AWS access uses IAM Identity Center and temporary SSO sessions. GitHub
Actions will use an AWS OIDC role in a later change; it must not use permanent
AWS access keys.

If a credential is committed, revoke or rotate it immediately before removing
it from Git history.

## Infrastructure changes

Infrastructure changes must be reviewed through a pull request. `terraform
plan` must be reviewed before any `terraform apply`. Production applies require
an explicitly protected GitHub environment.

