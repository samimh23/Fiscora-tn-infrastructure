[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AwsManifestPath,

    [Parameter(Mandatory)]
    [string]$AzureManifestPath
)

$ErrorActionPreference = 'Stop'

foreach ($path in @($AwsManifestPath, $AzureManifestPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Manifest not found: $path" }
}

$source = Get-Content -LiteralPath $AwsManifestPath | Sort-Object
$destination = Get-Content -LiteralPath $AzureManifestPath | Sort-Object
$difference = Compare-Object -ReferenceObject $source -DifferenceObject $destination

if ($difference) {
    $difference | Format-Table -AutoSize
    throw 'Migration verification failed: the object manifests differ.'
}

Write-Host "Migration verification passed for $($source.Count) manifest entries."
