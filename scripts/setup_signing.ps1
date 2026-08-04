# One-time release signing setup: generate keystore + android/key.properties
# Random password is written to key.properties (gitignored). Back it up safely!
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$keytool = 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
$keystorePath = Join-Path $root 'android\app\fatbattle-release.keystore'
$keyProps = Join-Path $root 'android\key.properties'

if (Test-Path $keystorePath) {
    Write-Host "Keystore already exists, skip: $keystorePath"
} else {
    # random 20-char alphanumeric password
    $pass = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 20 | ForEach-Object { [char]$_ })

    & $keytool -genkeypair -v `
        -keystore $keystorePath `
        -storetype PKCS12 `
        -alias fatbattle `
        -keyalg RSA -keysize 2048 -validity 10950 `
        -storepass $pass -keypass $pass `
        -dname "CN=FatBattle, OU=Mobile, O=FatBattle, L=Hangzhou, C=CN"
    if ($LASTEXITCODE -ne 0) { throw "keytool failed" }

    # write key.properties (excluded by android/.gitignore)
    @"
storePassword=$pass
keyPassword=$pass
keyAlias=fatbattle
storeFile=fatbattle-release.keystore
"@ | Set-Content -Path $keyProps -Encoding ascii

    Write-Host ""
    Write-Host "=============================================="
    Write-Host "Keystore created: $keystorePath"
    Write-Host "Signing config written: $keyProps"
    Write-Host "BACK UP both files! Losing them blocks future updates."
    Write-Host "=============================================="
}
