# Architecture simplification — review before implementation

Status: proposed, not deployed. Inspected on 8 October 2026.

This is a change to the actual hosting/network architecture, not another file
layout refactor. No application, database, firewall or network change has been
applied as part of this review.

## Proposed target

- Keep React on the existing Azure Static Web App.
- Run NestJS and its ClamAV sidecar on one Linux App Service.
- Keep the PostgreSQL server `psql-fiscora-staging-sami090` and database
  `accounting_nest`, including existing accounts and business data.
- Change PostgreSQL from VNet-integrated networking to a public-capable network
  configuration, then allow only the App Service outbound IP addresses. Keep TLS
  and password authentication; do not add an all-IP or all-Azure firewall rule.
- Keep Container Registry, Blob documents, Key Vault, managed identity, Google
  AI federation, outgoing SMTP and Application Insights.
- Retire the old Container App, its environment, VNet, two subnets and private
  database DNS only after the new path is verified and an exact deletion plan
  has been approved. Keep state storage and its protection unchanged.

Keeping the database private would require App Service VNet integration and a
dedicated subnet. It would therefore not achieve the requested removal of
networking complexity. Merely swapping hosting services is not enough.

## What was verified

- Azure reports PostgreSQL 16, state `Ready`, public network access `Disabled`,
  and the existing delegated PostgreSQL subnet/private DNS zone.
- Backup retention is seven days. Azure reports an earliest restore time of
  2 October 2026. This is metadata evidence, not a successful restore test or a
  newly created independent backup.
- NestJS already uses `ManagedIdentityCredential`; the Azure identity client ID
  can remain the same on App Service. WIF, Blob and Key Vault access still need
  end-to-end tests on the new hosting.
- The backend has scheduled document-extraction and embedding workers. The new
  App Service must use a paid, always-on configuration; do not use a free/sleeping
  plan or assume a successful HTTP health check proves workers work.
- ClamAV currently runs beside NestJS. Preserve malware scanning with a supported
  App Service sidecar configuration; do not silently disable it to simplify.

## Decision required before changing configuration

Removing the VNet changes the database's security boundary: its endpoint becomes
publicly routable, while firewall rules restrict who can connect. This is not
equivalent to the existing private-only network.

Microsoft documents an in-place VNet-to-private-endpoint-capable migration,
currently **Preview**. Its documentation estimates about 20 minutes overall and
about 10 minutes without database connectivity. Existing connections are
terminated. Connectivity must then be explicitly restored using firewall rules
or a private endpoint. The latter would retain network complexity.

The Azure CLI installed here exposes `az postgres flexible-server migrate-network`.
This command was **not run**. Command availability does not prove this server is
eligible or guarantee migration success. Do not assume there is an in-place
reverse operation; the documented recovery path and a restore test must be
established before proceeding.

Approve the public-with-IP-firewall target and a maintenance window before the
migration is executed. Review the App Service SKU and monthly estimate before
creating paid resources. If Preview is unacceptable, evaluate a restored/copied
server in parallel instead, with separate approval for its cost and cutover.

## Execution gates

1. Review the networking decision, downtime window, budget and recovery plan.
2. Verify fresh backups and test restore to an isolated server; validate schema,
   accounts, document metadata and pgvector data. Do not expose backup contents
   in logs, commit them, or reuse a restore for live writes during validation.
3. Prepare additive App Service Terraform and deployment changes, preserving the
   existing serving app. Scope deployment access to the new app, preserve API
   image ownership by GitHub, and use managed identity for ACR/secrets/storage.
   Size the plan for NestJS plus ClamAV and review fixed-cost implications.
4. Review an additive Terraform plan before creating the new hosting. Do not
   remove the old hosting or database resources in this phase.
5. Quiesce all live writes and background workers during the approved maintenance
   window. Perform the separately approved PostgreSQL networking migration, then
   configure only the reviewed App Service IP firewall rules. Enforce TLS.
6. Refresh Terraform after the server-side migration and reconcile its networking
   fields. Do not try to force this migration by removing the subnet fields and
   applying a replacement plan. Stop if the plan proposes PostgreSQL replacement,
   password rotation, data-resource deletion or an unreviewed change.
7. Test the new API: login/MFA, permissions, database reads/writes, document upload
   and malware scan, Blob access, SMTP, NuExtract/OCR, assistant/embeddings,
   scheduled workers and Application Insights. Avoid concurrent workers or
   migrations from both hosts during the cutover.
8. Update frontend API configuration and backend deployment workflow only when
   the new app is verified. Check CORS, authentication cookies/tokens, HTTPS and
   WebSocket behavior. Monitor the agreed observation period.
9. Review a separate exact cleanup plan for old hosting/network resources. Only
   then delete those resources. Never destroy the database, Key Vault, documents,
   state storage or Application Insights as a shortcut.

## Configuration locations to change after approval

- Infrastructure: `azure/environments/staging/application.tf`, `network.tf`,
  `database.tf`, `deployment-access.tf`, `outputs.tf`, migration mappings and tests.
- Backend repository: `.github/workflows/deploy-azure-staging.yml` currently
  deploys and verifies Container Apps revisions; it must target App Service.
- Frontend deployment settings: the API URL must target the verified new host.
- Existing private `terraform.tfvars`, backend configuration and state are kept.

## Official references

- [PostgreSQL network migration (Preview)](https://learn.microsoft.com/en-us/azure/postgresql/network/how-to-migrate-vnet-private-endpoint-capable-server)
- [App Service VNet integration and dedicated subnet requirements](https://learn.microsoft.com/en-us/azure/app-service/overview-vnet-integration)
- [App Service sidecar configuration](https://learn.microsoft.com/en-us/azure/app-service/configure-sidecar)

These sources were checked on 8 October 2026. Recheck eligibility, pricing and
platform behavior before executing the migration.
