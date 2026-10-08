# App Service cutover — actual architecture change

Status: live traffic cutover completed on 8 October 2026. PostgreSQL completed its
in-place network migration; NestJS/ClamAV run on App Service behind an exact-IP
database firewall, and the real frontend serves the new API URL. The old API
revisions are stopped. Legacy resource deletion remains separately reviewed.
See [the execution record](CUTOVER-2026-10-08.md). Keep the ignored local cutover
inputs for every plan/apply now that candidate resources exist. Do not interpret
a successful mock test as a completed cloud migration.

## Target and cost

React stays on Static Web Apps. NestJS and ClamAV move to a Linux App Service.
The same PostgreSQL server/database, Key Vault, Blob documents, managed identity,
Google AI federation and Application Insights remain. PostgreSQL switches to
public-capable networking with an exact IP firewall; old private networking and
Container Apps are removed only after successful cutover and separate review.

The proposed B3 Linux plan has 7 GB RAM for the existing combined 4 GB API/ClamAV
allocation and runs always-on for background workers. Microsoft's public retail
API returned USD 0.07/hour in `francecentral` on 8 October 2026: approximately
USD 51.10 for 730 hours. This is backend compute only, before tax/discounts;
database, registry, storage, monitoring and Google services are extra. Temporary
overlap with the old hosting and a restore-test server adds cost. A budget alert
is not a spending cap. Approve the cost before creating resources.

Sources: [Linux plan pricing](https://azure.microsoft.com/en-us/pricing/details/app-service/linux/)
and [Microsoft Retail Prices API](https://prices.azure.com/api/retail/prices).

## Read the implementation

- `environments/staging/app-service.tf`: service plan, disabled candidate site,
  API/ClamAV sidecars, Key Vault references, identity and deployment role.
- `environments/staging/migration-settings.tf`: temporary migration controls.
- `environments/staging/database.tf`: conditional networking reconciliation,
  retaining the existing server's name, password, backup policy and destroy guard.
- `environments/staging/database-firewall.tf`: one exact rule per reviewed IP,
  checked against the candidate's possible outbound IP list.
- `environments/staging/tests/migration.tftest.hcl`: mocked preparation,
  activation, ownership and negative firewall tests.

AzAPI is used for the site's `sitecontainers` configuration because the pinned
AzureRM provider does not expose that configuration. One provider owns the site;
there is no AzureRM/AzAPI competition for its configuration.

## Phase 1 — additive, quarantined hosting

After budget approval, keep the existing private `terraform.tfvars` unchanged and
put the following temporary controls in ignored `cutover.auto.tfvars` beside it:

```hcl
app_service_stage         = "prepare"
app_service_sku           = "B3"
postgres_network_migrated = false
legacy_backend_stopped   = false
```

During this cutover, update that same `cutover.auto.tfvars` for later phases;
automatic variable files override `terraform.tfvars`. Never maintain conflicting
copies of the migration controls. Do not replace the private file with an example.
Do not change `deploy_application`
or the existing image to tear down the current backend. Persist these settings;
using a one-off CLI flag and then omitting it on later plans would propose removal
of the candidate (blocked by destroy guards).

From the repository root:

```powershell
./scripts/plan.ps1 -Cloud Azure -OutFile app-service-prepare.tfplan
```

Review the actual plan: seven additions (plan, site, two containers, two basic-auth
policies, deployment role), no database/network changes, no deletion. Older state
may also show the two already-reviewed runtime address moves. Stop on unexpected
updates/replacements. Only after explicit approval, manually apply that saved plan
from `azure/environments/staging`. This guide does not automatically run apply.

The site is disabled. Its main container runs an idle command rather than NestJS,
and migrations/extraction/indexing settings are disabled as defense in depth.
GitHub refuses to activate it or overwrite its startup command. Preparing the
candidate does **not** prove database connectivity or full app functionality.

Read only the named, non-secret outputs:

```powershell
terraform -chdir=azure/environments/staging output -raw app_service_name
terraform -chdir=azure/environments/staging output -raw app_service_url
terraform -chdir=azure/environments/staging output -json app_service_database_ips
```

## Phase 2 — database networking, separately approved maintenance

1. Verify fresh backups and a successful isolated restore/data-integrity test.
   Verify accounts, schema, document metadata and pgvector data. Record the
   recovery procedure; do not assume the Preview network operation is reversible.
2. Schedule a maintenance window for the **whole cutover**, not just the database
   command. Stop incoming writes and confirm all old API revisions/workers are
   stopped. Do not merely set minimum replicas to zero: requests can wake the API.
   Freeze automatic releases during this window so GitHub cannot restart old work.
3. Recheck eligibility and Microsoft's
   [Preview migration documentation](https://learn.microsoft.com/en-us/azure/postgresql/network/how-to-migrate-vnet-private-endpoint-capable-server).
   The documented operation is `az postgres flexible-server migrate-network` for
   `rg-fiscora-staging` / `psql-fiscora-staging-sami090`. See the dated execution
   record for what was actually run; this procedure is not current status.
   Microsoft estimates about 20 minutes overall and about 10 minutes of database
   unavailability. Backups remain available; reconnecting still requires setup.
4. Only after explicit approval, execute the external Azure migration and wait
   for `Ready`. Never try to perform it by applying a Terraform replacement plan.
5. Copy the exact candidate IP output into `app_service_database_ips` in
   `cutover.auto.tfvars` and set `postgres_network_migrated = true`. Keep stage `prepare`.
   A normal refreshed Terraform plan must show the same database and password,
   no replacement, and only the reviewed public-access/firewall reconciliation.
   Stop on replacement. Do not bypass `prevent_destroy` or edit state to hide it.
6. After plan review, apply that reconciliation promptly to restore permitted
   connectivity. Never add `0.0.0.0`, all-Azure, all-internet or operator-IP rules.
   TLS and database authentication remain mandatory. Restricting shared App Service
   outbound IPs is not equivalent to a private-only database.

For an approved single-window cutover, phases 2 and 3 may share one refreshed plan
after the external migration returns Ready and candidate preflight/legacy-stop
checks pass. The API container explicitly depends on all firewall rules, so the
real startup command cannot be activated before they complete. Expect AzureRM to
serialize the rules; allow substantial extra maintenance time beyond the network
migration itself. The 8 October execution uses this reviewed combined plan.

If the Preview operation fails, stop and use the reviewed recovery procedure.
Do not delete the old database or create an empty replacement as a shortcut.

## Phase 3 — activate, test and redirect

With old API/workers confirmed stopped and firewall rules verified, update
`cutover.auto.tfvars`:

```hcl
app_service_stage       = "active"
legacy_backend_stopped = true
```

Review a fresh plan before applying. It enables the site, removes the idle command
and restores the original migration/worker feature settings. Verify login/MFA,
database reads/writes, permissions, document uploads/scans, Blob, SMTP, NuExtract,
OCR, Gemini/embeddings, background jobs and Application Insights. A `/health`
response alone does not prove any of those integrations.

Only after that verification, configure backend Actions variables:

```text
AZURE_BACKEND_HOSTING=app-service
AZURE_WEB_APP_NAME=<app_service_name output>
```

Keep existing OIDC and registry variables. The backend CI then calls
`deploy-azure-app-service.yml` instead of the Container Apps deployment. API images
remain digest-pinned; Terraform ignores only the API image, not its startup command
or the ClamAV image. The workflow verifies the actually served Git commit SHA.
Preparing code alone changes no GitHub variables. Actual cutover configuration
changes are recorded in the execution record.

Update the frontend repository's `AZURE_API_URL` to the verified App Service URL,
then deploy and verify HTTPS, CORS, authentication and WebSockets. Avoid running
both old and new workers simultaneously. Thaw normal releases only once routing
and workflow selection are consistent.

## Phase 4 — final simplification

After the observation/recovery window, review a separate cleanup change deleting
old Container Apps resources, the obsolete deployment role, VNet, both subnets,
private DNS zone/link and old references. Remove temporary migration controls and
update diagrams/mentor guide to describe the **then-live** architecture.

Until that review, legacy declarations remain deliberately present. Code prepared
for migration is not a claim that the deployed architecture is already simpler.
Never remove database/password/storage/state protections to make a plan succeed.

## Verification record

Verified before hosting creation on 8 October 2026:

- Terraform formatting and validation passed for all four roots.
- 30 infrastructure guards and 12 mocked Terraform tests passed.
- Four backend deployment guards, two health-controller tests, the backend build,
  targeted lint and parsing of all three deployment/CI YAML files passed.
- Refreshed default plan: **0 add, 0 change, 0 destroy**.
- Refreshed preparation plan: **7 add, 0 change, 0 destroy**. The existing
  PostgreSQL server/database/password, private networking and Container Apps are
  all no-op. Two previously reviewed runtime address moves remain pending.

The mock target networking run uses isolated fake state; it does not test the
external Azure migration or prove the existing server will migrate successfully.
Restore verification and the production network migration have since passed.
Hosting activation, traffic verification and cleanup status belong to the dated
execution record, not the historical mock/preparation results above.
