import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'tflite_accel.dart';

export 'tflite_accel.dart';

/// 给 [InterpreterOptions] 挂加速 delegate。失败则保持 CPU。
class TfliteGpuHook {
  TfliteGpuHook._();

  static const prefsGpuKey = TfliteAccelPrefs.gpuKey;
  static const prefsEngineKey = TfliteAccelPrefs.engineKey;

  /// 尝试挂 GPU（及可选 NNAPI）。任一步失败都写明原因并继续。
  static TfliteAccelResult attach(
    InterpreterOptions options, {
    bool preferGpu = false,
    bool preferNnApi = false,
  }) {
    var gpuAttached = false;
    var nnapiAttached = false;
    String? reason;

    if (preferNnApi && !kIsWeb && Platform.isAndroid) {
      try {
        options.useNnApiForAndroid = true;
        nnapiAttached = true;
      } catch (e) {
        reason = 'NNAPI 不可用: $e';
        debugPrint('TfliteGpuHook NNAPI: $e');
      }
    }

    if (preferGpu && !kIsWeb) {
      final gpu = tryCreateGpuDelegate();
      if (gpu != null) {
        try {
          options.addDelegate(gpu);
          gpuAttached = true;
        } catch (e) {
          reason = 'GPU delegate 挂载失败，已回退 CPU: $e';
          debugPrint('TfliteGpuHook addDelegate: $e');
          // delegate 已失败，交给 GC / Interpreter 析构
        }
      } else {
        reason = '当前设备/运行时没有可用的 GPU delegate，已用 CPU';
      }
    }

    final backend = gpuAttached ? 'gpu' : (nnapiAttached ? 'nnapi' : 'cpu');
    return TfliteAccelResult(
      gpuRequested: preferGpu,
      gpuAttached: gpuAttached,
      nnapiAttached: nnapiAttached,
      backend: backend,
      fallbackReason: gpuAttached ? null : reason,
    );
  }

  /// 创建平台 GPU delegate；失败返回 null（不抛）。
  static Delegate? tryCreateGpuDelegate() {
    try {
      if (kIsWeb) return null;
      if (Platform.isAndroid) {
        return GpuDelegateV2(
          options: GpuDelegateOptionsV2(
            isPrecisionLossAllowed: true,
          ),
        );
      }
      if (Platform.isIOS) {
        return GpuDelegate(
          options: GpuDelegateOptions(
            allowPrecisionLoss: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('TfliteGpuHook create: $e');
    }
    return null;
  }
}
