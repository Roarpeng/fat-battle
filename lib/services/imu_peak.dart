/// IMU 峰值计数：滑动三点峰 + 不应期，避免走路/抖动被单样本阈值误计。
class ImuPeakCounter {
  ImuPeakCounter({
    required this.peakThreshold,
    this.refractory = const Duration(milliseconds: 1200),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final double peakThreshold;
  final Duration refractory;
  final DateTime Function() _now;

  double _a = 0;
  double _b = 0;
  double _c = 0;
  int _n = 0;
  DateTime? lastPeakAt;
  int count = 0;

  /// 喂入一个标量（加速度幅值或轴向加速度绝对值）。
  /// 返回 true 表示确认一次新峰值（过不应期）。
  bool ingest(double magnitude) {
    _a = _b;
    _b = _c;
    _c = magnitude;
    _n++;
    if (_n < 3) return false;

    final isPeak = _b > _a && _b >= _c && _b >= peakThreshold;
    if (!isPeak) return false;

    final now = _now();
    final last = lastPeakAt;
    if (last != null && now.difference(last) < refractory) {
      return false;
    }
    lastPeakAt = now;
    count++;
    return true;
  }

  void reset() {
    _a = 0;
    _b = 0;
    _c = 0;
    _n = 0;
    lastPeakAt = null;
    count = 0;
  }
}

/// 按动作给出峰值阈值与不应期（腰部 IMU，加速度约以 g 计）。
class ImuExercisePeaks {
  static ImuPeakCounter forType(
    String exerciseType, {
    DateTime Function()? now,
  }) {
    switch (exerciseType) {
      case 'pushup':
        return ImuPeakCounter(
          peakThreshold: 1.55,
          refractory: const Duration(milliseconds: 1200),
          now: now,
        );
      case 'squat':
        return ImuPeakCounter(
          peakThreshold: 1.65,
          refractory: const Duration(milliseconds: 1200),
          now: now,
        );
      case 'jumping_jack':
        return ImuPeakCounter(
          peakThreshold: 2.2,
          refractory: const Duration(milliseconds: 1000),
          now: now,
        );
      case 'running':
        return ImuPeakCounter(
          peakThreshold: 2.15,
          refractory: const Duration(milliseconds: 1000),
          now: now,
        );
      case 'walking':
        return ImuPeakCounter(
          peakThreshold: 1.7,
          refractory: const Duration(milliseconds: 1500),
          now: now,
        );
      default:
        return ImuPeakCounter(
          peakThreshold: 1.8,
          refractory: const Duration(milliseconds: 1200),
          now: now,
        );
    }
  }
}
