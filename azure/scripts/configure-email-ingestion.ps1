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

        # Brevo returns HTTP 404/document_not_found when an account has no
        # inbound webhook yet. That is the normal first-run state, so treat it
        # as an empty collection and create the webhook below.
        try {
            $existing = Invoke-RestMethod `
                -Method Get `
                -Uri 'https://api.brevo.com/v3/webhooks?type=inbound&sort=desc' `
                -Headers $headers
        }
        catch {
            $statusCode = [int]$_.Exception.Response.StatusCode
            $errorBody = $_.ErrorDetails.Message
            if ($statusCode -eq 404 -or $errorBody -match 'document_not_found') {
                $existing = @{ webhooks = @() }
            }
            else {
                throw
            }
        }
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
        Write-Host "Brevo inbound MX records must resolve for $ReceivingDomain."
        Write-Host 'This repository manages them in a delegated Azure DNS zone.'
        Write-Host 'Add every value from Terraform output email_ingestion_dns_name_servers'
        Write-Host 'to Namecheap as an NS record with Host inbox. Keep root Mail Settings unchanged.'
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
