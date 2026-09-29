[CmdletBinding()]
param(
    [string] $ComposePath = (Join-Path $PSScriptRoot '..\..\chabok-platform-infrastructure\compose.yaml')
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$composePath = (Resolve-Path -LiteralPath $ComposePath).Path
$initializerPath = Join-Path $repositoryRoot 'swagger\swagger-initializer.js'
$nginxPath = Join-Path $repositoryRoot 'swagger\nginx.conf'
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-Contains {
    param(
        [string] $Name,
        [string] $Text,
        [string] $Expected
    )

    if ($Text.Contains($Expected)) {
        Write-Output "PASS | $Name"
        return
    }

    Write-Output "FAIL | $Name | missing: $Expected"
    $script:failures.Add($Name)
}

$compose = [System.IO.File]::ReadAllText($composePath)
$initializer = [System.IO.File]::ReadAllText($initializerPath)
$nginx = [System.IO.File]::ReadAllText($nginxPath)

Assert-Contains 'Pinned Swagger UI image' $compose 'image: swaggerapi/swagger-ui:v5.32.11@sha256:e43eb34b978af58d8cb78e5da9c12d605cf43d113ad3a96b18f9b028d6479d68'
Assert-Contains 'Explicit docs profile gate' $compose 'profiles: ["docs"]'
Assert-Contains 'Read-only compatible nginx entrypoint' $compose 'entrypoint: ["nginx", "-g", "daemon off;"]'
Assert-Contains 'Loopback-only documentation port' $compose '"127.0.0.1:${SWAGGER_UI_PORT:-8081}:8080"'
Assert-Contains 'Authoritative contracts mounted read-only' $compose '../chabok-api-contracts/v1:/usr/share/nginx/html/openapi/v1:ro'

$expectedSpecifications = [ordered]@{
    'Chabok IAM API' = '/openapi/v1/iam.yaml'
    'Chabok Consignment API' = '/openapi/v1/consignments.yaml'
    'Chabok Manifest API' = '/openapi/v1/manifests.yaml'
    'Chabok Dashboard API' = '/openapi/v1/dashboard.yaml'
    'Chabok Service Catalog API' = '/openapi/v1/service-catalog.yaml'
    'Chabok Pricing API' = '/openapi/v1/pricing.yaml'
    'Chabok Geography Reference API' = '/openapi/v1/geography.yaml'
    'Chabok Operations API' = '/openapi/v1/operations.yaml'
    'Chabok Network Administration API' = '/openapi/v1/network.yaml'
    'Chabok Fleet Administration API' = '/openapi/v1/fleet.yaml'
    'Chabok CRM API' = '/openapi/v1/crm.yaml'
}
foreach ($entry in $expectedSpecifications.GetEnumerator()) {
    Assert-Contains "$($entry.Key) selector label" $initializer "name: `"$($entry.Key)`""
    Assert-Contains "$($entry.Key) source" $initializer "url: `"$($entry.Value)`""
}

Assert-Contains 'Browser credentials explicitly enabled' $initializer 'withCredentials: true'
Assert-Contains 'Authorization is memory-only' $initializer 'persistAuthorization: false'
Assert-Contains 'Remote specification validator disabled' $initializer 'validatorUrl: null'
Assert-Contains 'Runtime-resolved backend service' $nginx 'resolver 127.0.0.11'
Assert-Contains 'Same-origin API proxy' $nginx 'proxy_pass $backend_upstream;'
Assert-Contains 'OpenAPI files are read-only over HTTP' $nginx 'limit_except GET HEAD'
Assert-Contains 'YAML response media type' $nginx 'default_type application/yaml;'
Assert-Contains 'Documentation framing denied' $nginx 'X-Frame-Options "DENY"'

$resolvedCompose = docker compose -f $composePath --profile docs config
if ($LASTEXITCODE -ne 0) {
    Write-Output 'FAIL | Docker Compose configuration'
    $failures.Add('Docker Compose configuration')
} else {
    Write-Output 'PASS | Docker Compose configuration'
}

$defaultServices = @(docker compose -f $composePath config --services)
if ($LASTEXITCODE -ne 0 -or $defaultServices -contains 'swagger-ui') {
    Write-Output 'FAIL | Documentation disabled without docs profile'
    $failures.Add('Documentation disabled without docs profile')
} else {
    Write-Output 'PASS | Documentation disabled without docs profile'
}

$docsServices = @(docker compose -f $composePath --profile docs config --services)
if ($LASTEXITCODE -ne 0 -or $docsServices -notcontains 'swagger-ui') {
    Write-Output 'FAIL | Documentation enabled only through docs profile'
    $failures.Add('Documentation enabled only through docs profile')
} else {
    Write-Output 'PASS | Documentation enabled only through docs profile'
}

if ($failures.Count -gt 0) {
    throw "Swagger UI validation failed: $($failures -join ', ')"
}

Write-Output "SWAGGER_UI_CONFIGURATION_OK specifications=$($expectedSpecifications.Count)"
