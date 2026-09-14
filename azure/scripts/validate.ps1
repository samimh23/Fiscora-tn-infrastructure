$ErrorActionPreference = 'Stop'

$azureRoot = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    throw 'Terraform >= 1.10 is required.'
}

Push-Location $azureRoot
try {
    terraform fmt -check -recursive
    if ($LASTEXITCODE -ne 0) { throw 'terraform fmt check failed.' }

    Push-Location 'bootstrap'
    try {
        terraform init -backend=false -input=false
        if ($LASTEXITCODE -ne 0) { throw 'Terraform bootstrap init failed.' }
        terraform validate
        if ($LASTEXITCODE -ne 0) { throw 'Terraform bootstrap validation failed.' }
    }
    finally { Pop-Location }

    Push-Location 'environments/staging'
    try {
        terraform init -backend=false -input=false
        if ($LASTEXITCODE -ne 0) { throw 'Terraform staging init failed.' }
        terraform validate
        if ($LASTEXITCODE -ne 0) { throw 'Terraform staging validation failed.' }
    }
    finally { Pop-Location }
}
finally { Pop-Location }
