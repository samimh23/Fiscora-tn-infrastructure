# Preview one existing deployment. Never copies example settings or applies.
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Azure', 'AzureBootstrap', 'Google')]
    [string]$Cloud,

    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9._-]*\.tfplan$')]
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$directory = switch ($Cloud) {
    'Azure' { 'azure/environments/staging' }
    'AzureBootstrap' { 'azure/bootstrap' }
    'Google' { 'gcp/environments/ai-staging' }
}
$deployment = Join-Path $root $directory

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    throw 'Terraform >= 1.10 is required.'
}
$requiredFiles = if ($Cloud -eq 'AzureBootstrap') { @('terraform.tfvars') } else { @('backend.hcl', 'terraform.tfvars') }
foreach ($file in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $deployment $file) -PathType Leaf)) {
        throw "Missing $directory/$file. Follow the first-installation guide; existing settings are never replaced by examples."
    }
}
if ($OutFile -and (Test-Path -LiteralPath (Join-Path $deployment $OutFile))) {
    throw 'The requested plan file already exists. Choose a new filename; old plans are never overwritten.'
}

Push-Location $deployment
try {
    if ($Cloud -eq 'AzureBootstrap') {
        terraform init -backend=false -input=false
    }
    else {
        terraform init '-backend-config=backend.hcl' -input=false
    }
    if ($LASTEXITCODE -ne 0) { throw 'Terraform backend initialization failed.' }
    terraform validate
    if ($LASTEXITCODE -ne 0) { throw 'Terraform validation failed.' }

    $planArgs = @('plan', '-input=false', '-lock-timeout=60s', '-detailed-exitcode')
    if ($OutFile) { $planArgs += "-out=$OutFile" }
    terraform @planArgs
    $result = $LASTEXITCODE
    if ($result -notin @(0, 2)) { throw "Terraform plan failed (exit $result)." }
    if ($result -eq 0) { Write-Output 'No infrastructure changes proposed.' }
    else { Write-Output 'Changes proposed. Review every action; nothing has been applied.' }
    if ($OutFile) {
        Write-Output "Saved in $directory/$OutFile. Treat it as sensitive; apply it manually only after review."
    }
}
finally { Pop-Location }
