# Read only the named deployment outputs. Never dump the whole state or secrets.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$deployment = Join-Path $root 'azure/environments/staging'
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    throw 'Terraform is required.'
}

function Read-DeploymentOutput([string]$Name, [switch]$Optional) {
    $lines = @(terraform output -json $Name 2>$null)
    if ($LASTEXITCODE -ne 0) {
        if ($Optional) { return '' }
        throw "Cannot read output $Name. Initialize the staging backend and apply its foundation first."
    }
    $value = ($lines -join "`n") | ConvertFrom-Json
    if (-not $Optional -and [string]::IsNullOrWhiteSpace([string]$value)) {
        throw "Output $Name is missing. Apply the staging foundation first."
    }
    return [string]$value
}

Push-Location $deployment
try {
    # All outputs below are names, URLs or identity IDs, not credentials.
    $tenant = Read-DeploymentOutput 'azure_tenant_id'
    $subscription = Read-DeploymentOutput 'azure_subscription_id'
    $group = Read-DeploymentOutput 'resource_group_name'
    $backendClient = Read-DeploymentOutput 'github_backend_client_id'
    $frontendClient = Read-DeploymentOutput 'github_frontend_client_id'
    $registry = Read-DeploymentOutput 'container_registry_name'
    $registryServer = Read-DeploymentOutput 'container_registry_login_server'
    $app = Read-DeploymentOutput 'container_app_name' -Optional
    if (-not $app) { $app = Read-DeploymentOutput 'container_app_deployment_name' }
    $frontend = Read-DeploymentOutput 'static_web_app_name'
    $hostname = Read-DeploymentOutput 'container_app_fqdn' -Optional

    Write-Output 'GitHub Actions variables — backend repository:'
    Write-Output "AZURE_CLIENT_ID=$backendClient"
    Write-Output "AZURE_TENANT_ID=$tenant"
    Write-Output "AZURE_SUBSCRIPTION_ID=$subscription"
    Write-Output "AZURE_RESOURCE_GROUP=$group"
    Write-Output "AZURE_CONTAINER_REGISTRY_NAME=$registry"
    Write-Output "AZURE_CONTAINER_REGISTRY_LOGIN_SERVER=$registryServer"
    Write-Output "AZURE_CONTAINER_APP_NAME=$app"
    Write-Output ''
    Write-Output 'GitHub Actions variables — frontend repository:'
    Write-Output "AZURE_CLIENT_ID=$frontendClient"
    Write-Output "AZURE_TENANT_ID=$tenant"
    Write-Output "AZURE_SUBSCRIPTION_ID=$subscription"
    Write-Output "AZURE_RESOURCE_GROUP=$group"
    Write-Output "AZURE_STATIC_WEB_APP_NAME=$frontend"
    if ($hostname) { Write-Output "AZURE_API_URL=https://$hostname" }
    else { Write-Output 'AZURE_API_URL: run this helper again after creating the API; do not deploy the frontend yet.' }
    Write-Output ''
    Write-Output 'Configuration only. No GitHub settings or cloud resources were changed.'
}
finally { Pop-Location }
