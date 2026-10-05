param(
    [string]$ProjectId = 'fiscora-ai',
    [string]$Region = 'europe-west1',
    [string]$Service = 'fiscora-nuextract-v3'
)

$ErrorActionPreference = 'Stop'
gcloud run services update $Service `
    --project $ProjectId `
    --region $Region `
    --min 0 `
    --max 1

if ($LASTEXITCODE -ne 0) { throw 'Cloud Run resume failed.' }
Write-Host 'NuExtract extraction is available and remains configured to scale from zero to one L4.'
