param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,

    [string]$Region = 'europe-west1',
    [string]$ModelRevision = 'c99dc8f5641b866aa0192b6ea78f84bf9f3535f1',
    [string]$Tag = 'vllm-0.22.1'
)

$ErrorActionPreference = 'Stop'
$serviceRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'services/nuextract'
$image = "${Region}-docker.pkg.dev/$ProjectId/fiscora-ai/nuextract3:$Tag"

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

Write-Host 'Immutable NuExtract image:'
Write-Host "${Region}-docker.pkg.dev/$ProjectId/fiscora-ai/nuextract3@$digest"
