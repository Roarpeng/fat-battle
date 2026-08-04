# Verify release APK signing certificate
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$apk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
$bt = Get-ChildItem "$env:LOCALAPPDATA\Android\sdk\build-tools" -Directory |
    Sort-Object Name -Descending | Select-Object -First 1
$signer = Join-Path $bt.FullName 'apksigner.bat'
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
& $signer verify --print-certs $apk
