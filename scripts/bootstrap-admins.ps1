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
    $secrets['AdminBootstrap:SetupKey'] = [Convert]::ToBase64String($randomBytes)
    [System.IO.File]::WriteAllText($secretFile, (ConvertTo-Json -InputObject $secrets -Depth 8), [System.Text.UTF8Encoding]::new($false))
    Write-Host 'Temporary bootstrap key prepared in User Secrets. Restart the API before provisioning.'
    return
}

$setupKey = $secrets['AdminBootstrap:SetupKey']
if ([string]::IsNullOrWhiteSpace($setupKey)) { throw 'Run this script with -PrepareKeyOnly, restart the API, then run it again to provision.' }

$usernames = @('Thanhadmin', 'Vuadmin', 'Nhanadmin')
$admins = [System.Collections.Generic.List[object]]::new()
$secureInputs = [System.Collections.Generic.List[System.Security.SecureString]]::new()
$pointers = [System.Collections.Generic.List[IntPtr]]::new()
try {
    foreach ($username in $usernames) {
        $secure = Read-Host "Password for $username (input is hidden)" -AsSecureString
        $secureInputs.Add($secure)
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        $pointers.Add($pointer)
        $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        $admins.Add(@{ username = $username; password = $password })
    }

    $payload = @{ setupKey = $setupKey; admins = $admins } | ConvertTo-Json -Depth 6 -Compress
    $result = Invoke-RestMethod -Uri 'http://127.0.0.1:5080/api/setup/bootstrap-admins' -Method Post -ContentType 'application/json' -Body $payload
    Write-Host ("Created {0} admin accounts." -f $result.admins.Count)
}
finally {
    if ($secretFile -and (Test-Path -LiteralPath $secretFile)) {
        $stored = Get-Content -LiteralPath $secretFile -Raw | ConvertFrom-Json
        $remaining = @{}
        if ($stored) { foreach ($property in $stored.PSObject.Properties) { if ($property.Name -ne 'AdminBootstrap:SetupKey') { $remaining[$property.Name] = $property.Value } } }
        [System.IO.File]::WriteAllText($secretFile, (ConvertTo-Json -InputObject $remaining -Depth 8), [System.Text.UTF8Encoding]::new($false))
    }
    foreach ($pointer in $pointers) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
    foreach ($secure in $secureInputs) { $secure.Dispose() }
    $admins.Clear()
    $payload = $null
    $setupKey = $null
}
