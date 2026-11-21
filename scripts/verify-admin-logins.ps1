$ErrorActionPreference = 'Stop'
$usernames = @('Thanhadmin', 'Vuadmin', 'Nhanadmin')
foreach ($username in $usernames) {
    $secure = Read-Host "Password for $username (input is hidden)" -AsSecureString
    $pointer = [IntPtr]::Zero
    $password = $null
    try {
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        $payload = @{ email = $username; password = $password } | ConvertTo-Json -Compress
        $session = Invoke-RestMethod -Uri 'http://127.0.0.1:5080/api/auth/login' -Method Post -ContentType 'application/json' -Body $payload
        Invoke-RestMethod -Uri 'http://127.0.0.1:5080/api/auth/logout' -Method Post -ContentType 'application/json' -Body (@{ refreshToken = $session.refreshToken } | ConvertTo-Json -Compress) | Out-Null
        Write-Host "$username login verified; test session revoked."
    }
    catch {
        Write-Error "$username login verification failed."
        exit 1
    }
    finally {
        if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
        if ($secure) { $secure.Dispose() }
        $password = $null
        $payload = $null
        $session = $null
    }
}
