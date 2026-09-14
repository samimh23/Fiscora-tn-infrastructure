[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$KeyVaultName,

    [Parameter(Mandatory)]
    [SecureString]$BrevoSmtpKey
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI (az) is required. Install it and run az login first.'
}

if ($PSCmdlet.ShouldProcess($KeyVaultName, 'Store the Brevo SMTP key')) {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($BrevoSmtpKey)
    try {
        $plainText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        az keyvault secret set `
            --vault-name $KeyVaultName `
            --name smtp-password `
            --value $plainText `
            --output none
        if ($LASTEXITCODE -ne 0) { throw 'Azure CLI could not store smtp-password.' }
    }
    finally {
        if ($pointer -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        }
        $plainText = $null
    }
}
