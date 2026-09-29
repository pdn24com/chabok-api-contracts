$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$openApiPath = Join-Path $repositoryRoot 'v1\iam.yaml'
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

$openApiText = [System.IO.File]::ReadAllText(
    $openApiPath,
    [System.Text.UTF8Encoding]::new($false, $true)
)
$operationIds = @(
    [regex]::Matches($openApiText, '(?m)^      operationId:\s+([A-Za-z0-9._-]+)\s*$') |
        ForEach-Object { $_.Groups[1].Value }
)
$uniqueOperationIds = @($operationIds | Sort-Object -Unique)
Add-CheckResult 'Operation-ID uniqueness' (
    $operationIds.Count -gt 0 -and $operationIds.Count -eq $uniqueOperationIds.Count
) "operationIds=$($operationIds.Count); unique=$($uniqueOperationIds.Count)"

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

$generatedTextFiles = @(Get-ChildItem (Join-Path $repositoryRoot 'v1') -Filter '*.yaml')
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
