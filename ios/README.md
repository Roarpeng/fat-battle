# iOS 脚手架

本目录提供 `flutter build ios --no-codesign` 所需的权限与工程入口，**不包含** Apple 签名证书。

## 权限

`Runner/Info.plist` 已声明：

- 摄像头 / 麦克风（系统相机组件可能要麦，应用默认不录音）
- 蓝牙 Always + Peripheral（`flutter_blue_plus` / 腰部 Hub）
- 相册读写（精彩瞬间）
- 使用期间定位（城市菜系 + 旧系统 BLE）

`Podfile` 打开 `permission_handler` 的 `PERMISSION_CAMERA` / `MICROPHONE` / `BLUETOOTH` / `PHOTOS` / `LOCATION`。

## 首次在 Mac 上补齐 Xcode 工程

若本机还没有完整 `Runner.xcodeproj`（或 Flutter 升级后工程过期）：

```bash
flutter create --platforms=ios .
cd ios && pod install
flutter build ios --no-codesign
```

`flutter create` 会保留已有 Info.plist / Podfile / AppDelegate。不要提交密钥或 provisioning profile。

## Dart 侧

- `google_mlkit_pose_detection` 与 `camera` 在 iOS 可用。
- Android 专用 JPEG MethodChannel（`fat_battle/mlkit_frame`）只在 `Platform.isAndroid` 走，iOS 用 ML Kit 自带输入。
- `camera_android` 是 Android 实现包，不会链到 iOS。
- TFLite MoveNet 在 iOS 可走 Metal `GpuDelegate`；失败回退 CPU。
