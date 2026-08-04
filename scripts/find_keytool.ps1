# 查找系统可用的 keytool（用于生成上架签名 keystore）
$ErrorActionPreference = 'SilentlyContinue'

$candidates = @()

# flutter 内置 JDK
$where = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if ($where) {
    $flutterRoot = Split-Path (Split-Path $where)
    $candidates += Get-ChildItem -Path $flutterRoot -Filter keytool.exe -Recurse | Select-Object -ExpandProperty FullName
}

# Android Studio JBR
$candidates += Get-ChildItem 'C:\Program Files\Android' -Filter keytool.exe -Recurse | Select-Object -ExpandProperty FullName

# Java 安装
$candidates += Get-ChildItem 'C:\Program Files\Java', 'C:\Program Files\Eclipse Adoptium', 'C:\Program Files\Microsoft' -Filter keytool.exe -Recurse | Select-Object -ExpandProperty FullName

# JAVA_HOME
if ($env:JAVA_HOME) {
    $candidates += Join-Path $env:JAVA_HOME 'bin\keytool.exe'
}

# PATH
$inPath = Get-Command keytool -ErrorAction SilentlyContinue
if ($inPath) { $candidates += $inPath.Source }

$candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
