$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot '..\backend\AvoraAI.API\AvoraAI.API.csproj'
[xml]$xml = Get-Content -LiteralPath $project -Raw
$secretsId = $xml.Project.PropertyGroup.UserSecretsId | Select-Object -First 1
if (-not $secretsId) { throw 'User Secrets is not initialized for AvoraAI.API.' }

$secure = Read-Host 'Enter the Google app password (input is hidden)' -AsSecureString
$bstr = [IntPtr]::Zero
try {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    if ([string]::IsNullOrWhiteSpace($password)) { throw 'Password cannot be empty.' }

    $store = Join-Path $env:APPDATA "Microsoft\UserSecrets\$secretsId"
    New-Item -ItemType Directory -Force -Path $store | Out-Null
    $secretFile = Join-Path $store 'secrets.json'
    $secrets = @{}
    if (Test-Path -LiteralPath $secretFile) {
        $existing = Get-Content -LiteralPath $secretFile -Raw | ConvertFrom-Json
        if ($existing) {
            foreach ($property in $existing.PSObject.Properties) {
                $secrets[$property.Name] = $property.Value
            }
        }
    }
    $secrets['Smtp:Password'] = $password
    $json = ConvertTo-Json -InputObject $secrets -Depth 8
    [System.IO.File]::WriteAllText($secretFile, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host 'SMTP password saved to local User Secrets. The value was not displayed.'
}
finally {
    if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    $password = $null
    $secure = $null
}
