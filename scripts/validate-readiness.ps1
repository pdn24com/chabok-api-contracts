$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem

$repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$contractPath = Join-Path $repositoryRoot 'docs\product\18-Chabok IAM Sprint 0 API Contract v1.1.docx'
$openApiPath = Join-Path $repositoryRoot 'openapi\v1\iam.yaml'
$failures = [System.Collections.Generic.List[string]]::new()

function Add-CheckResult {
    param(
        [string] $Name,
        [bool] $Passed,
        [string] $Details
    )

    if ($Passed) {
        Write-Output "PASS | $Name | $Details"
        return
    }

    Write-Output "FAIL | $Name | $Details"
    $script:failures.Add($Name)
}

$zip = [System.IO.Compression.ZipFile]::OpenRead($contractPath)
try {
    $entry = $zip.GetEntry('word/document.xml')
    $reader = [System.IO.StreamReader]::new($entry.Open())
    try {
        [xml] $document = $reader.ReadToEnd()
    } finally {
        $reader.Dispose()
    }

    $namespace = [System.Xml.XmlNamespaceManager]::new($document.NameTable)
    $namespace.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
    $sourceOperations = foreach ($row in $document.SelectNodes('//w:tr', $namespace)) {
        $cells = @(
            $row.SelectNodes('./w:tc', $namespace) | ForEach-Object {
                (
                    $_.SelectNodes('.//w:t', $namespace) |
                        ForEach-Object { $_.'#text' }
                ) -join ''
            }
        )

        if (
            $cells.Count -ge 2 -and
            $cells[0] -match '^(GET|POST|PATCH|PUT|DELETE)$' -and
            $cells[1] -match '^/'
        ) {
            "$($cells[0]) /api/v1$($cells[1])"
        }
    }
} finally {
    $zip.Dispose()
}

$openApiText = [System.IO.File]::ReadAllText(
    $openApiPath,
    [System.Text.UTF8Encoding]::new($false, $true)
)
$currentPath = $null
$openApiOperations = foreach ($line in $openApiText -split "`r?`n") {
    if ($line -match '^  (/[^:]+):$') {
        $currentPath = $Matches[1]
        continue
    }

    if ($currentPath -and $line -match '^    (get|post|patch|put|delete):$') {
        "$($Matches[1].ToUpperInvariant()) /api/v1$currentPath"
    }
}

$sourceSet = @($sourceOperations | Sort-Object -Unique)
$openApiSet = @($openApiOperations | Sort-Object -Unique)
$operationDiff = Compare-Object $sourceSet $openApiSet
Add-CheckResult 'IAM v1.1 exact operation inventory' (
    $sourceSet.Count -eq 34 -and
    $openApiSet.Count -eq 34 -and
    $null -eq $operationDiff
) "source=$($sourceSet.Count); openapi=$($openApiSet.Count); differences=$(@($operationDiff).Count)"

$operationIds = @(
    [regex]::Matches($openApiText, '(?m)^      operationId:\s+([A-Za-z0-9._-]+)\s*$') |
        ForEach-Object { $_.Groups[1].Value }
)
$uniqueOperationIds = @($operationIds | Sort-Object -Unique)
Add-CheckResult 'Operation-ID uniqueness' (
    $operationIds.Count -eq 34 -and $uniqueOperationIds.Count -eq 34
) "operationIds=$($operationIds.Count); unique=$($uniqueOperationIds.Count)"

$localReferences = @(
    [regex]::Matches($openApiText, "\`$ref:\s+'(#[^']+)'") |
        ForEach-Object { $_.Groups[1].Value }
)
Add-CheckResult 'Local-reference inventory' (
    $localReferences.Count -eq 285
) "references=$($localReferences.Count); resolution is enforced by Redocly"

Add-CheckResult 'Refresh-token response exposure guard' (
    $openApiText -notmatch '(?m)^\s+refresh_token:'
) 'no refresh_token property is declared'

$requiredContractFragments = @(
    'name: X-Correlation-ID',
    'name: X-Node-Id',
    'extension: IAM-EXT-011',
    'prohibited_error_code: PASSWORD_CHANGE_REQUIRED',
    'minProperties: 1',
    'permission_codes:',
    'uniqueItems: true',
    'same-site',
    'SameSite=Lax',
    'AUTHENTICATION_REQUIRED'
)
$missingFragments = @(
    $requiredContractFragments | Where-Object { -not $openApiText.Contains($_) }
)
$adminUpdateBlock = [regex]::Match(
    $openApiText,
    '(?ms)^    AdminUserUpdateRequest:.*?(?=^    [A-Za-z][A-Za-z0-9]+:)'
).Value
Add-CheckResult 'Security and schema regression guards' (
    $missingFragments.Count -eq 0 -and
    $openApiText -notmatch 'REFRESH_TOKEN_REUSED' -and
    $adminUpdateBlock -notmatch '(?m)^\s+(username|mobile|email):\s*$'
) "missingFragments=$($missingFragments.Count); no public reuse code"

$generatedTextFiles = @(
    Get-ChildItem (Join-Path $repositoryRoot 'docs\analysis') -Filter '*.md'
    Get-ChildItem (Join-Path $repositoryRoot 'docs\decisions') -Filter '*.md'
    Get-ChildItem (Join-Path $repositoryRoot 'docs\planning') -Filter '*.md'
    Get-ChildItem (Join-Path $repositoryRoot 'docs\architecture') -Filter '*.md'
    Get-ChildItem (Join-Path $repositoryRoot 'openapi') -Recurse -Include '*.yaml', '*.yml'
)
$encodingFailures = [System.Collections.Generic.List[string]]::new()
$strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
foreach ($file in $generatedTextFiles) {
    try {
        $text = [System.IO.File]::ReadAllText($file.FullName, $strictUtf8)
        if (
            $text.Contains([char] 0xFFFD) -or
            $text -match "\u00E2[\u0080-\u00BF]" -or
            $text -match "\u00C2[\u0080-\u00BF]"
        ) {
            $encodingFailures.Add($file.FullName)
        }
    } catch {
        $encodingFailures.Add($file.FullName)
    }
}
Add-CheckResult 'UTF-8 and mojibake guard' (
    $encodingFailures.Count -eq 0
) "files=$($generatedTextFiles.Count); failures=$($encodingFailures.Count)"

if ($failures.Count -gt 0) {
    throw "Readiness validation failed: $($failures -join ', ')"
}
