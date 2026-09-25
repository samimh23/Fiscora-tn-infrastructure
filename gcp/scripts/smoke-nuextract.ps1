param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,

    [Parameter(Mandatory = $true)]
    [string]$ImagePath,

    [string]$Region = 'europe-west1',
    [string]$Service = 'fiscora-nuextract-v3'
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
if (-not $uri) { throw 'NuExtract Cloud Run service URI was not found.' }

$token = gcloud auth print-identity-token
if (-not $token) { throw 'Could not create a Google identity token.' }

$template = [ordered]@{
    document_type = @('invoice', 'credit_note', 'receipt')
    supplier = [ordered]@{ name = 'verbatim-string'; tax_id = 'verbatim-string'; address = 'verbatim-string' }
    document_number = 'verbatim-string'
    issue_date = 'verbatim-string'
    subtotal_excl_tax = 'verbatim-string'
    tax_amount = 'verbatim-string'
    total_incl_tax = 'verbatim-string'
    amount_due = 'verbatim-string'
    line_items = @([ordered]@{
        reference = 'verbatim-string'
        description = 'verbatim-string'
        quantity = 'verbatim-string'
        unit_price = 'verbatim-string'
        tax_rate = 'verbatim-string'
        line_total = 'verbatim-string'
    })
} | ConvertTo-Json -Depth 10 -Compress

$encodedImage = [Convert]::ToBase64String([IO.File]::ReadAllBytes($resolvedImage.Path))
$payload = [ordered]@{
    model = 'numind/NuExtract3'
    temperature = 0
    max_tokens = 4000
    chat_template_kwargs = [ordered]@{
        template = $template
        instructions = 'Copy only visible values, preserve printed monetary formatting, and never calculate. A tax_id must come only from MF, matricule fiscal or tax ID; never use an IBAN, RIB, bank account, phone, barcode, RC or registration number as tax_id. Return JSON only.'
        enable_thinking = $false
    }
    messages = @(
        [ordered]@{
            role = 'user'
            content = @(
                [ordered]@{
                    type = 'image_url'
                    image_url = [ordered]@{ url = "data:$mimeType;base64,$encodedImage" }
                }
            )
        }
    )
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
try { $parsed = $raw | ConvertFrom-Json }
catch { throw "NuExtract returned non-JSON output: $raw" }

[pscustomobject]@{
    Status = 'ok'
    ElapsedSeconds = [Math]::Round($timer.Elapsed.TotalSeconds, 2)
    PromptTokens = $response.usage.prompt_tokens
    OutputTokens = $response.usage.completion_tokens
    Extraction = $parsed
}
