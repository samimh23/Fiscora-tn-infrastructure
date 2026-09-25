param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,

    [string]$Region = 'europe-west1',
    [string]$ModelRevision = 'a470f0b5dd0b42fa7182cdbe7c6113a232f671e4',
    [string]$Tag = 'nuextract-2-0-8b-vllm-nightly'
)

$ErrorActionPreference = 'Stop'
$serviceRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'services/nuextract'
$image = "${Region}-docker.pkg.dev/$ProjectId/fiscora-ai/nuextract-2-8b:$Tag"

gcloud builds submit $serviceRoot `
    --project $ProjectId `
    --region $Region `
    --config (Join-Path $serviceRoot 'cloudbuild.yaml') `
    --substitutions "_IMAGE=$image,_MODEL_REVISION=$ModelRevision"

if ($LASTEXITCODE -ne 0) {
    throw 'Cloud Build failed.'
}

$digest = gcloud artifacts docker images describe $image `
    --project $ProjectId `
    --format 'value(image_summary.digest)'

if (-not $digest) {
    throw 'The image was built, but its digest could not be resolved.'
}

Write-Host 'Immutable NuExtract extraction image:'
Write-Host "${Region}-docker.pkg.dev/$ProjectId/fiscora-ai/nuextract-2-8b@$digest"

