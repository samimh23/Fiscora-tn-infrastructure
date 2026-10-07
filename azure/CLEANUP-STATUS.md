# Incoming-email retirement — staging status

Verified on 2026-10-05 (Africa/Lagos). This is an operation record, not a
guarantee of future cloud state.

Historical record: on 2026-10-07 the separate GitHub Terraform-plan workflow
was retired in code. Its identity retirement is a separate bootstrap change,
not part of the applied incoming-email cleanup recorded below. See
[SIMPLIFICATION.md](SIMPLIFICATION.md) for the current local-only planning flow.

## Completed with explicit approval

- Removed the Brevo incoming-email webhook for `inbox.fiscora.me`; a follow-up
  lookup returned HTTP 404 / `document_not_found`. Outgoing SMTP was unchanged.
- Applied the reviewed staging plan: six obsolete incoming-email DNS resources
  deleted and one in-place API configuration update. No resources were added.
- Removed `EMAIL_INGESTION_DOMAIN`, `EMAIL_INGESTION_MAX_ATTACHMENT_BYTES`,
  `BREVO_API_KEY` and `INBOUND_EMAIL_WEBHOOK_SECRET` from the API, along with
  the two corresponding Key Vault references. The SMTP reference remains.
- Applied the separate bootstrap plan: removed only the obsolete pull-request
  OIDC credential. State storage and manual-main access remain.
- Configured the infrastructure repository's five Azure ID/state variables and
  encrypted `AZURE_TERRAFORM_TFVARS` secret. No passwords/API keys were uploaded.
- The [manual GitHub plan](https://github.com/samimh23/Fiscora-tn-infrastructure/actions/runs/37244065428)
  succeeded with no changes. The local refreshed staging plan also exited 0.
- Revision `ca-fiscora-staging-api--0000071` is healthy, provisioned and serving
  100% traffic. The API health endpoint returned HTTP 200. The API image digest
  was preserved; PostgreSQL, document storage, runtime identity and SMTP were
  not changed.

## Remaining external DNS housekeeping

Namecheap was not accessible from the available browser session. In its
Advanced DNS page for `fiscora.me`, remove only the four **NS** records with
Host **inbox** pointing to:

- `ns1-07.azure-dns.com`
- `ns2-07.azure-dns.net`
- `ns3-07.azure-dns.org`
- `ns4-07.azure-dns.info`

Keep the root domain, `app`, `www`, GitHub Pages records, outgoing-email DKIM
records, and root email-forwarding settings. Gmail forwarding to the retired
receiving domain was never enabled, according to the user.

Old Key Vault secret objects were deliberately retained; only the API's
references were removed. Their separate deletion is not needed for the app to
work and was not part of this applied plan.
