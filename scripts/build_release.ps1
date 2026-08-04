# Release build for store publishing (Google Play).
# Backend mode: APK/AAB contains NO LLM keys; all AI calls go through the backend proxy.
#
# Usage:
#   .\scripts\build_release.ps1 -ApiBaseUrl "https://your-domain.com"            # AAB (Google Play)
#   .\scripts\build_release.ps1 -ApiBaseUrl "https://your-domain.com" -Apk       # APK
#
# Prereq: run scripts\setup_signing.ps1 once (release keystore + key.properties)
param(
    [Parameter(Mandatory = $true)][string]$ApiBaseUrl,
    [switch]$Apk
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# sanity checks
if (-not $ApiBaseUrl.StartsWith('https://')) {
    Write-Warning "API_BASE_URL is not https. Android blocks cleartext HTTP by default; stores require TLS."
}
if (-not (Test-Path (Join-Path $root 'android\key.properties'))) {
    Write-Host "No key.properties found - generating release signing..."
    powershell -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\setup_signing.ps1')
}

$defines = @("--dart-define=API_BASE_URL=$ApiBaseUrl")

if ($Apk) {
    Write-Host "Building signed release APK (backend mode, no embedded keys)..."
    flutter build apk --release @defines
} else {
    Write-Host "Building signed release App Bundle for Google Play (backend mode)..."
    flutter build appbundle --release @defines
}
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($Apk) {
    Write-Host "APK: build\app\outputs\flutter-apk\app-release.apk"
} else {
    Write-Host "AAB: build\app\outputs\bundle\release\app-release.aab"
}
