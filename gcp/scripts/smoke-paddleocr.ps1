param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,

    [Parameter(Mandatory = $true)]
    [string]$DocumentPath,

    [string]$Region = 'europe-west1',
    [string]$Service = 'fiscora-paddleocr'
)

$ErrorActionPreference = 'Stop'

$resolvedDocument = Resolve-Path -LiteralPath $DocumentPath
$extension = [IO.Path]::GetExtension($resolvedDocument.Path).ToLowerInvariant()
$mimeType = switch ($extension) {
    '.pdf' { 'application/pdf' }
    '.png' { 'image/png' }
    '.jpg' { 'image/jpeg' }
    '.jpeg' { 'image/jpeg' }
    default { throw "Unsupported OCR smoke-test document type: $extension" }
}

$uri = gcloud run services describe $Service `
    --project $ProjectId `
    --region $Region `
    --format 'value(status.url)'

if (-not $uri) {
    throw 'PaddleOCR Cloud Run service URI was not found.'
}

$token = gcloud auth print-identity-token
if (-not $token) {
    throw 'Could not create a Google identity token.'
}

$payload = [ordered]@{
    mimeType      = $mimeType
    contentBase64 = [Convert]::ToBase64String(
        [IO.File]::ReadAllBytes($resolvedDocument.Path)
    )
} | ConvertTo-Json -Depth 5 -Compress

$timer = [Diagnostics.Stopwatch]::StartNew()
$response = Invoke-RestMethod `
    -Method Post `
    -Uri "$uri/ocr" `
    -Headers @{ Authorization = "Bearer $token" } `
    -ContentType 'application/json' `
    -Body $payload `
    -TimeoutSec 1200
$timer.Stop()

if (-not $response.tokens -or $response.tokens.Count -lt 1) {
    throw 'PaddleOCR returned no tokens.'
}

[pscustomobject]@{
    Status         = 'ok'
    ServiceUri     = $uri
    MimeType       = $mimeType
    PageCount      = if ($response.pageCount) { $response.pageCount } else { 1 }
    TokenCount     = $response.tokens.Count
    ElapsedSeconds = [Math]::Round($timer.Elapsed.TotalSeconds, 2)
}
