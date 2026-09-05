/// TFLite 加速后端结果（纯 Dart，不链原生库）。
class TfliteAccelResult {
  final bool gpuRequested;
  final bool gpuAttached;
  final bool nnapiAttached;
  final String backend;
  final String? fallbackReason;

  const TfliteAccelResult({
    required this.gpuRequested,
    required this.gpuAttached,
    required this.nnapiAttached,
    required this.backend,
    this.fallbackReason,
  });

  String get label {
    switch (backend) {
      case 'gpu':
        return 'GPU';
      case 'nnapi':
        return 'NNAPI';
      default:
        return 'CPU';
    }
  }
}

class TfliteAccelPrefs {
  static const gpuKey = 'coach_tflite_prefer_gpu';
  static const engineKey = 'coach_camera_engine';
}
