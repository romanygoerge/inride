# ==============================================================================
# SECURE ANDROID RELEASE KEYSTORE GENERATOR (POWERSHELL)
# ==============================================================================
# This script securely generates a production Android release keystore (upload-keystore.jks)
# and local `android/key.properties` without exposing passwords in command line logs.
# ==============================================================================

$ErrorActionPreference = "Stop"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "       inRide Android Release Keystore Generator (Secure)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir\.."
$AndroidDir = "$ProjectRoot\android"
$AppDir = "$AndroidDir\app"
$KeystorePath = "$AppDir\upload-keystore.jks"
$KeyPropertiesPath = "$AndroidDir\key.properties"

# 1. Check if keystore already exists
if (Test-Path $KeystorePath) {
    Write-Warning "A keystore already exists at: $KeystorePath"
    $confirm = Read-Host "Do you want to overwrite it? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "Operation cancelled. Existing keystore preserved." -ForegroundColor Yellow
        exit 0
    }
}

# 2. Find keytool
$KeytoolCmd = "keytool"
try {
    $null = Get-Command $KeytoolCmd -ErrorAction Stop
} catch {
    # Check JAVA_HOME
    if ($env:JAVA_HOME -and (Test-Path "$env:JAVA_HOME\bin\keytool.exe")) {
        $KeytoolCmd = "$env:JAVA_HOME\bin\keytool.exe"
    } else {
        Write-Error "keytool was not found in PATH or JAVA_HOME. Please ensure Java JDK is installed."
        exit 1
    }
}

# 3. Securely prompt for passwords
Write-Host "Please enter a strong password for your new Keystore:" -ForegroundColor Green
$SecurePass1 = Read-Host -AsSecureString "Enter Keystore Password"
$SecurePass2 = Read-Host -AsSecureString "Confirm Keystore Password"

$BSTR1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass1)
$PlainPass1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR1)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR1)

$BSTR2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass2)
$PlainPass2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR2)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR2)

if ($PlainPass1.Length -lt 8) {
    Write-Error "Password must be at least 8 characters long for security."
    exit 1
}

if ($PlainPass1 -ne $PlainPass2) {
    Write-Error "Passwords do not match. Please run the script again."
    exit 1
}

$KeyAlias = "upload"
$DName = "CN=inRide, OU=Mobile, O=inRide, L=Cairo, ST=Cairo, C=EG"

Write-Host ""
Write-Host "Generating release keystore (RSA 2048-bit, validity 10000 days)..." -ForegroundColor Yellow

# 4. Generate Keystore via keytool
$KeytoolArgs = @(
    "-genkeypair",
    "-v",
    "-keystore", $KeystorePath,
    "-alias", $KeyAlias,
    "-keyalg", "RSA",
    "-keysize", "2048",
    "-validity", "10000",
    "-storepass", $PlainPass1,
    "-keypass", $PlainPass1,
    "-dname", $DName
)

& $KeytoolCmd $KeytoolArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to generate keystore."
    exit 1
}

# 5. Generate local `key.properties`
$KeyPropertiesContent = @"
storeFile=app/upload-keystore.jks
storePassword=$PlainPass1
keyAlias=$KeyAlias
keyPassword=$PlainPass1
"@

Set-Content -Path $KeyPropertiesPath -Value $KeyPropertiesContent -Encoding UTF8

# Clean memory
$PlainPass1 = $null
$PlainPass2 = $null
[System.GC]::Collect()

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "✓ Keystore generated successfully at:" -ForegroundColor Green
Write-Host "  $KeystorePath" -ForegroundColor White
Write-Host "✓ Local configuration saved at:" -ForegroundColor Green
Write-Host "  $KeyPropertiesPath" -ForegroundColor White
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "🔒 IMPORTANT SECURITY STEPS:" -ForegroundColor Yellow
Write-Host "1. Keep a secure offline backup of 'upload-keystore.jks' (e.g. in 1Password / Bitwarden / encrypted USB)."
Write-Host "2. Never commit 'upload-keystore.jks' or 'key.properties' to Git (already in .gitignore)."
Write-Host "3. To use in GitHub Actions, encode your keystore to Base64 with:"
Write-Host "   [Convert]::ToBase64String([IO.File]::ReadAllBytes('$KeystorePath')) | Set-Clipboard" -ForegroundColor Cyan
Write-Host "   and paste into GitHub Secret: 'ANDROID_KEYSTORE_BASE64'"
Write-Host ""
