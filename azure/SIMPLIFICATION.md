# Azure simplification history

## Direct runtime configuration — 8 October 2026

Azure staging now has no child modules. `application.tf` directly declares the
Container Apps Environment and NestJS/ClamAV Container App, with direct references
to PostgreSQL, Key Vault, document storage and Application Insights. The obsolete
`azure/modules/application` source and duplicate input declarations are removed.
Its ownership tests now run in staging beside the layout test.

`database.tf` groups PostgreSQL's subnet, private DNS, server, database and
extensions. Moving these existing root declarations between files does not
change their Terraform addresses. The private network is retained because the
existing PostgreSQL server uses it; this is not a public-database migration.

Two additional `moved` blocks migrate the runtime's module addresses to direct
staging addresses; all 41 earlier mappings remain, for 43 total. Database names,
addresses, generated passwords, state backend, secrets, hosting configuration,
Application Insights and GitHub's API-image ownership are preserved. Existing
private `terraform.tfvars` and `backend.hcl` files remain compatible.

A source-equivalence test compares every runtime configuration token against
the previous module after input substitution. Verification on 8 October passed:
recursive formatting, all 26 Node guards, validation of all four Azure/GCP roots,
and all four mocked Terraform ownership/layout tests. A refreshed, read-only
Azure staging plan showed only the two runtime address moves and **0 to add,
0 to change, 0 to destroy**. PostgreSQL and its generated password were unchanged.
No Terraform apply was run. Review a fresh plan before a later apply; the saved
review plan is local, ignored by Git and may become stale.

The sections below are dated historical records, not the current file layout.

## Workflow simplification — 7 October 2026

GitHub infrastructure CI now performs offline checks only. The separate
`terraform-azure-plan.yml` workflow and duplicated staging configuration are
no longer needed. Refreshed plans and reviewed applies run locally with one
private `terraform.tfvars` and `backend.hcl` per deployment.

Bootstrap now contains only the state resource group, protected storage,
private container, operator role and deletion lock. Four retired resources
have been removed from its configuration: `azurerm_user_assigned_identity.terraform_plan`,
`azurerm_federated_identity_credential.terraform_main`,
`azurerm_role_assignment.terraform_plan_subscription_reader` and
`azurerm_role_assignment.terraform_plan_state`. Their Azure deletion was applied
on 7 October after separate user approval of the exact plan. A push still never
applies changes. Preserve the bootstrap's existing local state.

Application hosting, database, documents, runtime secrets, Application Insights,
frontend/backend OIDC deployment identities and Google federation are unchanged.
Existing staging input values and all 41 state migrations remain intact.
Only an unused compatibility input was retired and one non-secret planned API
name output was added for first-installation guidance.

Use `./scripts/show-deployment-settings.ps1` after initialization/foundation
creation to print only the named GitHub application deployment variables.
It does not dump state, display passwords/keys, or change cloud/GitHub settings.
The single installation guide is [DEPLOYMENT.md](DEPLOYMENT.md).

Verification on 7 October: all 21 Node guards and four mocked Terraform tests
passed; every Azure/GCP configuration validated. The read-only settings helper
successfully read the existing staging state. A refreshed bootstrap plan verified
exactly the four identity/access deletions above, with no changes to the remaining
five state-foundation resources. The initial apply removed the trust and Reader
role but the storage lock blocked the state-access role deletion. After separate
approval, only that lock was temporarily removed; a fresh plan deleted the two
remaining retired resources. A `finally` safeguard restored the original lock,
and its ID, CanNotDelete level and notes were verified unchanged. No storage,
state contents, operator role or application infrastructure was removed.
The final refreshed bootstrap plan exited 0: all five foundation resources were
unchanged, no retired identity resources remained, and the deletion lock was
CanNotDelete. Application resources were not applied or redeployed by this cleanup.

The verification below is the historical 5 October layout refactor, not an
assertion that this later identity retirement has been applied.

## Scope

This is a Terraform code-layout refactor, not a cloud migration or a service
removal. Application Insights is explicitly retained with the same connection,
sampling, Log Analytics retention and daily quota. No Terraform apply was run.

Ten small modules are now direct resource declarations in staging topic files.
The larger `application` module stays because it has independent ownership tests
for the NestJS image deployed by GitHub, runtime configuration and ClamAV.
`main.tf` is the entry point and file map; [START-HERE.md](START-HERE.md) explains
the files in plain language for a project presentation.

## Hosting declaration cleanup — 7 October 2026

`hosting.tf` now omits repeated provider defaults for registry public networking
and zone redundancy, and for Static Web App SKU size and configuration-file
changes. These defaults were verified against AzureRM 4.81.0; the mocked provider
does not execute the real provider's defaulting logic. The mocked foundation plan
checks the retained explicit authentication, Free-tier and preview settings.

The application module no longer explicitly waits for the database and three
generated secrets already referenced in its inputs, nor for the GitHub image-push
role or the operator's document-access role. Those roles/resources are retained;
only unnecessary startup ordering was removed. Hidden runtime prerequisites
remain: PostgreSQL extensions, image-pull access, document access, and now the
API's Key Vault read permission. The intentional document-protection lock is
still established before the application starts. A Node guard checks this list.

Static Web App lifecycle exclusions, CORS deduplication, SMTP configuration,
Application Insights, resource names, images and secrets are unchanged. This
cleanup is code-only: no Terraform apply or application deployment is performed.
IAM dependency ordering does not guarantee instantaneous role propagation in
Azure, so first-deployment health checks remain necessary.

## Compatibility

- `moved.tf` contains 41 explicit old-to-new resource address mappings.
- Cloud resource names/IDs, generated passwords/keys, data protections, inputs,
  defaults, outputs, state storage and provider versions are preserved.
- PostgreSQL remains private with seven-day backups and pgvector.
- Documents remain private with versioning, soft deletion and deletion guards.
- The API identity, separate GitHub OIDC identities and Azure→Google federation
  remain. NuExtract, PaddleOCR and Gemini still require that Google connection.
- Initial deployment flags remain: the foundation must be creatable before the
  first API image or custom-domain DNS exists. Existing installations must keep
  `deploy_application=true`. These are useful prerequisites, not unused switches.
- Module-wide deployment prerequisites were translated into explicit resource
  dependencies for database DNS, IAM grants and generated runtime secrets.

## Verified before/after plans

Using the existing local inputs and the same remote Azure state, fresh refreshed
plans were generated before and after the refactor. Local comparison checked all
44 planned resource entries and every existing output. After mapping the moved
addresses, resource values, actions, unknown/sensitive metadata and outputs were
identical. There are **no new resource creates, deletes or replacements** caused
by this refactor. All 41 moves were recognized in the plan.

The baseline already proposed one in-place API settings update from the earlier
Qwen retirement. The refactored plan proposed exactly that same update, not an
additional change. The API image was preserved. Neither plan was applied.

Offline checks include a mocked staging-foundation plan, the existing three
mocked application ownership tests, Node layout/migration guards and validation
of all four Azure/GCP roots plus the application module. CI runs the same guards.
Run `./scripts/check.ps1` before changing these files.

## Next approved apply

Create a fresh local refreshed plan first; never reuse pre-refactor saved plans.
Review the already-pending API settings update as well as the address moves.
An approved apply will record the new addresses in Terraform state without
recreating the moved cloud resources. Keep `moved.tf` for older state snapshots.
Do not run `state rm`, re-import resources or rename Azure resources for this
refactor. No cloud cleanup, Qwen service deletion or background-worker redesign
is included in this code-layout change.
