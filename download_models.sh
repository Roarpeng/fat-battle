#!/usr/bin/env bash
# MoveNet tflite 下载（Linux / macOS）。Windows 用 download_models.ps1。
# 用法：./download_models.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="$ROOT/assets/models"
mkdir -p "$DEST"

download() {
  local name="$1"
  local file="$2"
  shift 2
  local dest="$DEST/$file"
  if [[ -f "$dest" ]] && [[ "$(wc -c < "$dest")" -gt 100000 ]]; then
    echo "[skip] $file already present"
    return 0
  fi
  echo "=== $name ==="
  for url in "$@"; do
    echo "  trying $url"
    if curl -fsSL --connect-timeout 20 -o "$dest" "$url"; then
      if [[ "$(wc -c < "$dest")" -gt 100000 ]]; then
        echo "  OK $file"
        return 0
      fi
      rm -f "$dest"
    fi
  done
  echo "  [MANUAL] open https://tfhub.dev/google/movenet/singlepose/lightning/tflite/float16/1"
  echo "  save as $dest"
  return 1
}

download "MoveNet Lightning (float16)" "movenet_lightning.tflite" \
  "https://storage.googleapis.com/tfhub-lite-models/google/movenet/singlepose/lightning/tflite/float16/1.tflite" \
  "https://tfhub.dev/google/movenet/singlepose/lightning/tflite/float16/1?lite-format=tflite" || true

download "MoveNet Thunder (float16)" "movenet_thunder.tflite" \
  "https://storage.googleapis.com/tfhub-lite-models/google/movenet/singlepose/thunder/tflite/float16/1.tflite" \
  "https://tfhub.dev/google/movenet/singlepose/thunder/tflite/float16/1?lite-format=tflite" || true

echo
echo "Models live in $DEST and are gitignored. Lightning is the default asset."
echo "Then: flutter pub get && reopen the app, switch 高级选项 → TFLite 离线."
