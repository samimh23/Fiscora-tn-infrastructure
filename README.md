# Fiscora infrastructure

Terraform configuration for Fiscora's AWS environment and the reviewed Azure
migration target.

The existing AWS stack remains under `bootstrap/`, `modules/` and
`environments/`. The Azure stack is isolated under [`azure/`](azure/README.md)
and cannot change or destroy AWS resources.

## Current scope

The first environment is a low-cost staging platform in `eu-north-1`:

- one VPC and public application subnet;
- one ARM Amazon Linux EC2 Docker host with a stable Elastic IP and no SSH port;
- AWS Systems Manager access for administration;
- one ECR repository for immutable backend images;
- one private, encrypted S3 bucket for accounting documents;
- one private S3 bucket and CloudFront distribution for build artifacts;
- Caddy on the Docker host for the public React application, API routing and
  automatic HTTPS at `app.fiscora.me`.

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
.github/workflows/         Validation and authenticated plan automation
```

## Safety

Running `terraform init`, `fmt`, `validate` or `plan` does not create the
declared application resources. Only `terraform apply` changes AWS.

Do not commit `backend.hcl`, `terraform.tfvars`, Terraform state, plans or
credentials. Human access uses the `fiscora-admin` AWS SSO profile.

The staging S3 buckets and ECR repository intentionally allow forced deletion.
Running `terraform destroy` for staging permanently removes its database,
documents, web artifacts and container images. Production storage must use a
separate retention and recovery policy.

## Validate locally

```powershell
aws sso login --profile fiscora-admin
.\scripts\validate.ps1
```

## Bootstrap remote state

This is a one-time operation and creates only the protected Terraform state
bucket. The first initialization deliberately disables the remote backend
because the bucket does not exist yet:

```powershell
cd bootstrap
terraform init -backend=false
terraform plan -var="aws_profile=fiscora-admin"
terraform apply -var="aws_profile=fiscora-admin"
terraform output -raw state_bucket_name
```

Copy `bootstrap/backend.hcl.example` to `bootstrap/backend.hcl`, replace the
bucket placeholder with the output above, and migrate the bootstrap state into
the protected bucket:

```powershell
terraform init -migrate-state -backend-config=backend.hcl
```

Then copy `environments/staging/backend.hcl.example` to
`environments/staging/backend.hcl`, use the same bucket name, and keep both
`backend.hcl` files uncommitted.

## Review staging without deploying

```powershell
cd environments/staging
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform plan -out=staging.tfplan
```

Review the complete plan and its estimated AWS costs before running any apply.
The deployed staging defaults target the $20 monthly budget; see
[`COSTS.md`](COSTS.md) for the dated estimate and its limitations.

## Deployed staging

The current staging environment uses `t4g.small`, 20 GB gp3 and Elastic IP
`51.21.164.16`. Runtime definitions are stored in `deploy/`. Application
secrets are generated on the host in `/opt/fiscora/.env`; they are not stored
in Git or Terraform state.

After building the backend as a Linux ARM64 image and uploading the frontend
bundle to the private web bucket, deploy through AWS Systems Manager. The host
pulls the artifacts and runs PostgreSQL, MinIO, NestJS and Caddy with Docker
Compose. Port 22 remains closed.

Namecheap must contain this record before Caddy can issue the TLS certificate:

```text
Type: A Record
Host: app
Value: 51.21.164.16
```

Do not use this staging topology for real customer data. Malware scanning is
disabled on the 2 GB host. Transactional email can use Brevo SMTP while Amazon
SES production access is still unavailable; keep SMTP credentials in the host
environment or a secret manager, never in Git.

## GitHub Actions authentication

The bootstrap also creates a GitHub OIDC provider and the
`fiscora-github-terraform-plan` role. Its trust policy accepts only the
immutable GitHub owner/repository IDs for this repository and only the `main`
branch. GitHub receives temporary AWS credentials; no AWS access key is stored
in repository secrets.

The `Terraform staging plan` workflow is read-only. It runs after relevant
changes reach `main` and can also be started manually from the repository
Actions page. It may read the staging state and create/delete only the native
S3 lock file. It cannot apply a plan or change application resources.

Application deployment automation can be tightened further with dedicated
GitHub OIDC roles for the backend and frontend repositories. No long-lived AWS
access key is required.
