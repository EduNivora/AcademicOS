$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$secretFile = Join-Path $repoRoot ".env.local"
$secureKey = $null
$keyPointer = [IntPtr]::Zero
$plainKey = $null

Push-Location $repoRoot
try {
    if (-not (Get-Command neon -ErrorAction SilentlyContinue)) {
        throw "Neon CLI is missing. Install it once with: npm install -g neon@latest"
    }

    if (-not (Test-Path (Join-Path $repoRoot ".neon"))) {
        throw "This checkout is not linked to Neon. Run 'neon link' and select project edunivora / branch br-late-bread-bajll3is, then run this script again."
    }

    Write-Host "Enter your Gemini API key. The input will be hidden."
    $secureKey = Read-Host -Prompt "Gemini API key" -AsSecureString
    if ($secureKey.Length -lt 10) {
        throw "The supplied key is empty or too short."
    }

    $keyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
    $plainKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPointer)

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText(
        $secretFile,
        ("GEMINI_API_KEY=" + $plainKey + [Environment]::NewLine),
        $utf8NoBom
    )

    Remove-Variable plainKey
    $plainKey = $null

    Write-Host "Deploying the Neon configuration and the server-side Gemini secret..."
    npm run neon:deploy -- --env .env.local
    if ($LASTEXITCODE -ne 0) {
        throw "Neon deployment failed. The local secret file will still be deleted."
    }

    Write-Host "Deployment completed. The local .env.local file will now be removed."
}
finally {
    if ($keyPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPointer)
    }
    if (Test-Path $secretFile) {
        Remove-Item $secretFile -Force
    }
    if ($null -ne $secureKey) {
        $secureKey.Dispose()
    }
    Pop-Location
}
