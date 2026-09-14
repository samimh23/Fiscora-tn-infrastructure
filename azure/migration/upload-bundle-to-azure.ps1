[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$StorageAccountName,

    [string]$ContainerName = 'accounting-documents',
    [string]$SourceDirectory = (Join-Path $PSScriptRoot 'out'),
    [string]$MigrationPrefix = (Get-Date -Format 'yyyyMMdd-HHmmss'),
    [switch]$Execute
)

$ErrorActionPreference = 'Stop'

if ($MigrationPrefix -notmatch '^[a-zA-Z0-9/_-]+$') {
    throw 'MigrationPrefix contains unsupported characters.'
}
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI is required. Run az login first.'
}

$required = @('accounting.dump', 'documents.tar.gz', 'SHA256SUMS')
foreach ($file in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $SourceDirectory $file))) {
        throw "Missing migration artifact: $file"
    }
}

$manifest = Get-Content -LiteralPath (Join-Path $SourceDirectory 'SHA256SUMS')
foreach ($file in @('accounting.dump', 'documents.tar.gz')) {
    $line = $manifest | Where-Object { $_ -match "\s+$([regex]::Escape($file))$" } | Select-Object -First 1
    if (-not $line) { throw "SHA256SUMS does not contain $file." }
    $expected = ($line -split '\s+')[0].ToLowerInvariant()
    $actual = (Get-FileHash -LiteralPath (Join-Path $SourceDirectory $file) -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) { throw "Checksum mismatch for $file." }
}

Write-Host "Verified migration bundle in $SourceDirectory."
Write-Host "Azure destination: $StorageAccountName/$ContainerName/migration/$MigrationPrefix"

if (-not $Execute) {
    Write-Host 'Dry run only. Re-run with -Execute to upload the verified bundle.'
    return
}

foreach ($file in $required) {
    if ($PSCmdlet.ShouldProcess($file, 'Upload migration artifact to Azure Blob Storage')) {
        az storage blob upload `
            --account-name $StorageAccountName `
            --container-name $ContainerName `
            --name "migration/$MigrationPrefix/$file" `
            --file (Join-Path $SourceDirectory $file) `
            --auth-mode login `
            --overwrite false `
            --output none
        if ($LASTEXITCODE -ne 0) { throw "Azure upload failed for $file." }
    }
}

Write-Host 'Upload complete. Database restore and document import must run from the private Azure network.'
