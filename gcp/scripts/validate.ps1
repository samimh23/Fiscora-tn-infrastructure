$ErrorActionPreference = 'Stop'

$gcpRoot = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    throw 'Terraform >= 1.10 is required.'
}

Push-Location $gcpRoot
try {
    terraform fmt -check -recursive
    if ($LASTEXITCODE -ne 0) { throw 'terraform fmt check failed.' }

    foreach ($directory in @('bootstrap', 'environments/ai-staging')) {
        Push-Location $directory
        try {
            terraform init -backend=false -input=false
            if ($LASTEXITCODE -ne 0) { throw "Terraform init failed in $directory." }
            terraform validate
            if ($LASTEXITCODE -ne 0) { throw "Terraform validation failed in $directory." }
        }
        finally {
            Pop-Location
        }
    }
}
finally {
    Pop-Location
}

