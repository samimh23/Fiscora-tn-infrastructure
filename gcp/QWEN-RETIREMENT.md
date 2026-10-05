# Qwen retirement — 5 October 2026

The backend and frontend now use NuExtract only for purchases, sales and bank
statements. Other categories remain upload-only. Completed review history is
preserved. The former Qwen build tooling and Terraform service declaration have
been removed. No cloud deletion has been applied during this change.

## Verified locally

- 98 extraction tests passed; backend build and lint passed.
- Frontend eligibility tests, build and lint passed (existing lint warnings).
- Four Terraform roots and the application module validate.
- 11 command/workflow tests and three mocked Terraform tests passed.
- A refreshed plan identifies only the former Qwen service and its two
  invocation IAM grants for deletion. The active NuExtract service is unchanged.
- PaddleOCR CLI attribution metadata is now ignored; its runtime configuration
  remains managed normally.

## Deployment gate

Backend commit: 44986a8. Frontend commit: 112967a.
GitHub backend validation succeeded, but application deployment jobs were still
queued at the last check. Verify deployment completion and the exact running
backend image before retiring the old service or removing its Azure settings.

## Protected service cleanup

The old service is named fiscora-nuextract, but its container runs Qwen.
The active NuExtract3 service is fiscora-nuextract-v3: do not delete it.

The retired service currently has Terraform deletion protection enabled.
An operator must perform a reviewed two-stage cleanup:

1. Temporarily retain ONLY its previous resource and invocation grants, with
   their existing image/configuration, and set deletion_protection=false for
   that resource only. Apply a fresh plan that changes this protection flag.
   The shared runtime identity may be relabelled NuExtract3 without replacing it.
2. Remove that temporary declaration, generate another fresh plan, and verify
   exactly three deletions: Qwen Cloud Run and its two invocation IAM grants.
   Apply only after the NuExtract-only backend is live.
3. Plan Azure separately to remove obsolete Qwen environment variables.
   Preserve the currently deployed API image; do not apply an older saved plan
   while GitHub is deploying a newer image.
4. Verify invoice and bank extraction, generic category rejection, human review
   and an empty final Terraform plan.

Active NuExtract/PaddleOCR protection, shared service accounts, WIF, Vertex AI,
document storage, the database and application accounts must remain unchanged.
Old Qwen image artifacts may be retained for rollback; deleting an image is a
separate operation and is not needed to stop the running service.
