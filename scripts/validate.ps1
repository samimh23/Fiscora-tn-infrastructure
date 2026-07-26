$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot

Push-Location $repositoryRoot
try {
    terraform fmt -check -recursive

    Push-Location "bootstrap"
    try {
        terraform init -backend=false -input=false
        terraform validate
    }
    finally {
        Pop-Location
    }

    Push-Location "environments/staging"
    try {
        terraform init -backend=false -input=false
        terraform validate
    }
    finally {
        Pop-Location
    }
}
finally {
    Pop-Location
}

