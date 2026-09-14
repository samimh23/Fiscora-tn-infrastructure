# AWS-to-Azure data migration

These scripts prepare and verify a controlled migration. They are dry-run by
default and never delete source data.

## Safety boundary

- Do not run a database restore against a non-empty destination.
- Do not change Namecheap DNS before application smoke tests pass.
- Do not destroy AWS until database counts, document hashes and user workflows
  have been verified and the rollback window has elapsed.
- Migration bundles contain confidential accounting data. Keep them out of Git,
  delete local copies after verification and retain only encrypted backups.

## Workflow

1. Start the AWS staging EC2 instance for the export window.
2. Run `export-aws-staging.ps1` without `-Execute` and review its target.
3. Run it again with `-Execute`. It creates a PostgreSQL custom-format dump,
   exports plain objects from MinIO and writes SHA-256 checksums.
4. Upload the bundle with `upload-bundle-to-azure.ps1`, first as a dry run and
   then with `-Execute`.
5. Restore from a temporary migration runner attached to the Azure Container
   Apps virtual network. The runner is deliberately not enabled in the base
   stack; it should exist only for the migration window.
6. Compare exported and imported object manifests with
   `verify-migration.ps1`, then run application-level smoke tests.

The private PostgreSQL server cannot be restored directly from an arbitrary
laptop. The migration runner and its one-time job definition will be added only
after the base Azure plan succeeds, because it needs the final registry,
network and storage identifiers.
