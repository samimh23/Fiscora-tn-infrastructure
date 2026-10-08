# Retired Azure hosting cleanup — 8 October 2026

Status: complete. The approved apply destroyed exactly eight retired resources,
with zero additions and zero changes. Final live checks and a refreshed plan passed.
The user confirmed that the app works after the App Service cutover and invoice
posting fix. This is user acceptance, not a claim of exhaustive automated testing.

## Reviewed scope

The refreshed saved plan contains **0 additions, 0 updates and 8 deletions**:

| Retired resource | Azure name |
| --- | --- |
| Container App | `ca-fiscora-staging-api` |
| Container Apps environment | `cae-fiscora-staging` |
| Virtual network | `vnet-fiscora-staging` |
| Container Apps subnet | `snet-container-apps` |
| Old PostgreSQL subnet | `snet-postgresql` |
| Private DNS zone | `privatelink.postgres.database.azure.com` |
| Private DNS VNet link | `fiscora-staging-postgres-dns` |
| Obsolete backend deployment role | `Container Apps Contributor` on staging RG |

Approval was requested after inspecting the plan and received explicitly.
A machine-readable allowlist also checks that the saved plan contains only
these eight delete actions before apply. The old API had no active revisions;
the environment contained no other applications. The preserved database was
Ready with no delegated subnet or private DNS attachment. The only remaining
network association belonged to the old Container Apps environment.

## Preserved services

- App Service `app-fiscora-staging-sami090` and B3 plan `asp-fiscora-staging`.
- PostgreSQL `psql-fiscora-staging-sami090`, database `accounting_nest`, existing
  password, seven-day backups and all 25 exact App Service IP firewall rules.
- React Static Web App and its custom domain.
- Blob documents, private container, versioning and deletion lock.
- Key Vault, existing secrets and application managed identity.
- Container Registry, image release ownership and current GitHub OIDC identities.
- Application Insights, Log Analytics, budget and Google AI federation.

No active application setting, API image, password, business record or current
deployment permission is part of this cleanup. The approved plan is ignored
locally and must never be committed; it may contain sensitive values.

## Code changes

The obsolete `.tf` definitions, role, outputs and compatibility moves are removed
so future plans cannot recreate retired hosting or networking. The PostgreSQL
resource keeps its existing address and explicit null private-network fields.
Existing migration inputs remain required for the deployed stack; retain ignored
`cutover.auto.tfvars` with the existing private settings on every plan/apply.

`app-service.tf` is now the only active NestJS/ClamAV hosting definition.
The deployment-settings helper prints only App Service values. The old runtime
snapshot is retained as `scripts/fixtures/application-retired.tf.txt` solely for
offline equivalence checks; Terraform does not load that file.

Existing human edits to bootstrap/main.tf, staging/backend.tf and staging/main.tf
are preserved and excluded from this cleanup commit. Only the separate file-map
comment hunk in staging/main.tf is updated and selectively staged for this cleanup.

## Recovery after retirement

The old hosting and private network are no longer an immediately available
fallback after this apply. PostgreSQL backups and the existing data are retained.
If recovery is ever needed, use a reviewed PostgreSQL point-in-time restore and
validate its data before switching the application. Recreating the old private
topology requires an explicit new plan; do not reuse an old cutover plan or assume
the database network migration can be reversed in place.

## Verification

- Before apply: live API healthy on release `d1f4ee240bb65976b4f77556b1ea33552c988a26`.
- Source guards: 31 passed; mocked Terraform tests: 12 passed.
- Apply result: **0 added, 0 changed, 8 destroyed**.
- Azure inventory: old Container App, environment, VNet and private DNS zone are
  absent; their two subnets and DNS link were deleted successfully by Terraform.
- The obsolete Container Apps role is absent. Current Website Contributor,
  registry, document-storage, Key Vault and frontend deployment roles remain.
- PostgreSQL is Ready at the same resource ID, with seven-day backups and the
  same 25 single-IP firewall rules. App Service, Blob Storage, Key Vault, ACR,
  Static Web Apps, Application Insights and Log Analytics remain present.
- After apply: live API healthy on the same release
  `d1f4ee240bb65976b4f77556b1ea33552c988a26`.
- Final refreshed plan: **No changes. Your infrastructure matches the configuration.**
