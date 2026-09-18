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

$instructions = @'
Classify the financial document and extract it to JSON. Copy monetary values,
quantities, rates and identifiers exactly as printed. Keep all spaces, commas
and points exactly as they appear. Do not calculate, normalize or multiply any
number. Preserve every table row in printed order. Use null instead of guessing.
'@

$encodedImage = [Convert]::ToBase64String([IO.File]::ReadAllBytes($resolvedImage.Path))
$payload = [ordered]@{
    model           = 'Qwen/Qwen3.5-4B'
    temperature     = 0
    seed            = 0
    max_tokens      = 8000
    response_format = [ordered]@{ type = 'json_object' }
    messages        = @(
        [ordered]@{ role = 'system'; content = $instructions },
        [ordered]@{
            role    = 'user'
            content = @(
                [ordered]@{
                    type      = 'image_url'
                    image_url = [ordered]@{ url = "data:$mimeType;base64,$encodedImage" }
                },
                [ordered]@{
                    type = 'text'
                    text = 'Return only the extracted JSON.'
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
$candidate = $raw -replace '(?is)^\s*<answer>\s*', '' -replace '(?is)\s*</answer>\s*$', ''
$candidate = $candidate -replace '(?is)^\s*```(?:json)?\s*', '' -replace '(?is)\s*```\s*$', ''

try {
    $parsed = $candidate | ConvertFrom-Json
}
catch {
    throw "Qwen returned non-JSON output: $raw"
}

[pscustomobject]@{
    Status         = 'ok'
    ElapsedSeconds = [Math]::Round($timer.Elapsed.TotalSeconds, 2)
    PromptTokens   = $response.usage.prompt_tokens
    OutputTokens   = $response.usage.completion_tokens
    Extraction     = $parsed
}
