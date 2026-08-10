# Build fat-battle release APK (backend proxy mode).
# App only gets API_BASE_URL. Baidu/Zhipu keys stay on the server.
# Output: build\app\outputs\flutter-apk\app-release.apk
#
# Usage (from repo root):
#   powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1 -ApiBaseUrl "http://111.229.178.88:8080"

param(
    [string]$ApiBaseUrl = $env:API_BASE_URL
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    $ApiBaseUrl = "http://111.229.178.88:8080"
}

$ApiBaseUrl = $ApiBaseUrl.Trim().TrimEnd('/')
if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    Write-Host "[FAIL] API_BASE_URL is empty. Food recognition requires backend URL." -ForegroundColor Red
    exit 1
}

Write-Host "=== Fat-Battle APK build (backend proxy) ===" -ForegroundColor Cyan
Write-Host "Workdir: $PSScriptRoot\.." -ForegroundColor Gray
Write-Host "API_BASE_URL: $ApiBaseUrl" -ForegroundColor Gray
Write-Host "Note: APK has NO Baidu/Zhipu keys; server does recognition." -ForegroundColor Gray

Set-Location -Path "$PSScriptRoot\.."

Write-Host ""
Write-Host "Building release APK..." -ForegroundColor Yellow
flutter build apk --release --dart-define=API_BASE_URL=$ApiBaseUrl

if ($LASTEXITCODE -eq 0) {
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    Write-Host ""
    Write-Host "[OK] APK built." -ForegroundColor Green
    Write-Host "APK: $apkPath" -ForegroundColor Green
    if (Test-Path $apkPath) {
        $size = (Get-Item $apkPath).Length / 1MB
        Write-Host ("Size: {0:N2} MB" -f $size) -ForegroundColor Green
    }
} else {
    Write-Host ""
    Write-Host "[FAIL] APK build failed." -ForegroundColor Red
    exit $LASTEXITCODE
}