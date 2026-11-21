param([switch]$PrepareKeyOnly)
$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot '..\backend\AvoraAI.API\AvoraAI.API.csproj'
[xml]$projectXml = Get-Content -LiteralPath $project -Raw
$secretsId = $projectXml.Project.PropertyGroup.UserSecretsId | Select-Object -First 1
if (-not $secretsId) { throw 'User Secrets is not initialized for AvoraAI.API.' }

$store = Join-Path $env:APPDATA "Microsoft\UserSecrets\$secretsId"
New-Item -ItemType Directory -Force -Path $store | Out-Null
$secretFile = Join-Path $store 'secrets.json'
$secrets = @{}
if (Test-Path -LiteralPath $secretFile) {
    $existing = Get-Content -LiteralPath $secretFile -Raw | ConvertFrom-Json
    if ($existing) { foreach ($property in $existing.PSObject.Properties) { $secrets[$property.Name] = $property.Value } }
}

if ($PrepareKeyOnly) {
    [byte[]]$randomBytes = New-Object byte[] 48
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($randomBytes) } finally { $rng.Dispose() }
    $secrets['SuperAdminBootstrap:SetupKey'] = [Convert]::ToBase64String($randomBytes)
    [System.IO.File]::WriteAllText($secretFile, (ConvertTo-Json -InputObject $secrets -Depth 8), [System.Text.UTF8Encoding]::new($false))
    Write-Host 'One-time SuperAdmin setup key prepared. Restart the API before continuing.'
    return
}

$setupKey = $secrets['SuperAdminBootstrap:SetupKey']
if ([string]::IsNullOrWhiteSpace($setupKey)) { throw 'Run this script with -PrepareKeyOnly, restart the API, then run it again to provision.' }
$secure = $null
$pointer = [IntPtr]::Zero
$password = $null
try {
    $email = Read-Host 'SuperAdmin email'
    $secure = Read-Host 'Initial SuperAdmin password (input is hidden)' -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    $payload = @{ setupKey = $setupKey; email = $email.Trim(); password = $password } | ConvertTo-Json -Compress
    $result = Invoke-RestMethod -Uri 'http://127.0.0.1:5080/api/setup/bootstrap-superadmin' -Method Post -ContentType 'application/json' -Body $payload
    Write-Host ("Created initial SuperAdmin for {0}. It must change its password at first login." -f $result.email)
}
finally {
    if (Test-Path -LiteralPath $secretFile) {
        $stored = Get-Content -LiteralPath $secretFile -Raw | ConvertFrom-Json
        $remaining = @{}
        if ($stored) { foreach ($property in $stored.PSObject.Properties) { if ($property.Name -ne 'SuperAdminBootstrap:SetupKey') { $remaining[$property.Name] = $property.Value } } }
        [System.IO.File]::WriteAllText($secretFile, (ConvertTo-Json -InputObject $remaining -Depth 8), [System.Text.UTF8Encoding]::new($false))
    }
    if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
    if ($secure) { $secure.Dispose() }
    $password = $null; $payload = $null; $setupKey = $null
}
