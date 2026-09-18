param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,

    [string]$Region = 'europe-west1',
    [string]$ModelRevision = '851bf6e',
    [string]$Tag = 'qwen3-5-4b-vllm-nightly'
)

$ErrorActionPreference = 'Stop'
$serviceRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'services/qwen'
$image = "${Region}-docker.pkg.dev/$ProjectId/fiscora-ai/qwen3-5-4b:$Tag"

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

Write-Host 'Immutable Qwen extraction image:'
Write-Host "${Region}-docker.pkg.dev/$ProjectId/fiscora-ai/qwen3-5-4b@$digest"
