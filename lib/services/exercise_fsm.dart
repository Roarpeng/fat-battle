import 'dart:math' as math;

/// 纯 Dart 动作状态机（无摄像头 / ML Kit），供端侧计次与单测使用。
///
/// 阶段：idle/setup → eccentric → bottom（必须达到 ROM）→ concentric → lock。
/// 浅蹲/浅撑只给口令、不计次。站姿基线来自校准，而不是全局固定阈值。

enum RepPhase { idle, setup, eccentric, bottom, concentric, lock }

class LandmarkPoint {
  final double x;
  final double y;
  final double z;
  const LandmarkPoint(this.x, this.y, [this.z = 0]);
}

class FsmTick {
  final RepPhase phase;
  final bool counted;
  final bool shallow;
  final String? cue;
  final String? feedback;
  final String exerciseName;
  final bool highlight;
  final double? minKneeAngle;
  final double? qualityAngle;
  final double? qualityDepth;
  final double? qualityBodyLine;
  final double motionLevel;

  const FsmTick({
    required this.phase,
    required this.exerciseName,
    this.counted = false,
    this.shallow = false,
    this.cue,
    this.feedback,
    this.highlight = false,
    this.minKneeAngle,
    this.qualityAngle,
    this.qualityDepth,
    this.qualityBodyLine,
    this.motionLevel = 0,
  });
}

class PoseCalibration {
  double standingKneeAngle = 170;
  double standingHipY = 0.45;
  double standingElbowAngle = 165;
  double standingShoulderY = 0.40;
  int samples = 0;
  bool committed = false;

  bool get isReady => samples >= 8;
}

/// 深蹲 / 俯卧撑 / 弓步蹲有限状态机。
class ExerciseRepFsm {
  ExerciseRepFsm({
    required this.exerciseType,
    DateTime Function()? now,
    this.minRepMs = 500,
  }) : _now = now ?? DateTime.now;

  final String exerciseType;
  final DateTime Function() _now;
  final int minRepMs;

  final PoseCalibration calibration = PoseCalibration();
  RepPhase phase = RepPhase.idle;

  double _prevAngle = 180;
  double _repMinAngle = 180;
  double _repMaxHipY = 0;
  double _repMinShoulderY = 999;
  double _repBodyLine = 1;
  DateTime? _lastRepAt;

  static ExerciseRepFsm? forType(
    String exerciseType, {
    DateTime Function()? now,
  }) {
    switch (exerciseType) {
      case 'squat':
      case 'pushup':
      case 'lunge':
        return ExerciseRepFsm(exerciseType: exerciseType, now: now);
      default:
        return null;
    }
  }

  String get exerciseName {
    switch (exerciseType) {
      case 'pushup':
        return '俯卧撑';
      case 'lunge':
        return '弓步蹲';
      default:
        return '深蹲';
    }
  }

  void reset() {
    phase = RepPhase.idle;
    calibration.samples = 0;
    calibration.committed = false;
    _prevAngle = 180;
    _repMinAngle = 180;
    _repMaxHipY = 0;
    _repMinShoulderY = 999;
    _repBodyLine = 1;
    _lastRepAt = null;
  }

  /// 站姿采样：入镜/倒计时期间调用，捕获髋/膝（或肘）基线。
  void ingestCalibration(Map<String, LandmarkPoint> lm) {
    if (calibration.committed) return;
    final m = _metrics(lm);
    if (m == null) return;
    if (exerciseType == 'pushup') {
      if (m.elbowAngle < 145) return;
      _blendCal(
        elbow: m.elbowAngle,
        shoulderY: m.shoulderY,
        hipY: m.hipY,
        knee: m.kneeAngle,
      );
    } else {
      if (m.kneeAngle < 150) return;
      _blendCal(
        elbow: m.elbowAngle,
        shoulderY: m.shoulderY,
        hipY: m.hipY,
        knee: m.kneeAngle,
      );
    }
  }

  void commitCalibration() {
    if (calibration.samples < 3) {
      // 样本不足时保留默认站姿阈值，仍允许开练
      calibration.committed = true;
      return;
    }
    calibration.committed = true;
  }

  FsmTick tick(Map<String, LandmarkPoint> lm, {double sensitivity = 0.7}) {
    final m = _metrics(lm);
    if (m == null) {
      return FsmTick(
        phase: phase,
        exerciseName: exerciseName,
        cue: _outOfFrameCue(),
      );
    }

    if (!calibration.committed) {
      ingestCalibration(lm);
      _prevAngle = m.primaryAngle;
      phase = RepPhase.setup;
      return FsmTick(
        phase: phase,
        exerciseName: exerciseName,
        motionLevel: m.motion,
      );
    }

    final rom = _romThreshold(sensitivity);
    final lockAngle = _lockThreshold();
    final enterDrop = 12.0 + (1.0 - sensitivity) * 8.0;
    final angle = m.primaryAngle;
    final descending = angle < _prevAngle - 1.5;
    final ascending = angle > _prevAngle + 1.5;

    if (angle < _repMinAngle) _repMinAngle = angle;
    if (m.hipY > _repMaxHipY) _repMaxHipY = m.hipY;
    if (m.shoulderY < _repMinShoulderY) _repMinShoulderY = m.shoulderY;
    _repBodyLine = m.bodyLine;

    String? liveCue;
    if (exerciseType == 'pushup' && m.bodyLine < 0.45 && phase != RepPhase.idle) {
      liveCue = '腰往下塌了，收紧核心把髋抬平';
    }

    FsmTick result;
    switch (phase) {
      case RepPhase.idle:
      case RepPhase.setup:
      case RepPhase.lock:
        _resetRepExtrema(m);
        if (angle < _standingPrimary() - enterDrop) {
          phase = RepPhase.eccentric;
        } else {
          phase = RepPhase.setup;
        }
        result = FsmTick(
          phase: phase,
          exerciseName: exerciseName,
          cue: liveCue,
          motionLevel: m.motion,
          minKneeAngle: m.kneeAngle,
        );
      case RepPhase.eccentric:
        if (_romMet(m, rom)) {
          phase = RepPhase.bottom;
          result = FsmTick(
            phase: phase,
            exerciseName: exerciseName,
            cue: liveCue,
            motionLevel: m.motion,
            minKneeAngle: _repMinAngle,
          );
        } else if (ascending && angle > lockAngle - 25) {
          // 未达 ROM 就站起来：口令、不计次
          phase = RepPhase.setup;
          result = FsmTick(
            phase: phase,
            exerciseName: exerciseName,
            shallow: true,
            cue: _shallowCue(),
            motionLevel: m.motion,
            minKneeAngle: _repMinAngle,
          );
        } else {
          result = FsmTick(
            phase: phase,
            exerciseName: exerciseName,
            cue: liveCue,
            motionLevel: m.motion,
            minKneeAngle: _repMinAngle,
          );
        }
      case RepPhase.bottom:
        if (ascending && angle > rom + 8) {
          phase = RepPhase.concentric;
        }
        result = FsmTick(
          phase: phase,
          exerciseName: exerciseName,
          cue: liveCue,
          motionLevel: m.motion,
          minKneeAngle: _repMinAngle,
        );
      case RepPhase.concentric:
        if (_romMet(m, rom) && descending) {
          phase = RepPhase.bottom;
          result = FsmTick(
            phase: phase,
            exerciseName: exerciseName,
            motionLevel: m.motion,
            minKneeAngle: _repMinAngle,
          );
        } else if (angle >= lockAngle) {
          final counted = _debounceOk();
          phase = RepPhase.lock;
          if (counted) {
            _lastRepAt = _now();
            result = _countTick(m, liveCue);
          } else {
            result = FsmTick(
              phase: phase,
              exerciseName: exerciseName,
              motionLevel: m.motion,
              minKneeAngle: _repMinAngle,
            );
          }
        } else {
          result = FsmTick(
            phase: phase,
            exerciseName: exerciseName,
            cue: liveCue,
            motionLevel: m.motion,
            minKneeAngle: _repMinAngle,
          );
        }
    }

    _prevAngle = angle;
    if (phase == RepPhase.lock) {
      phase = RepPhase.setup;
    }
    return result;
  }

  FsmTick _countTick(_PoseMetrics m, String? liveCue) {
    final q = _quality(m);
    final gradeHint = q.grade;
    final highlight = gradeHint == 'S' || gradeHint == 'A';
    final nCue = liveCue;
    return FsmTick(
      phase: RepPhase.lock,
      exerciseName: exerciseName,
      counted: true,
      feedback: _countFeedback(q.grade),
      cue: nCue,
      highlight: highlight,
      minKneeAngle: _repMinAngle,
      qualityAngle: q.angle,
      qualityDepth: q.depth,
      qualityBodyLine: q.bodyLine,
      motionLevel: m.motion,
    );
  }

  void _blendCal({
    required double elbow,
    required double shoulderY,
    required double hipY,
    required double knee,
  }) {
    final n = calibration.samples;
    calibration.standingKneeAngle = _ema(calibration.standingKneeAngle, knee, n);
    calibration.standingHipY = _ema(calibration.standingHipY, hipY, n);
    calibration.standingElbowAngle =
        _ema(calibration.standingElbowAngle, elbow, n);
    calibration.standingShoulderY =
        _ema(calibration.standingShoulderY, shoulderY, n);
    calibration.samples = n + 1;
  }

  double _ema(double prev, double next, int n) {
    if (n <= 0) return next;
    return (prev * n + next) / (n + 1);
  }

  void _resetRepExtrema(_PoseMetrics m) {
    _repMinAngle = m.primaryAngle;
    _repMaxHipY = m.hipY;
    _repMinShoulderY = m.shoulderY;
    _repBodyLine = m.bodyLine;
  }

  double _standingPrimary() =>
      exerciseType == 'pushup' ? calibration.standingElbowAngle : calibration.standingKneeAngle;

  double _romThreshold(double sensitivity) {
    final drop = 55.0 + (1.0 - sensitivity) * 20.0;
    final fromStand = _standingPrimary() - drop;
    if (exerciseType == 'pushup') {
      return fromStand.clamp(85.0, 120.0);
    }
    if (exerciseType == 'lunge') {
      return fromStand.clamp(90.0, 125.0);
    }
    return fromStand.clamp(90.0, 120.0);
  }

  double _lockThreshold() {
    return (_standingPrimary() - 18).clamp(145.0, 175.0);
  }

  bool _romMet(_PoseMetrics m, double rom) {
    if (m.primaryAngle > rom) return false;
    if (exerciseType == 'pushup') {
      final drop = calibration.standingShoulderY - _repMinShoulderY;
      final ratio = calibration.standingShoulderY > 0.05
          ? drop / calibration.standingShoulderY
          : 0.0;
      return ratio > 0.06 || m.primaryAngle < rom - 4;
    }
    final hipDrop = _repMaxHipY - calibration.standingHipY;
    final ratio = calibration.standingHipY.abs() > 0.05
        ? hipDrop / calibration.standingHipY.abs()
        : hipDrop;
    if (exerciseType == 'lunge') {
      return m.kneeDiff > 22 && (m.primaryAngle <= rom || ratio > 0.08);
    }
    return ratio > 0.12 || m.primaryAngle < rom - 5;
  }

  bool _debounceOk() {
    final last = _lastRepAt;
    if (last == null) return true;
    return _now().difference(last).inMilliseconds >= minRepMs;
  }

  String _outOfFrameCue() {
    if (exerciseType == 'pushup') {
      return '请确保上半身入镜，正对或侧对手机';
    }
    return '请正对手机，全身入镜';
  }

  String _shallowCue() {
    switch (exerciseType) {
      case 'pushup':
        return '幅度不够，再往下压一点';
      case 'lunge':
        return '弓步再低一点，前膝大约九十度';
      default:
        return '幅度不够哦，再蹲低一点~';
    }
  }

  String _countFeedback(String grade) {
    switch (grade) {
      case 'S':
        return '标准动作，完美！';
      case 'A':
        return '不错，继续保持';
      case 'B':
        return '可以再深一点';
      default:
        return '幅度有点浅哦';
    }
  }

  _QualityParts _quality(_PoseMetrics m) {
    final minA = _repMinAngle;
    final angleNorm = minA <= 90
        ? 1.0
        : (1.0 - ((minA - 90) / 50.0)).clamp(0.0, 1.0);
    double depth;
    if (exerciseType == 'pushup') {
      final drop = calibration.standingShoulderY - _repMinShoulderY;
      depth = (drop / 0.12).clamp(0.0, 1.0);
    } else {
      final hipDrop = _repMaxHipY - calibration.standingHipY;
      depth = (hipDrop / (calibration.standingHipY.abs() * 0.28 + 0.04))
          .clamp(0.0, 1.0);
    }
    final body = _repBodyLine.clamp(0.0, 1.0);
    final score = angleNorm * 40 + depth * 30 + body * 30;
    String grade;
    if (score > 90) {
      grade = 'S';
    } else if (score > 75) {
      grade = 'A';
    } else if (score > 60) {
      grade = 'B';
    } else if (score > 45) {
      grade = 'C';
    } else {
      grade = 'D';
    }
    return _QualityParts(
      angle: angleNorm,
      depth: depth,
      bodyLine: body,
      grade: grade,
    );
  }

  _PoseMetrics? _metrics(Map<String, LandmarkPoint> lm) {
    final lHip = lm['leftHip'];
    final rHip = lm['rightHip'];
    final lKnee = lm['leftKnee'];
    final rKnee = lm['rightKnee'];
    final lAnkle = lm['leftAnkle'];
    final rAnkle = lm['rightAnkle'];
    final lShoulder = lm['leftShoulder'];
    final rShoulder = lm['rightShoulder'];
    final lElbow = lm['leftElbow'];
    final rElbow = lm['rightElbow'];
    final lWrist = lm['leftWrist'];
    final rWrist = lm['rightWrist'];

    final leftLeg = lHip != null && lKnee != null && lAnkle != null;
    final rightLeg = rHip != null && rKnee != null && rAnkle != null;
    final leftArm = lShoulder != null && lElbow != null && lWrist != null;
    final rightArm = rShoulder != null && rElbow != null && rWrist != null;

    if (exerciseType == 'pushup') {
      if (!leftArm && !rightArm) return null;
    } else {
      if (!leftLeg && !rightLeg) return null;
    }

    var kneeL = 180.0;
    var kneeR = 180.0;
    if (leftLeg) {
      kneeL = angleAt(lHip, lKnee, lAnkle);
    }
    if (rightLeg) {
      kneeR = angleAt(rHip, rKnee, rAnkle);
    }
    final knee = (leftLeg && rightLeg)
        ? (kneeL + kneeR) / 2
        : (leftLeg ? kneeL : kneeR);
    final kneeDiff = (kneeL - kneeR).abs();

    var elbowL = 180.0;
    var elbowR = 180.0;
    if (leftArm) {
      elbowL = angleAt(lShoulder, lElbow, lWrist);
    }
    if (rightArm) {
      elbowR = angleAt(rShoulder, rElbow, rWrist);
    }
    final elbow = (leftArm && rightArm)
        ? (elbowL + elbowR) / 2
        : (leftArm ? elbowL : elbowR);

    final hipY = ((lHip?.y ?? rHip?.y ?? 0) + (rHip?.y ?? lHip?.y ?? 0)) / 2;
    final shoulderY =
        ((lShoulder?.y ?? rShoulder?.y ?? 0) + (rShoulder?.y ?? lShoulder?.y ?? 0)) /
            2;

    double bodyLine = 0.85;
    final sh = lShoulder ?? rShoulder;
    final hip = lHip ?? rHip;
    final ankle = lAnkle ?? rAnkle;
    if (sh != null && hip != null && ankle != null) {
      final bodyAngle = angleAt(sh, hip, ankle);
      bodyLine = (1.0 - ((bodyAngle - 180.0).abs() / 40.0)).clamp(0.0, 1.0);
    }

    final primary = exerciseType == 'pushup' ? elbow : knee;
    final motion = ((180.0 - primary) / 90.0).clamp(0.0, 1.0);

    return _PoseMetrics(
      kneeAngle: knee,
      elbowAngle: elbow,
      primaryAngle: primary,
      hipY: hipY,
      shoulderY: shoulderY,
      bodyLine: bodyLine,
      kneeDiff: kneeDiff,
      motion: motion,
    );
  }
}

class _PoseMetrics {
  final double kneeAngle;
  final double elbowAngle;
  final double primaryAngle;
  final double hipY;
  final double shoulderY;
  final double bodyLine;
  final double kneeDiff;
  final double motion;

  const _PoseMetrics({
    required this.kneeAngle,
    required this.elbowAngle,
    required this.primaryAngle,
    required this.hipY,
    required this.shoulderY,
    required this.bodyLine,
    required this.kneeDiff,
    required this.motion,
  });
}

class _QualityParts {
  final double angle;
  final double depth;
  final double bodyLine;
  final String grade;
  const _QualityParts({
    required this.angle,
    required this.depth,
    required this.bodyLine,
    required this.grade,
  });
}

/// 顶点 [b] 的夹角，0–180°。
double angleAt(LandmarkPoint a, LandmarkPoint b, LandmarkPoint c) {
  final v1x = a.x - b.x;
  final v1y = a.y - b.y;
  final v2x = c.x - b.x;
  final v2y = c.y - b.y;
  final dot = v1x * v2x + v1y * v2y;
  final mag1 = math.sqrt(v1x * v1x + v1y * v1y);
  final mag2 = math.sqrt(v2x * v2x + v2y * v2y);
  if (mag1 < 1e-6 || mag2 < 1e-6) return 180.0;
  var cosVal = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
  return math.acos(cosVal) * 180 / math.pi;
}

double dist(LandmarkPoint a, LandmarkPoint b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}
