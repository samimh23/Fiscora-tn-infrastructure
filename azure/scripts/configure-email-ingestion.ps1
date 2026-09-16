[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$KeyVaultName,

    [Parameter(Mandatory)]
    [ValidatePattern('^https://')]
    [string]$ApiBaseUrl,

    [Parameter(Mandatory)]
    [SecureString]$BrevoApiKey,

    [string]$ReceivingDomain = 'inbox.fiscora.me',

    [switch]$RotateWebhookSecret
)

$ErrorActionPreference = 'Stop'
$description = 'Fiscora inbound accounting documents'
$webhookSecretName = 'inbound-email-webhook-secret'
$brevoApiKeySecretName = 'brevo-api-key'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI (az) is required. Install it and run az login first.'
}

$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($BrevoApiKey)
try {
    $apiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    if ([string]::IsNullOrWhiteSpace($apiKey) -or -not $apiKey.StartsWith('xkeysib-')) {
        throw 'BrevoApiKey must be a Brevo REST API key beginning with xkeysib-. The SMTP key cannot be used.'
    }

    $webhookSecret = $null
    if (-not $RotateWebhookSecret) {
        $webhookSecret = az keyvault secret show `
            --vault-name $KeyVaultName `
            --name $webhookSecretName `
            --query value `
            --output tsv 2>$null
        if ($LASTEXITCODE -ne 0) { $webhookSecret = $null }
    }
    if ([string]::IsNullOrWhiteSpace($webhookSecret) -or $webhookSecret.Length -lt 32) {
        $bytes = New-Object byte[] 32
        [Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
        $webhookSecret = [Convert]::ToHexString($bytes).ToLowerInvariant()
        [Array]::Clear($bytes, 0, $bytes.Length)
    }

    if ($PSCmdlet.ShouldProcess($KeyVaultName, 'Store inbound Brevo credentials and configure its webhook')) {
        az keyvault secret set `
            --vault-name $KeyVaultName `
            --name $brevoApiKeySecretName `
            --value $apiKey `
            --output none
        if ($LASTEXITCODE -ne 0) { throw "Azure CLI could not store $brevoApiKeySecretName." }

        az keyvault secret set `
            --vault-name $KeyVaultName `
            --name $webhookSecretName `
            --value $webhookSecret `
            --output none
        if ($LASTEXITCODE -ne 0) { throw "Azure CLI could not store $webhookSecretName." }

        $headers = @{
            accept         = 'application/json'
            'api-key'      = $apiKey
            'content-type' = 'application/json'
        }
        $webhookUrl = "$($ApiBaseUrl.TrimEnd('/'))/api/email-ingestion/brevo"
        $body = @{
            type        = 'inbound'
            events      = @('inboundEmailProcessed')
            url         = $webhookUrl
            domain      = $ReceivingDomain
            description = $description
            headers     = @(
                @{
                    key   = 'x-fiscora-webhook-secret'
                    value = $webhookSecret
                }
            )
        } | ConvertTo-Json -Depth 5

        $existing = Invoke-RestMethod `
            -Method Get `
            -Uri 'https://api.brevo.com/v3/webhooks?type=inbound&sort=desc' `
            -Headers $headers
        $match = @($existing.webhooks) |
            Where-Object { $_.domain -eq $ReceivingDomain -or $_.description -eq $description } |
            Select-Object -First 1

        if ($match) {
            Invoke-WebRequest `
                -Method Put `
                -Uri "https://api.brevo.com/v3/webhooks/$($match.id)" `
                -Headers $headers `
                -Body $body | Out-Null
            Write-Host "Updated Brevo inbound webhook $($match.id)."
        }
        else {
            $created = Invoke-RestMethod `
                -Method Post `
                -Uri 'https://api.brevo.com/v3/webhooks' `
                -Headers $headers `
                -Body $body
            Write-Host "Created Brevo inbound webhook $($created.id)."
        }

        Write-Host ''
        Write-Host 'Add these DNS records in Namecheap Advanced DNS:'
        Write-Host "MX | Host: inbox | Priority: 10 | Value: inbound1.sendinblue.com"
        Write-Host "MX | Host: inbox | Priority: 20 | Value: inbound2.sendinblue.com"
        Write-Host ''
        Write-Host 'Run terraform apply after the secrets exist so the Container App receives them.'
    }
}
finally {
    if ($pointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
    $apiKey = $null
    $webhookSecret = $null
}
