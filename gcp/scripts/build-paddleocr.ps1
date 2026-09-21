param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,

    [string]$Region = 'europe-west1',
    [string]$Tag = 'pp-ocrv6-medium'
)

$ErrorActionPreference = 'Stop'
$serviceRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'services/paddleocr'
$image = "${Region}-docker.pkg.dev/$ProjectId/fiscora-ai/paddleocr:$Tag"

gcloud builds submit $serviceRoot `
    --project $ProjectId `
    --region $Region `
    --config (Join-Path $serviceRoot 'cloudbuild.yaml') `
    --substitutions "_IMAGE=$image"

if ($LASTEXITCODE -ne 0) {
    throw 'Cloud Build failed.'
}

$digest = gcloud artifacts docker images describe $image `
    --project $ProjectId `
    --format 'value(image_summary.digest)'

if (-not $digest) {
    throw 'The image was built, but its digest could not be resolved.'
}

Write-Host 'Immutable PaddleOCR image:'
Write-Host "${Region}-docker.pkg.dev/$ProjectId/fiscora-ai/paddleocr@$digest"
