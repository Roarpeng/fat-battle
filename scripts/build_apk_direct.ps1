# App 直连打包：从 web/.env 读取密钥，经 --dart-define 注入，不依赖本机后端
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root 'web\.env'
if (-not (Test-Path $envFile)) { throw "缺少 $envFile" }

$vars = @{}
Get-Content $envFile | ForEach-Object {
  if ($_ -match '^\s*([A-Z0-9_]+)=(.*)$') {
    $vars[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'")
  }
}

foreach ($k in @('ZHIPU_API_KEY', 'BAIDU_API_KEY', 'BAIDU_SECRET_KEY')) {
  if (-not $vars[$k]) { throw "web/.env 缺少 $k" }
}

Set-Location $root
$env:Path = "C:\Users\roarp\AppData\Local\Android\sdk\platform-tools;$env:Path"

$defines = @(
  "--dart-define=ZHIPU_API_KEY=$($vars['ZHIPU_API_KEY'])",
  "--dart-define=BAIDU_API_KEY=$($vars['BAIDU_API_KEY'])",
  "--dart-define=BAIDU_SECRET_KEY=$($vars['BAIDU_SECRET_KEY'])"
)

Write-Host "Building release APK (direct API, no backend proxy)..."
flutter build apk --release @defines
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$device = (flutter devices --machine | ConvertFrom-Json | Where-Object { $_.targetPlatform -like 'android*' } | Select-Object -First 1).id
if (-not $device) {
  Write-Host "APK 已生成: build\app\outputs\flutter-apk\app-release.apk （未检测到 Android 设备）"
  exit 0
}

Write-Host "Installing to $device ..."
flutter install --release -d $device
