param(
    [string]$ProjectId = 'fiscora-ai',
    [string]$Region = 'europe-west1',
    [string]$Service = 'fiscora-nuextract'
)

$ErrorActionPreference = 'Stop'
gcloud run services update $Service `
    --project $ProjectId `
    --region $Region `
    --max 0

if ($LASTEXITCODE -ne 0) { throw 'Cloud Run pause failed.' }
Write-Host 'Document extraction is disabled. New requests fail until resume-extraction.ps1 is run.'
