[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^i-[a-f0-9]+$')]
    [string]$InstanceId,

    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$')]
    [string]$BucketName,

    [string]$AwsProfile = 'fiscora-admin',
    [string]$AwsRegion = 'eu-north-1',
    [string]$BackupPrefix = (Get-Date -Format 'yyyyMMdd-HHmmss'),
    [string]$DestinationDirectory = (Join-Path $PSScriptRoot 'out'),
    [switch]$Execute
)

$ErrorActionPreference = 'Stop'

if ($BackupPrefix -notmatch '^[a-zA-Z0-9/_-]+$') {
    throw 'BackupPrefix may contain only letters, digits, slash, underscore and hyphen.'
}
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    throw 'AWS CLI is required.'
}

$s3Prefix = "s3://$BucketName/azure-migration/$BackupPrefix"
$commands = @(
    'set -euo pipefail',
    'rm -rf /opt/fiscora/migration && install -d -m 0700 /opt/fiscora/migration/documents',
    'docker exec fiscora-staging-postgres-1 pg_dump -U accounting -d accounting_nest -Fc -f /tmp/accounting.dump',
    'docker cp fiscora-staging-postgres-1:/tmp/accounting.dump /opt/fiscora/migration/accounting.dump',
    'docker exec fiscora-staging-postgres-1 rm -f /tmp/accounting.dump',
    'docker run --rm --network fiscora-staging_default --env-file /opt/fiscora/.env --entrypoint /bin/sh -v /opt/fiscora/migration/documents:/export minio/mc:RELEASE.2025-04-16T18-13-26Z -c ''mc alias set source http://minio:9000 "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" >/dev/null && mc mirror --overwrite source/"$MINIO_BUCKET" /export''',
    'tar -C /opt/fiscora/migration/documents -czf /opt/fiscora/migration/documents.tar.gz .',
    'cd /opt/fiscora/migration && sha256sum accounting.dump documents.tar.gz > SHA256SUMS',
    "aws s3 cp /opt/fiscora/migration/accounting.dump '$s3Prefix/accounting.dump' --only-show-errors",
    "aws s3 cp /opt/fiscora/migration/documents.tar.gz '$s3Prefix/documents.tar.gz' --only-show-errors",
    "aws s3 cp /opt/fiscora/migration/SHA256SUMS '$s3Prefix/SHA256SUMS' --only-show-errors"
)

Write-Host 'Planned export:'
Write-Host "  EC2 instance: $InstanceId"
Write-Host "  Destination:  $s3Prefix"
Write-Host '  Contents: PostgreSQL custom dump, plain document objects, SHA-256 manifest'

if (-not $Execute) {
    Write-Host 'Dry run only. Re-run with -Execute after reviewing the values.'
    return
}

$request = @{
    DocumentName = 'AWS-RunShellScript'
    InstanceIds  = @($InstanceId)
    Comment      = "Fiscora Azure migration export $BackupPrefix"
    Parameters   = @{ commands = $commands }
} | ConvertTo-Json -Depth 6

$requestFile = [IO.Path]::GetTempFileName()
try {
    [IO.File]::WriteAllText($requestFile, $request, [Text.UTF8Encoding]::new($false))
    $response = aws ssm send-command `
        --profile $AwsProfile `
        --region $AwsRegion `
        --cli-input-json "file://$requestFile" `
        --output json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw 'AWS SSM rejected the export command.' }

    $commandId = $response.Command.CommandId
    aws ssm wait command-executed `
        --profile $AwsProfile `
        --region $AwsRegion `
        --command-id $commandId `
        --instance-id $InstanceId
    if ($LASTEXITCODE -ne 0) {
        aws ssm get-command-invocation --profile $AwsProfile --region $AwsRegion --command-id $commandId --instance-id $InstanceId
        throw 'The remote export failed. Review the SSM output above.'
    }

    New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null
    foreach ($file in @('accounting.dump', 'documents.tar.gz', 'SHA256SUMS')) {
        aws s3 cp "$s3Prefix/$file" (Join-Path $DestinationDirectory $file) `
            --profile $AwsProfile `
            --region $AwsRegion `
            --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw "Could not download $file." }
    }
}
finally {
    Remove-Item -LiteralPath $requestFile -Force -ErrorAction SilentlyContinue
}

Write-Host "Export downloaded to $DestinationDirectory. Do not delete AWS yet."
