# Prepare an AI release: build/publish the selected image, never apply Terraform.
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('nuextract', 'paddleocr')]
    [string]$Service,

    [Parameter(Mandatory)]
    [string]$ProjectId,

    [string]$Region = 'europe-west1'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    throw 'Google Cloud CLI is required. Authenticate before building.'
}

Write-Output "Preparing ${Service}: Cloud Build publishes an image and can incur charges."
& (Join-Path $root "gcp/scripts/build-$Service.ps1") -ProjectId $ProjectId -Region $Region

$setting = switch ($Service) {
    'nuextract' { 'nuextract_image' }
    'paddleocr' { 'ocr_image' }
}
Write-Output "Next: copy the printed digest into $setting in gcp/environments/ai-staging/terraform.tfvars."
Write-Output 'Then run ./scripts/plan.ps1 -Cloud Google -OutFile ai-release.tfplan and review the plan.'
Write-Output 'No Cloud Run service settings or enable flags were changed. Apply remains manual.'
