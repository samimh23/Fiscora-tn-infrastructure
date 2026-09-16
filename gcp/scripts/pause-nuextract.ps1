param(
    [string]$ProjectId = 'fiscora-ai',
    [string]$Region = 'europe-west1',
    [string]$Service = 'fiscora-nuextract'
)

$ErrorActionPreference = 'Stop'

gcloud run services update $Service `
    --project $ProjectId `
    --region $Region `
    --scaling 0 `
    --quiet

if ($LASTEXITCODE -ne 0) { throw 'Cloud Run pause failed.' }
Write-Host 'NuExtract is disabled. New requests fail until resume-nuextract.ps1 is run.'
