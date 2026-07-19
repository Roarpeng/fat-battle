# 以 debug 模式在连接的设备上运行 fat-battle 应用
# 使用前请确保：
#   1. 手机已通过 USB 连接并启用 USB 调试
#   2. 已在开发者选项中授予电脑授权
#   3. 执行 `flutter devices` 能看到设备
#
# 用法：在项目根目录执行
#   powershell -ExecutionPolicy Bypass -File scripts\run_debug.ps1

$ErrorActionPreference = "Stop"

Write-Host "=== Fat-Battle Debug 运行脚本 ===" -ForegroundColor Cyan
Write-Host "工作目录: $PSScriptRoot\.." -ForegroundColor Gray

# 切换到项目根目录
Set-Location -Path "$PSScriptRoot\.."

# 显示已连接设备
Write-Host "`n[1/2] 已连接设备:" -ForegroundColor Yellow
flutter devices

# 运行应用
Write-Host "`n[2/2] 启动 debug 模式..." -ForegroundColor Yellow
flutter run --debug `
    --dart-define=BAIDU_API_KEY=tmZ8dTmfodEts6Ufb6q2QURb `
    --dart-define=BAIDU_SECRET_KEY=UlGJoVVmIRJYIt9aOAXml8nnJhQxJpAl
