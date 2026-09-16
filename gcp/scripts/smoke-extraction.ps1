param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,

    [Parameter(Mandatory = $true)]
    [string]$ImagePath,

    [string]$Region = 'europe-west1',
    [string]$Service = 'fiscora-nuextract'
)

$ErrorActionPreference = 'Stop'

$resolvedImage = Resolve-Path -LiteralPath $ImagePath
$extension = [IO.Path]::GetExtension($resolvedImage.Path).ToLowerInvariant()
$mimeType = switch ($extension) {
    '.png' { 'image/png' }
    '.jpg' { 'image/jpeg' }
    '.jpeg' { 'image/jpeg' }
    '.jfif' { 'image/jpeg' }
    default { throw "Unsupported smoke-test image type: $extension" }
}

$uri = gcloud run services describe $Service `
    --project $ProjectId `
    --region $Region `
    --format 'value(status.url)'

if (-not $uri) {
    throw 'Cloud Run service URI was not found.'
}

$token = gcloud auth print-identity-token
if (-not $token) {
    throw 'Could not create a Google identity token.'
}

$template = [ordered]@{
    document_type = @('invoice', 'credit_note', 'bank_statement', 'receipt', 'other')
    supplier = [ordered]@{
        name    = 'verbatim-string'
        tax_id  = 'verbatim-string'
        address = 'verbatim-string'
    }
    customer = [ordered]@{
        name       = 'verbatim-string'
        customer_id = 'verbatim-string'
        address    = 'verbatim-string'
    }
    document_number  = 'verbatim-string'
    issue_date       = 'date-time'
    currency         = 'currency'
    subtotal_excl_tax = 'number'
    tax_amount       = 'number'
    stamp_tax        = 'number'
    total_incl_tax   = 'number'
    amount_due       = 'number'
    line_items = @([ordered]@{
        description = 'verbatim-string'
        quantity    = 'number'
        unit_price  = 'number'
        tax_rate    = 'number'
        line_total  = 'number'
    })
}

$instructions = @'
Classify document_type from visible evidence, then extract all applicable fields.
Use null for information that is unreadable or absent and never infer hidden identifiers.
Preserve printed identifiers exactly. Use ISO-8601 dates and ISO-4217 currencies.
For Tunisian documents, DT means TND and a comma followed by three digits is a millime decimal separator.
Keep fiscal stamp separate. Financial values must be validated by the application before acceptance.
'@

$encodedImage = [Convert]::ToBase64String([IO.File]::ReadAllBytes($resolvedImage.Path))
$payload = [ordered]@{
    model       = 'numind/NuExtract3'
    temperature = 0.2
    max_tokens  = 2400
    messages    = @([ordered]@{
        role    = 'user'
        content = @([ordered]@{
            type      = 'image_url'
            image_url = [ordered]@{ url = "data:$mimeType;base64,$encodedImage" }
        })
    })
    chat_template_kwargs = [ordered]@{
        template        = ($template | ConvertTo-Json -Depth 10 -Compress)
        instructions    = $instructions
        enable_thinking = $false
    }
} | ConvertTo-Json -Depth 20 -Compress

$timer = [Diagnostics.Stopwatch]::StartNew()
$response = Invoke-RestMethod `
    -Method Post `
    -Uri "$uri/v1/chat/completions" `
    -Headers @{ Authorization = "Bearer $token" } `
    -ContentType 'application/json' `
    -Body $payload `
    -TimeoutSec 900
$timer.Stop()

$raw = [string]$response.choices[0].message.content
$candidate = $raw -replace '(?is)^\s*<answer>\s*', '' -replace '(?is)\s*</answer>\s*$', ''
$candidate = $candidate -replace '(?is)^\s*```(?:json)?\s*', '' -replace '(?is)\s*```\s*$', ''

try {
    $parsed = $candidate | ConvertFrom-Json
}
catch {
    throw "NuExtract returned non-JSON output: $raw"
}

[pscustomobject]@{
    Status         = 'ok'
    ElapsedSeconds = [Math]::Round($timer.Elapsed.TotalSeconds, 2)
    PromptTokens   = $response.usage.prompt_tokens
    OutputTokens   = $response.usage.completion_tokens
    Extraction     = $parsed
}
