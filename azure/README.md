# Fiscora on Azure

Start with [START-HERE.md](START-HERE.md) for the file map and mentor walkthrough,
then [DEPLOYMENT.md](DEPLOYMENT.md) for the first deployment and routine updates.
For an existing installation, preserve `terraform.tfvars`, `backend.hcl`, state,
resource names and identity IDs. Examples are for new installations only.

The small Azure components are declared directly in staging topic files; only
the tested Container Apps module remains. Start with `staging/main.tf`, then
`hosting.tf`, `database.tf`, `storage.tf`, `security.tf` and `monitoring.tf`.
Network, GitHub deployment access and Google federation each have a dedicated
file. Application Insights is retained. Keep `moved.tf`: its 41 address mappings
preserve existing cloud resources and generated secrets. See
[SIMPLIFICATION.md](SIMPLIFICATION.md) for the before/after plan verification.

## Architecture kept deliberately small

- Static Web Apps hosts the React frontend.
- Container Apps hosts the NestJS API and its ClamAV sidecar.
- PostgreSQL Flexible Server stores relational data on a private subnet.
- Blob Storage stores documents with versioning and 30-day soft deletion;
  public containers and storage account keys are disabled.
- A user-assigned managed identity gives the API access to Blob Storage and
  Key Vault. Key Vault holds generated database/JWT/MFA secrets and the
  separately supplied outgoing SMTP key.
- Container Registry stores immutable backend images.
- Namecheap handles application DNS. Brevo is used for outgoing emails only.
- Log Analytics/Application Insights provide monitoring. The resource-group
  budget sends notifications; it is not a hard spending limit.
- GitHub application deployments authenticate through OIDC with separate
  frontend/backend identities. Infrastructure checks need no cloud identity.

Google Cloud AI is a separate stack under `gcp/`; this cleanup does not migrate
or remove NuExtract, PaddleOCR, Vertex AI or their identity federation.

## Deployment ownership

Terraform owns resource creation, network, identities, secrets references,
API settings and the ClamAV image. GitHub builds, publishes and releases the
**API image**. Terraform uses `backend_image` on first creation, then ignores
only `template[0].container[0].image` so an infrastructure update cannot revert
a GitHub release. A postcondition checks that this container is still `api`.

For a new installation, deploy the foundation with `deploy_application=false`,
run **Backend CI** manually with **bootstrap_image_only** checked, then create
the API using the resulting digest and `deploy_application=true`. Keep it true
afterwards. The API has a `prevent_destroy` guard against accidental removal
while its resource configuration remains present.

Pull requests and relevant pushes run offline formatting/validation and mocked
ownership tests. The separate GitHub cloud-plan workflow has been retired.
Plan locally with `./scripts/plan.ps1 -Cloud Azure`, review the refreshed plan,
then apply the saved plan manually. Keep only the local `terraform.tfvars` and
`backend.hcl`; no duplicated staging settings or Terraform cloud credentials
are required in the infrastructure repository's Actions settings.
Application pushes still release the backend/frontend through their own repositories.
`./scripts/show-deployment-settings.ps1` prints their required Actions variables.
The bootstrap now manages protected state storage and operator access only.
Existing installations must review its separate identity-retirement plan before
applying; this code change does not delete anything in Azure automatically.

## Retired incoming-email feature

The existing staging cleanup was applied and verified on 2026-10-05; see
[CLEANUP-STATUS.md](CLEANUP-STATUS.md) for results and the remaining Namecheap
housekeeping. The procedure below also covers other existing installations.

The next reviewed staging plan removes the obsolete incoming-email DNS zone
and its five records, and removes four environment variables/two secret
references from the API. **A push does not apply this cleanup.** Existing
documents and database history remain untouched.

Disable Gmail forwarding and the Brevo incoming webhook separately before
applying this retirement. Remove only the `inbox` delegation in Namecheap;
keep outgoing SMTP/DKIM and the website/app DNS. Old Key Vault secrets are not
deleted by this change. The bootstrap plan separately retires the unused
pull-request OIDC credential. The later workflow simplification now also prepares
retirement of the unused manual-plan identity; see [SIMPLIFICATION.md](SIMPLIFICATION.md).

## Security and staging limits

- Generated secrets exist in remote Terraform state as well as Key Vault.
  Never commit, print or share state or saved plans; restrict access to them.
- Uploads fail closed when malware scanning is unavailable. Verify scanner
  health and EICAR rejection with synthetic files before using real documents.
  Pin the ClamAV image by digest before production.
- PostgreSQL uses an administrator password in this staging setup. Production
  should use Entra database authentication and a separate migration identity.
- This is a single-region staging setup, not a production availability claim.
- The configured budget ends at the month boundary `2027-01-01`; review dates,
  actual costs and Azure credits before deploying another installation.
- Check database compatibility before rolling back an API release. Roll back
  application images with the release/revision workflow, not by changing the
  now-ignored Terraform API image field.
