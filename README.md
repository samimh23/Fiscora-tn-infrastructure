# Fiscora infrastructure

Terraform configuration for Fiscora's AWS environments.

## Current scope

The first environment is a low-cost staging platform in `eu-north-1`:

- one VPC and public application subnet;
- one Amazon Linux EC2 Docker host with no SSH port;
- AWS Systems Manager access for administration;
- one ECR repository for immutable backend images;
- one private, encrypted S3 bucket for accounting documents;
- one private S3 bucket and CloudFront distribution for the React application.

PostgreSQL will initially run in Docker on the staging host. This topology is
for development, demonstrations and pilot testing only. Production will use a
managed PostgreSQL database, private subnets and a separate availability plan
before real customer accounting data is accepted.

## Repository layout

```text
bootstrap/                 Terraform state bucket
environments/staging/      Staging composition and values
modules/network/           VPC, subnet and routing
modules/registry/          Backend ECR repository
modules/storage/           Document and web buckets, CloudFront
modules/compute/           EC2, SSM, IAM and security group
scripts/validate.ps1       Local format and validation checks
```

## Safety

Running `terraform init`, `fmt`, `validate` or `plan` does not create the
declared application resources. Only `terraform apply` changes AWS.

Do not commit `backend.hcl`, `terraform.tfvars`, Terraform state, plans or
credentials. Human access uses the `fiscora-admin` AWS SSO profile.

## Validate locally

```powershell
aws sso login --profile fiscora-admin
.\scripts\validate.ps1
```

## Bootstrap remote state

This is a one-time operation and creates only the protected Terraform state
bucket:

```powershell
cd bootstrap
terraform init
terraform plan -var="aws_profile=fiscora-admin"
terraform apply -var="aws_profile=fiscora-admin"
terraform output -raw state_bucket_name
```

Copy `environments/staging/backend.hcl.example` to
`environments/staging/backend.hcl`, replace the bucket placeholder with the
output above, and keep `backend.hcl` uncommitted.

## Review staging without deploying

```powershell
cd environments/staging
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform plan -out=staging.tfplan
```

Review the complete plan and its estimated AWS costs before running any apply.
GitHub OIDC, deployment workflows, application secrets, DNS and HTTPS for the
backend will be added before staging is deployed.

