# 构建 fat-battle 的 release APK
# 输出位置：build\app\outputs\flutter-apk\app-release.apk
#
# 用法：在项目根目录执行
#   powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1

$ErrorActionPreference = "Stop"

Write-Host "=== Fat-Battle APK 构建脚本 ===" -ForegroundColor Cyan
Write-Host "工作目录: $PSScriptRoot\.." -ForegroundColor Gray

# 切换到项目根目录
Set-Location -Path "$PSScriptRoot\.."

# 构建 release APK
Write-Host "`n开始构建 release APK..." -ForegroundColor Yellow
flutter build apk --release `
    --dart-define=BAIDU_API_KEY=tmZ8dTmfodEts6Ufb6q2QURb `
    --dart-define=BAIDU_SECRET_KEY=UlGJoVVmIRJYIt9aOAXml8nnJhQxJpAl

if ($LASTEXITCODE -eq 0) {
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    Write-Host "`n[成功] APK 构建完成!" -ForegroundColor Green
    Write-Host "APK 路径: $apkPath" -ForegroundColor Green
    if (Test-Path $apkPath) {
        $size = (Get-Item $apkPath).Length / 1MB
        Write-Host ("文件大小: {0:N2} MB" -f $size) -ForegroundColor Green
    }
} else {
    Write-Host "`n[失败] APK 构建失败，请查看上方错误信息" -ForegroundColor Red
    exit $LASTEXITCODE
}
