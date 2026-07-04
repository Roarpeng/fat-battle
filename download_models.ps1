# download_models.ps1
# MoveNet tflite model download script (Windows PowerShell)
# Usage: powershell -ExecutionPolicy Bypass -File download_models.ps1
#
# If automated download fails (403 error), follow the manual instructions below.

$ErrorActionPreference = "Stop"
$modelsDir = Join-Path $PSScriptRoot "assets\models"

# Create model directory
if (-not (Test-Path $modelsDir)) {
    New-Item -ItemType Directory -Path $modelsDir -Force | Out-Null
    Write-Host "Created directory: $modelsDir" -ForegroundColor Green
}

# Helper: format file size
function Format-FileSize($bytes) {
    $mb = $bytes / 1048576.0
    return "{0:N1} MB" -f $mb
}

# Model download list - try multiple sources
# Source 1: Google Cloud Storage (tfhub-lite-models bucket)
# Source 2: TensorFlow Hub resolve URL
$models = @(
    @{
        Name = "MoveNet Lightning (float16)"
        File = "movenet_lightning.tflite"
        Urls = @(
            "https://storage.googleapis.com/tfhub-lite-models/google/movenet/singlepose/lightning/tflite/float16/1.tflite",
            "https://tfhub.dev/google/movenet/singlepose/lightning/tflite/float16/1?lite-format=tflite"
        )
        ManualUrl = "https://tfhub.dev/google/movenet/singlepose/lightning/tflite/float16/1"
    },
    @{
        Name = "MoveNet Thunder (float16)"
        File = "movenet_thunder.tflite"
        Urls = @(
            "https://storage.googleapis.com/tfhub-lite-models/google/movenet/singlepose/thunder/tflite/float16/1.tflite",
            "https://tfhub.dev/google/movenet/singlepose/thunder/tflite/float16/1?lite-format=tflite"
        )
        ManualUrl = "https://tfhub.dev/google/movenet/singlepose/thunder/tflite/float16/1"
    }
)

$anySuccess = $false

foreach ($model in $models) {
    $destPath = Join-Path $modelsDir $model.File

    Write-Host ""
    Write-Host "=== $($model.Name) ===" -ForegroundColor Cyan

    # Skip if already exists
    if (Test-Path $destPath) {
        $size = (Get-Item $destPath).Length
        if ($size -gt 100000) {
            $sizeStr = Format-FileSize $size
            Write-Host "  File exists ($sizeStr), skipping" -ForegroundColor Yellow
            $anySuccess = $true
            continue
        }
    }

    $downloaded = $false
    foreach ($url in $model.Urls) {
        Write-Host "  Trying: $url"
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $url -OutFile $destPath -UseBasicParsing -TimeoutSec 30
            $ProgressPreference = 'Continue'

            $size = (Get-Item $destPath).Length
            if ($size -gt 100000) {
                $sizeStr = Format-FileSize $size
                Write-Host "  OK! Size: $sizeStr" -ForegroundColor Green
                $downloaded = $true
                $anySuccess = $true
                break
            } else {
                Write-Host "  Got only $size bytes (HTML page?), trying next..." -ForegroundColor Yellow
                Remove-Item $destPath -Force -ErrorAction SilentlyContinue
            }
        } catch {
            $errMsg = $_.Exception.Message
            Write-Host "  Failed: $errMsg" -ForegroundColor Red
            Remove-Item $destPath -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not $downloaded) {
        Write-Host ""
        Write-Host "  [MANUAL DOWNLOAD REQUIRED]" -ForegroundColor Yellow
        Write-Host "  Automated download failed. Please download manually:" -ForegroundColor White
        Write-Host "  1. Open in browser: $($model.ManualUrl)" -ForegroundColor White
        Write-Host "  2. Click 'Download' to get the .tflite file" -ForegroundColor White
        Write-Host "  3. Rename to: $($model.File)" -ForegroundColor White
        Write-Host "  4. Place in: $modelsDir\" -ForegroundColor White
        Write-Host ""
        Write-Host "  Or use Python:" -ForegroundColor White
        Write-Host "    pip install tensorflow_hub" -ForegroundColor White
        Write-Host "    python -c `"import tensorflow_hub as hub; hub.load('$($model.ManualUrl)')`"" -ForegroundColor White
    }
}

# Verify
Write-Host ""
Write-Host "=== Model Files ===" -ForegroundColor Cyan
$lightning = Join-Path $modelsDir "movenet_lightning.tflite"
$thunder   = Join-Path $modelsDir "movenet_thunder.tflite"

if (Test-Path $lightning) {
    $size = (Get-Item $lightning).Length
    if ($size -gt 100000) {
        $sizeStr = Format-FileSize $size
        Write-Host "  [OK] movenet_lightning.tflite  ($sizeStr)" -ForegroundColor Green
    } else {
        Write-Host "  [INVALID] movenet_lightning.tflite (too small, delete and re-download)" -ForegroundColor Red
    }
} else {
    Write-Host "  [MISSING] movenet_lightning.tflite" -ForegroundColor Red
}

if (Test-Path $thunder) {
    $size = (Get-Item $thunder).Length
    if ($size -gt 100000) {
        $sizeStr = Format-FileSize $size
        Write-Host "  [OK] movenet_thunder.tflite    ($sizeStr)" -ForegroundColor Green
    } else {
        Write-Host "  [INVALID] movenet_thunder.tflite (too small, delete and re-download)" -ForegroundColor Red
    }
} else {
    Write-Host "  [MISSING] movenet_thunder.tflite" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Notes ===" -ForegroundColor Cyan
Write-Host "  - Default model: movenet_lightning.tflite (192x192 input)"
Write-Host "  - To use Thunder: edit tflite_motion_service.dart:"
Write-Host "      kInputSize = 256"
Write-Host "      kModelAsset = 'assets/models/movenet_thunder.tflite'"
Write-Host ""
Write-Host "  - Alternative: download via Python tensorflow_hub"
Write-Host "  - TensorFlow Hub: https://tfhub.dev/s?deployment-format=lite"
Write-Host "  - Kaggle: https://www.kaggle.com/models/google/movenet"
Write-Host ""
