# TFLite 动作分类服务 - 研究报告

> 生成日期：2026-07-03
> 项目：fat-battle（Flutter 健身游戏）

---

## 目录

1. [MoveNet Lightning vs Thunder 性能对比](#1-movenet-lightning-vs-thunder-性能对比)
2. [Android 设备推理速度](#2-android-设备推理速度fps)
3. [模型文件大小](#3-模型文件大小)
4. [与 MediaPipe 方案对比](#4-与-mediapipe-方案对比优缺点)
5. [离线可用性](#5-离线可用性)
6. [已知问题和限制](#6-已知问题和限制)
7. [tflite_flutter 兼容性说明](#7-tflite_flutter-兼容性说明)
8. [模型打包方式](#8-模型打包方式)
9. [Android NNAPI / GPU Delegate 配置](#9-android-nnapi--gpu-delegate-配置)

---

## 1. MoveNet Lightning vs Thunder 性能对比

MoveNet 是 Google 推出的单人姿态估计模型，基于 CenterNet 架构，检测人体 **17 个关键点**（COCO 格式）。提供两个版本：

| 维度 | Lightning | Thunder |
|------|-----------|---------|
| 定位 | 速度优先，实时应用 | 精度优先，高质量场景 |
| 输入尺寸 | 192×192×3 (int32) | 256×256×3 (int32) |
| 输出 | [1,1,17,3] float32 | [1,1,17,3] float32 |
| mAP (COCO) | 63.0 (FP16) / 57.4 (INT8) | 72.0 (FP16) / 68.9 (INT8) |
| Pixel 5 CPU 延迟 | 60ms (FP16) / 52ms (INT8) | 155ms (FP16) / 100ms (INT8) |
| Pixel 5 GPU 延迟 | 25ms (FP16) / 28ms (INT8) | 45ms (FP16) / 52ms (INT8) |
| Raspberry Pi 4 CPU | 186ms (FP16) / 95ms (INT8) | 594ms (FP16) / 251ms (INT8) |
| 文件大小 | 4.8MB (FP16) / 2.9MB (INT8) | 12.6MB (FP16) / 7.1MB (INT8) |

**选型建议**：
- **Lightning FP16**（本项目默认）：移动端实时应用首选，约 16 FPS (GPU) / 12 FPS (CPU)，精度够用
- **Thunder FP16**：需要高精度关键点时使用（如瑜伽姿势分类），约 22 FPS (GPU)
- **INT8 量化版**：低端设备优先，最小 2.9MB，但精度下降约 5 个 mAP 点

---

## 2. Android 设备推理速度（FPS）

基于 Google 官方在 Pixel 5 上的基准测试（TensorFlow 2.5+）：

| 模型 | CPU 4线程 | GPU | NNAPI | 理论 FPS (GPU) |
|------|-----------|-----|-------|----------------|
| Lightning FP16 | 60ms (~17 FPS) | 25ms (~40 FPS) | ~30ms (~33 FPS) | 40 |
| Lightning INT8 | 52ms (~19 FPS) | 28ms (~36 FPS) | ~25ms (~40 FPS) | 36 |
| Thunder FP16 | 155ms (~6 FPS) | 45ms (~22 FPS) | ~50ms (~20 FPS) | 22 |
| Thunder INT8 | 100ms (~10 FPS) | 52ms (~19 FPS) | ~40ms (~25 FPS) | 19 |
| PoseNet (旧) | 80ms (~12 FPS) | 40ms (~25 FPS) | - | 25 |

**实际应用中的 FPS 预期**（包含预处理 + 后处理）：
- 中端 Android（骁龙 7 系列）：**Lightning ~15-25 FPS**
- 高端 Android（骁龙 8 系列）：**Lightning ~25-35 FPS**
- 低端 Android：**Lightning ~8-15 FPS**（建议用 INT8 量化版）

本项目设置 `_frameSkip = 2`（每 3 帧处理 1 帧），实际推理频率约 10-15 FPS，足以检测动作周期。

---

## 3. 模型文件大小

| 模型 | 量化格式 | 文件大小 |
|------|----------|----------|
| MoveNet Lightning | FP16 | **4.8 MB** |
| MoveNet Lightning | INT8 | 2.9 MB |
| MoveNet Thunder | FP16 | 12.6 MB |
| MoveNet Thunder | INT8 | 7.1 MB |
| PoseNet (MobileNetV1) | FP32 | 13.3 MB |

本项目默认打包 **Lightning FP16 (4.8MB)**，对 APK 体积影响可控。如果同时打包 Lightning + Thunder，增加约 17MB。

---

## 4. 与 MediaPipe 方案对比（优缺点）

### MoveNet (TFLite)

| 优点 | 缺点 |
|------|------|
| ✅ 纯离线推理，无需网络 | ❌ 仅 17 个关键点（MediaPipe 33 个） |
| ✅ 模型文件小（2.9-12.6MB） | ❌ 单人姿态（多人需 multipose 版本） |
| ✅ tflite_flutter 跨平台 Dart API | ❌ 遮挡鲁棒性不如 BlazePose |
| ✅ 可选 GPU/NNAPI 加速 | ❌ Dart 层预处理（YUV→RGB）有性能开销 |
| ✅ 可自由切换模型版本 | ❌ tflite_flutter 维护活跃度一般 |
| ✅ 无 Google Play Services 依赖 | ❌ 无内置动作分类器，需自行实现 |

### MediaPipe (google_mlkit_pose_detection)

| 优点 | 缺点 |
|------|------|
| ✅ 33 个关键点（BlazePose） | ❌ 依赖 Google Play Services（国内设备受限） |
| ✅ 遮挡鲁棒性强 | ❌ APK 体积增加较大 |
| ✅ ML Kit API 更稳定，Google 官方维护 | ❌ 模型不可替换/定制 |
| ✅ 原生预处理（C++ 层，性能好） | ❌ 无法选择模型版本/精度 |
| ✅ 多人姿态支持 | ❌ 需要联网首次下载模型组件 |

### 选型结论

- **国内市场 / 离线场景 / 可定制** → MoveNet (TFLite)
- **海外市场 / 高精度 / 快速集成** → MediaPipe (ML Kit)
- **本项目策略**：MoveNet 为主（`TfliteMotionService`），ML Kit 备选（`google_mlkit_pose_detection` 已在 pubspec 中声明）

---

## 5. 离线可用性

| 方案 | 离线可用 | 说明 |
|------|----------|------|
| MoveNet (TFLite) | ✅ 完全离线 | 模型打包在 assets 中，推理全在端侧 |
| MediaPipe (ML Kit) | ⚠️ 首次需联网 | 首次使用会下载模型组件到设备，之后可离线 |
| PoseNet (TFLite) | ✅ 完全离线 | 同 MoveNet，但精度更低 |

**本项目 MoveNet 方案完全离线可用**，模型文件通过 `assets/models/` 打包到 APK 中，用户安装后无需任何网络连接。

---

## 6. 已知问题和限制

### tflite_flutter 包

1. **维护状态**：原由 GSoC 实习生开发，社区维护。2026 年最新版本约 0.11.x，对 Flutter 3.44 的兼容性需验证
2. **Flutter 3.44 兼容性风险**：Flutter 3.44 使用 Dart 3.12，tflite_flutter 的 FFI 绑定可能需要更新。如果遇到编译错误，替代方案：
   - 使用 `google_mlkit_pose_detection`（MediaPipe）
   - 或降级 Flutter 版本至 3.41（稳定版）
3. **GPU Delegate**：需要额外引入 `tflite_flutter_gpu` 包，配置较复杂
4. **iOS 兼容性**：iOS 上 Metal delegate 需要额外配置，本项目目前仅优化 Android

### MoveNet 模型

1. **单人姿态**：当前版本仅检测图像中最中心的一个人，多人场景不可靠
2. **侧面视角**：当人体侧面朝向摄像头时，部分关键点被遮挡，置信度下降
3. **快速运动**：帧率过低时（<10 FPS），快速动作（如跳绳）可能漏检
4. **光照影响**：暗光环境下精度下降
5. **输入格式**：float16 版本输入为 int32（像素值 0-255），int8 版本输入为 uint8，需注意匹配

### 预处理性能

- Dart 层 YUV→RGB 转换 + resize 在低端设备上可能成为瓶颈（192×192×3 = 110,592 像素）
- 解决方案：可考虑用 `compute()` 隔离线程处理，或使用 Platform Channel 调用原生预处理

---

## 7. tflite_flutter 兼容性说明

### 当前状态（2026年7月）

- **pub.dev 最新版本**：约 `0.11.0`
- **Flutter 3.44 (Dart 3.12)**：存在潜在兼容性风险，主要因为：
  - tflite_flutter 使用 dart:ffi 调用 native TFLite C API
  - Flutter 3.44 仍处于补丁修复阶段（3.44.3），非生产稳定版
  - 部分 native binding 可能未及时更新

### 替代方案

如果 `tflite_flutter` 在 Flutter 3.44 上编译失败：

1. **方案 A：google_mlkit_pose_detection**（推荐）
   - 已在 pubspec.yaml 中声明
   - Google 官方维护，兼容性好
   - 基于 MediaPipe，33 关键点
   - 缺点：依赖 Google Play Services

2. **方案 B：降级 Flutter**
   - 使用 Flutter 3.41 (Dart 3.11) 稳定版
   - tflite_flutter 0.11.0 在 3.41 上验证可用

3. **方案 C：Platform Channel + 原生 TFLite**
   - Android 端用 Kotlin 直接调用 `org.tensorflow.lite.Interpreter`
   - 性能最优但开发量大

---

## 8. 模型打包方式

### 步骤

1. **下载模型**：运行 `download_models.ps1`
   ```powershell
   powershell -ExecutionPolicy Bypass -File download_models.ps1
   ```

2. **模型文件位置**：
   ```
   assets/
   └── models/
       ├── movenet_lightning.tflite   (4.8 MB)
       └── movenet_thunder.tflite     (12.6 MB)
   ```

3. **pubspec.yaml 声明**（已配置）：
   ```yaml
   flutter:
     assets:
       - assets/models/
   ```

4. **代码中加载**：
   ```dart
   _interpreter = await Interpreter.fromAsset(
     'assets/models/movenet_lightning.tflite',
   );
   ```

### APK 大小影响

| 打包内容 | APK 增量 |
|----------|----------|
| 仅 Lightning FP16 | +4.8 MB |
| Lightning + Thunder | +17.4 MB |
| Lightning INT8 | +2.9 MB |

---

## 9. Android NNAPI / GPU Delegate 配置

### NNAPI（推荐，Android 10+）

```dart
final options = InterpreterOptions();
options.useNnApiForAndroid = true;  // 自动选择 NPU/DSP
_interpreter = await Interpreter.fromAsset(modelPath, options: options);
```

- 优势：自动利用设备 NPU/DSP，无需额外依赖
- 适用：Android 10 (API 29) 及以上
- 模型选择：INT8 量化版在 NNAPI 上表现最佳

### GPU Delegate

```dart
// 需额外引入 tflite_flutter_gpu 包
import 'package:tflite_flutter_gpu/tflite_flutter_gpu.dart';

final gpuDelegate = GpuDelegateV2(
  options: GpuDelegateOptionsV2(
    isPrecisionLossAllowed: true,  // FP16 精度
    inferencePreference: TfLiteGpuInferenceUsage.preferenceSustainSpeed,
  ),
);
final options = InterpreterOptions()..addDelegate(gpuDelegate);
_interpreter = await Interpreter.fromAsset(modelPath, options: options);
```

- 优势：GPU 并行计算，适合 FP16 模型
- 注意：部分 GPU 对 int32 输入支持不佳，需测试兼容性

### 配置建议

| 设备类型 | 推荐配置 | 模型 |
|----------|----------|------|
| 高端 (骁龙8系) | GPU Delegate | Thunder FP16 |
| 中端 (骁龙7系) | NNAPI | Lightning FP16 |
| 低端 (骁龙4系) | CPU 4线程 | Lightning INT8 |
| IoT/嵌入式 | CPU | Lightning INT8 |

本项目 `TfliteMotionService.configure()` 方法支持切换：
```dart
final service = TfliteMotionService();
service.configure(useNnApi: true);  // 启用 NNAPI
await service.initialize();
```

---

## 参考

- [MoveNet 和 TensorFlow Lite 在边缘设备上的姿势估计和分类](https://blog.tensorflowcn.cn/2021/08/pose-estimation-and-classification-on-edge-devices-with-MoveNet-and-TensorFlow-Lite.html)
- [TensorFlow Hub - MoveNet 模型](https://tfhub.dev/s?deployment-format=lite&q=movenet)
- [TensorFlow Examples - Android 姿态估计](https://github.com/tensorflow/examples/tree/master/lite/examples/pose_estimation/android)
- [tflite_flutter pub.dev](https://pub.dev/packages/tflite_flutter)
- [姿势分类教程 (Colab)](https://tensorflowcn.cn/lite/tutorials/pose_classification)
