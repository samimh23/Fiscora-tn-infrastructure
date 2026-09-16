param(
    [string]$ProjectId = 'fiscora-ai',
    [string]$Region = 'europe-west1',
    [string]$Service = 'fiscora-nuextract'
)

$ErrorActionPreference = 'Stop'

gcloud run services update $Service `
    --project $ProjectId `
    --region $Region `
    --scaling auto `
    --min 0 `
    --max 1 `
    --quiet

if ($LASTEXITCODE -ne 0) { throw 'Cloud Run resume failed.' }
Write-Host 'NuExtract is available and remains configured to scale from zero to one L4.'
