[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RouteInventoryPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$contractPaths = @(
    (Join-Path $repositoryRoot 'v1\iam.yaml'),
    (Join-Path $repositoryRoot 'v1\consignments.yaml'),
    (Join-Path $repositoryRoot 'v1\manifests.yaml'),
    (Join-Path $repositoryRoot 'v1\dashboard.yaml'),
    (Join-Path $repositoryRoot 'v1\service-catalog.yaml'),
    (Join-Path $repositoryRoot 'v1\pricing.yaml'),
    (Join-Path $repositoryRoot 'v1\geography.yaml'),
    (Join-Path $repositoryRoot 'v1\operations.yaml'),
    (Join-Path $repositoryRoot 'v1\network.yaml'),
    (Join-Path $repositoryRoot 'v1\fleet.yaml'),
    (Join-Path $repositoryRoot 'v1\crm.yaml')
)

$contractOperations = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal
)
foreach ($contractPath in $contractPaths) {
    $currentPath = $null
    foreach ($line in [System.IO.File]::ReadAllLines($contractPath)) {
        if ($line -match '^  (/[^:]+):\s*$') {
            $currentPath = $Matches[1]
            continue
        }
        if ($null -ne $currentPath -and $line -match '^    (get|post|patch|put|delete):\s*$') {
            [void] $contractOperations.Add("$($Matches[1].ToUpperInvariant()) $currentPath")
        }
    }
}

$resolvedInventoryPath = (Resolve-Path -LiteralPath $RouteInventoryPath).Path
$routeJson = [System.IO.File]::ReadAllText($resolvedInventoryPath)

$routeInventory = $routeJson | ConvertFrom-Json
$implemented = @(
    $routeInventory | ForEach-Object {
        $method = ($_.method -split '\|')[0]
        $path = '/' + ($_.uri -replace '^api/v1/?', '')
        $path = $path.Replace('{userId}', '{user_id}').
            Replace('{sessionId}', '{session_id}').
            Replace('{roleId}', '{role_id}').
            Replace('{assignmentId}', '{assignment_id}').
            Replace('{cityId}', '{city_id}').
            Replace('{consignmentId}', '{consignment_id}').
            Replace('{manifestId}', '{manifest_id}')
        if ($path.StartsWith('/network/')) {
            $path = $path.Replace('{areaId}', '{area_id}').
                Replace('{nodeId}', '{node_id}').
                Replace('{policyId}', '{policy_id}').
                Replace('{versionId}', '{version_id}').
                Replace('{definitionId}', '{route_definition_id}')
        }
        if ($path.StartsWith('/network/') -and $path.Contains('{action}')) {
            foreach ($action in @('validate', 'approve', 'publish', 'supersede', 'archive')) {
                "$method $($path.Replace('{action}', $action))"
            }
        }
        else {
            "$method $path"
        }
    } | Sort-Object -Unique
)

$missing = @($implemented | Where-Object { -not $contractOperations.Contains($_) })
if ($missing.Count -gt 0) {
    throw "Implemented routes missing from approved OpenAPI contract: $($missing -join ', ')"
}

$unimplemented = @($contractOperations | Where-Object { $_ -notin $implemented })
if ($unimplemented.Count -gt 0) {
    throw "Approved OpenAPI operations missing from Laravel routes: $($unimplemented -join ', ')"
}

Write-Output "OPENAPI_ROUTE_CONFORMANCE_OK implemented=$($implemented.Count) contract=$($contractOperations.Count)"
