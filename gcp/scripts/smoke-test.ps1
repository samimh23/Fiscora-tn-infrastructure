param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,

    [string]$Region = 'europe-west1',
    [string]$Service = 'fiscora-nuextract'
)

$ErrorActionPreference = 'Stop'

$uri = gcloud run services describe $Service `
    --project $ProjectId `
    --region $Region `
    --format 'value(status.url)'

if (-not $uri) {
    throw 'Cloud Run service URI was not found.'
}

$token = gcloud auth print-identity-token
if (-not $token) {
    throw 'Could not create a Google identity token.'
}

Write-Host 'Calling the private health endpoint. A scale-from-zero start may take several minutes.'
$headers = @{ Authorization = "Bearer $token" }
$health = Invoke-WebRequest -UseBasicParsing -Uri "$uri/health" -Headers $headers -TimeoutSec 900
$models = Invoke-RestMethod -Uri "$uri/v1/models" -Headers $headers -TimeoutSec 120

[pscustomobject]@{
    HealthStatus = $health.StatusCode
    ServiceUri   = $uri
    Model         = $models.data[0].id
}
