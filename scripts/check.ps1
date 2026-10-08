# Validate code only. No cloud authentication or infrastructure deployment.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

foreach ($tool in @('terraform', 'node')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool is required."
    }
}

Push-Location $root
try {
    terraform fmt -check -recursive
    if ($LASTEXITCODE -ne 0) { throw 'Terraform formatting check failed.' }

    $tests = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.test.cjs' | ForEach-Object FullName)
    node --test @tests
    if ($LASTEXITCODE -ne 0) { throw 'Command/workflow guard tests failed.' }

    foreach ($directory in @('azure/bootstrap', 'azure/environments/staging', 'gcp/bootstrap', 'gcp/environments/ai-staging')) {
        Push-Location $directory
        try {
            terraform init -backend=false -input=false
            if ($LASTEXITCODE -ne 0) { throw "Terraform init failed in $directory." }
            terraform validate
            if ($LASTEXITCODE -ne 0) { throw "Terraform validation failed in $directory." }
            if ($directory -eq 'azure/environments/staging') {
                terraform test
                if ($LASTEXITCODE -ne 0) { throw 'Mocked Azure layout tests failed.' }
            }
        }
        finally { Pop-Location }
    }
}
finally { Pop-Location }

Write-Output 'Checks passed. No cloud resources were changed.'
