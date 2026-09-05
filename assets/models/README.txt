# Place MoveNet tflite model files here (gitignored; do not commit binaries).
#
# Linux / macOS:
#   chmod +x download_models.sh && ./download_models.sh
# Windows:
#   powershell -ExecutionPolicy Bypass -File download_models.ps1
#
# Required files:
#   movenet_lightning.tflite  (4.8 MB, default - 192x192 input)
#   movenet_thunder.tflite    (12.6 MB, optional - 256x256 input)
#
# App: 锻炼页 → 高级选项 → TFLite 离线。GPU 开关失败会自动 CPU。
