param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F-]{36}$')]
    [string]$SubscriptionId
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI is required.'
}

az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) { throw 'Unable to select the Azure subscription.' }

$providers = @(
    'Microsoft.App',
    'Microsoft.Authorization',
    'Microsoft.Consumption',
    'Microsoft.ContainerRegistry',
    'Microsoft.DBforPostgreSQL',
    'Microsoft.Insights',
    'Microsoft.KeyVault',
    'Microsoft.ManagedIdentity',
    'Microsoft.Network',
    'Microsoft.OperationalInsights',
    'Microsoft.Storage',
    'Microsoft.Web'
)

foreach ($provider in $providers) {
    $state = az provider show `
        --namespace $provider `
        --query registrationState `
        --output tsv

    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read registration state for $provider."
    }

    if ($state -ne 'Registered') {
        Write-Output "Registering $provider..."
        az provider register --namespace $provider --wait --output none
        if ($LASTEXITCODE -ne 0) { throw "Registration failed for $provider." }
    }
    else {
        Write-Output "$provider is already registered."
    }
}

Write-Output 'All Fiscora Azure resource providers are registered.'
