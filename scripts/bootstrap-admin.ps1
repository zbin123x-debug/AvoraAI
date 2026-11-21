$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot '..\backend\AvoraAI.API\AvoraAI.API.csproj'
[xml]$projectXml = Get-Content -LiteralPath $project -Raw
$secretsId = $projectXml.Project.PropertyGroup.UserSecretsId | Select-Object -First 1
if (-not $secretsId) { throw 'User Secrets is not initialized for AvoraAI.API.' }

$email = Read-Host 'Initial Admin email'
$securePassword = Read-Host 'Initial Admin password (hidden)' -AsSecureString
$passwordBstr = [IntPtr]::Zero
$adminPassword = $null
$setupKey = $null
$secretFile = $null
try {
    $passwordBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $adminPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordBstr)
    $hasDigit = $adminPassword -match '[0-9]'
    $hasSymbol = $adminPassword.ToCharArray() | Where-Object {
        $code = [int]$_
        ($code -ge 33 -and $code -le 47) -or
        ($code -ge 58 -and $code -le 64) -or
        ($code -ge 91 -and $code -le 96) -or
        ($code -ge 123 -and $code -le 126)
    } | Select-Object -First 1
    if ($adminPassword.Length -lt 10 -or $adminPassword.Length -gt 128 -or -not [char]::IsUpper($adminPassword[0]) -or -not $hasDigit -or -not $hasSymbol) {
        throw 'Password must be 10-128 characters, start with an uppercase letter, and contain a digit and a symbol.'
    }

    [byte[]]$randomBytes = New-Object byte[] 48
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($randomBytes)
    $setupKey = [Convert]::ToBase64String($randomBytes)

    $store = Join-Path $env:APPDATA "Microsoft\UserSecrets\$secretsId"
    New-Item -ItemType Directory -Force -Path $store | Out-Null
    $secretFile = Join-Path $store 'secrets.json'
    $secrets = @{}
    if (Test-Path -LiteralPath $secretFile) {
        $existing = Get-Content -LiteralPath $secretFile -Raw | ConvertFrom-Json
        if ($existing) { foreach ($property in $existing.PSObject.Properties) { $secrets[$property.Name] = $property.Value } }
    }
    $secrets['AdminBootstrap:SetupKey'] = $setupKey
    [System.IO.File]::WriteAllText($secretFile, (ConvertTo-Json -InputObject $secrets -Depth 8), [System.Text.UTF8Encoding]::new($false))

    $payload = @{ setupKey = $setupKey; email = $email.Trim(); password = $adminPassword } | ConvertTo-Json -Compress
    Invoke-RestMethod -Uri 'http://127.0.0.1:5080/api/setup/bootstrap-admin' -Method Post -ContentType 'application/json' -Body $payload | Out-Null

    $secrets.Remove('AdminBootstrap:SetupKey')
    [System.IO.File]::WriteAllText($secretFile, (ConvertTo-Json -InputObject $secrets -Depth 8), [System.Text.UTF8Encoding]::new($false))
    Write-Host 'Initial Admin account created. The one-time setup key was removed from User Secrets.'
}
finally {
    if ($passwordBstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordBstr) }
    if ($secretFile -and (Test-Path -LiteralPath $secretFile)) {
        $stored = Get-Content -LiteralPath $secretFile -Raw | ConvertFrom-Json
        $remaining = @{}
        if ($stored) { foreach ($property in $stored.PSObject.Properties) { if ($property.Name -ne 'AdminBootstrap:SetupKey') { $remaining[$property.Name] = $property.Value } } }
        [System.IO.File]::WriteAllText($secretFile, (ConvertTo-Json -InputObject $remaining -Depth 8), [System.Text.UTF8Encoding]::new($false))
    }
    $adminPassword = $null
    $securePassword = $null
    $setupKey = $null
    $payload = $null
}
