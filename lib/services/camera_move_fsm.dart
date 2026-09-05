import 'exercise_fsm.dart';

/// 摄像头可引导动作（深蹲/俯卧撑/弓步之外）的纯 Dart 状态机。
///
/// 与 [ExerciseRepFsm] 一样不依赖摄像头 / ML Kit，供端侧计次与单测。
/// 高抬腿 / 开合跳 / 登山跑走「阶段往返计次」；平板按秒累计；波比走 4 阶段。
abstract class CameraMoveFsm {
  CameraMoveFsm({
    required this.exerciseType,
    DateTime Function()? now,
    this.minRepMs = 400,
  }) : _now = now ?? DateTime.now;

  final String exerciseType;
  final DateTime Function() _now;
  final int minRepMs;

  DateTime? _lastRepAt;

  String get exerciseName;

  void reset();

  FsmTick tick(Map<String, LandmarkPoint> lm, {double sensitivity = 0.7});

  static CameraMoveFsm? forType(
    String exerciseType, {
    DateTime Function()? now,
  }) {
    switch (exerciseType) {
      case 'highknee':
        return HighKneeFsm(now: now);
      case 'plank':
        return PlankHoldFsm(now: now);
      case 'burpee':
        return BurpeePhaseFsm(now: now);
      case 'mountainclimber':
        return MountainClimberFsm(now: now);
      case 'jumping_jack':
      case 'hiit':
      case 'jumprope':
        // 旧 inline 开合跳检测器也覆盖 HIIT / 跳绳镜头模式。
        return JumpingJackFsm(now: now);
      default:
        return null;
    }
  }

  bool debounceOk() {
    final last = _lastRepAt;
    if (last == null) return true;
    return _now().difference(last).inMilliseconds >= minRepMs;
  }

  void markRep() => _lastRepAt = _now();
}

/// 镜头可引导动作目录：克制课 / 伤病过滤 / HUD 共用。
class CameraGuidableMove {
  final String type;
  final String name;
  final String category; // cardio | strength | core
  final bool kneeLoad;
  final bool waistLoad;
  final bool timedHold;
  final bool hasDedicatedFsm;

  const CameraGuidableMove({
    required this.type,
    required this.name,
    required this.category,
    this.kneeLoad = false,
    this.waistLoad = false,
    this.timedHold = false,
    this.hasDedicatedFsm = true,
  });
}

class CameraGuidableCatalog {
  CameraGuidableCatalog._();

  static const List<CameraGuidableMove> all = [
    CameraGuidableMove(
      type: 'squat',
      name: '深蹲',
      category: 'strength',
      kneeLoad: true,
    ),
    CameraGuidableMove(
      type: 'pushup',
      name: '俯卧撑',
      category: 'strength',
    ),
    CameraGuidableMove(
      type: 'lunge',
      name: '弓步蹲',
      category: 'strength',
      kneeLoad: true,
    ),
    CameraGuidableMove(
      type: 'jumping_jack',
      name: '开合跳',
      category: 'cardio',
    ),
    CameraGuidableMove(
      type: 'highknee',
      name: '高抬腿',
      category: 'cardio',
      kneeLoad: true,
    ),
    CameraGuidableMove(
      type: 'plank',
      name: '平板支撑',
      category: 'core',
      waistLoad: true,
      timedHold: true,
    ),
    CameraGuidableMove(
      type: 'burpee',
      name: '波比跳',
      category: 'strength',
      kneeLoad: true,
      waistLoad: true,
    ),
    CameraGuidableMove(
      type: 'mountainclimber',
      name: '登山跑',
      category: 'core',
      waistLoad: true,
    ),
  ];

  static CameraGuidableMove? byType(String type) {
    for (final m in all) {
      if (m.type == type) return m;
    }
    return null;
  }

  static List<String> typesForCategory(String category) =>
      all.where((m) => m.category == category).map((m) => m.type).toList();

  static Set<String> kneeLoadTypes() =>
      all.where((m) => m.kneeLoad).map((m) => m.type).toSet();

  static Set<String> waistLoadTypes() =>
      all.where((m) => m.waistLoad).map((m) => m.type).toSet();
}

/// 高抬腿：down → up → down 计 1 次。浅抬只给口令。
class HighKneeFsm extends CameraMoveFsm {
  HighKneeFsm({DateTime Function()? now})
      : super(exerciseType: 'highknee', now: now, minRepMs: 280);

  String _state = 'down';
  double _peakRatio = 0;

  @override
  String get exerciseName => '高抬腿';

  @override
  void reset() {
    _state = 'down';
    _peakRatio = 0;
    _lastRepAt = null;
  }

  @override
  FsmTick tick(Map<String, LandmarkPoint> lm, {double sensitivity = 0.7}) {
    final lHip = lm['leftHip'];
    final rHip = lm['rightHip'];
    final lKnee = lm['leftKnee'];
    final rKnee = lm['rightKnee'];
    final lShoulder = lm['leftShoulder'];
    final rShoulder = lm['rightShoulder'];
    if (lHip == null || rHip == null || lKnee == null || rKnee == null) {
      return FsmTick(
        phase: RepPhase.setup,
        exerciseName: exerciseName,
        cue: '请正对手机，下半身入镜',
      );
    }

    final hipMidY = (lHip.y + rHip.y) / 2;
    // 取抬得更高的一侧膝（图像 Y 向下），避免左右平均把单侧高抬冲掉。
    final raisedKneeY = lKnee.y < rKnee.y ? lKnee.y : rKnee.y;
    var torso = 0.1;
    if (lShoulder != null && rShoulder != null) {
      final shoulderMidY = (lShoulder.y + rShoulder.y) / 2;
      final t = (hipMidY - shoulderMidY).abs();
      if (t > 0.02) torso = t;
    }
    final ratio = (hipMidY - raisedKneeY) / torso;
    if (ratio > _peakRatio) _peakRatio = ratio;

    final upTh = 0.2 * (1.0 - sensitivity * 0.3);
    final downTh = 0.05 * (1.0 + (1.0 - sensitivity) * 0.5);
    var next = _state;
    if (ratio > upTh) {
      next = 'up';
    } else if (ratio < downTh) {
      next = 'down';
    }

    final motion = (ratio * 5).clamp(0.0, 1.0);
    if (_state == 'up' && next == 'down') {
      final shallow = _peakRatio < upTh * 1.15;
      _state = next;
      if (shallow) {
        _peakRatio = 0;
        return FsmTick(
          phase: RepPhase.setup,
          exerciseName: exerciseName,
          shallow: true,
          cue: '膝盖再抬高一点，大腿接近水平',
          motionLevel: motion,
        );
      }
      if (!debounceOk()) {
        _peakRatio = 0;
        return FsmTick(
          phase: RepPhase.lock,
          exerciseName: exerciseName,
          motionLevel: motion,
        );
      }
      markRep();
      final peak = _peakRatio;
      _peakRatio = 0;
      return FsmTick(
        phase: RepPhase.lock,
        exerciseName: exerciseName,
        counted: true,
        highlight: peak > 0.35,
        feedback: peak > 0.35 ? '膝盖抬得真高' : '节奏不错',
        qualityAngle: (peak / 0.3).clamp(0.0, 1.0),
        qualityDepth: peak > 0.2 ? 1.0 : peak / 0.2,
        qualityBodyLine: 0.8,
        motionLevel: motion,
      );
    }
    _state = next;
    return FsmTick(
      phase: _state == 'up' ? RepPhase.bottom : RepPhase.setup,
      exerciseName: exerciseName,
      motionLevel: motion,
    );
  }
}

/// 平板支撑：肩髋对齐且髋踝拉开时按秒累计。塌腰只给口令。
class PlankHoldFsm extends CameraMoveFsm {
  PlankHoldFsm({DateTime Function()? now})
      : super(exerciseType: 'plank', now: now, minRepMs: 900);

  DateTime? _holdStart;
  double _accumulated = 0;
  int _lastEmittedSec = 0;

  @override
  String get exerciseName => '平板支撑';

  double get accumulatedSeconds => _accumulated;

  @override
  void reset() {
    _holdStart = null;
    _accumulated = 0;
    _lastEmittedSec = 0;
    _lastRepAt = null;
  }

  void seedSeconds(int seconds) {
    _accumulated = seconds < 0 ? 0 : seconds.toDouble();
    _lastEmittedSec = _accumulated.toInt();
    _holdStart = null;
  }

  @override
  FsmTick tick(Map<String, LandmarkPoint> lm, {double sensitivity = 0.7}) {
    final lShoulder = lm['leftShoulder'];
    final rShoulder = lm['rightShoulder'];
    final lHip = lm['leftHip'];
    final rHip = lm['rightHip'];
    final lAnkle = lm['leftAnkle'];
    final rAnkle = lm['rightAnkle'];
    if (lShoulder == null || rShoulder == null || lHip == null || rHip == null) {
      _holdStart = null;
      return FsmTick(
        phase: RepPhase.setup,
        exerciseName: exerciseName,
        cue: '请正对手机，全身入镜',
      );
    }

    final shoulderMidY = (lShoulder.y + rShoulder.y) / 2;
    final hipMidY = (lHip.y + rHip.y) / 2;
    final shoulderHipDiff = (shoulderMidY - hipMidY).abs();
    var hipAnkleDiff = 0.0;
    if (lAnkle != null && rAnkle != null) {
      final ankleMidY = (lAnkle.y + rAnkle.y) / 2;
      hipAnkleDiff = (hipMidY - ankleMidY).abs();
    }
    var bodyLine = 0.7;
    if (lAnkle != null) {
      final bodyAngle = angleAt(lShoulder, lHip, lAnkle);
      bodyLine = (1.0 - ((bodyAngle - 180.0).abs() / 40.0)).clamp(0.0, 1.0);
    }

    final shTh = 0.08 * (1.0 + (1.0 - sensitivity) * 0.5);
    final haTh = 0.1 * (1.0 - (1.0 - sensitivity) * 0.3);
    final inForm = shoulderHipDiff < shTh && hipAnkleDiff > haTh;
    final now = _now();

    if (!inForm) {
      _holdStart = null;
      return FsmTick(
        phase: RepPhase.setup,
        exerciseName: exerciseName,
        cue: shoulderHipDiff >= shTh ? '腰往下塌了，收紧核心把髋抬平' : '请保持平板支撑姿势',
        qualityBodyLine: bodyLine,
        motionLevel: 0.3,
      );
    }

    if (_holdStart == null) {
      _holdStart = now;
    } else {
      _accumulated += now.difference(_holdStart!).inMilliseconds / 1000.0;
      _holdStart = now;
    }
    final secs = _accumulated.toInt();
    if (secs > _lastEmittedSec) {
      _lastEmittedSec = secs;
      markRep();
      return FsmTick(
        phase: RepPhase.lock,
        exerciseName: exerciseName,
        counted: true,
        highlight: secs > 0 && secs % 15 == 0,
        feedback: secs >= 30 ? '很棒，继续撑住' : '保持住',
        qualityAngle: 0.9,
        qualityDepth: 0.8,
        qualityBodyLine: bodyLine,
        motionLevel: 1.0,
        minKneeAngle: secs.toDouble(),
      );
    }
    return FsmTick(
      phase: RepPhase.bottom,
      exerciseName: exerciseName,
      qualityBodyLine: bodyLine,
      motionLevel: 1.0,
    );
  }
}

/// 波比：stand → squat → plank → jump → stand 计 1 次。
class BurpeePhaseFsm extends CameraMoveFsm {
  BurpeePhaseFsm({DateTime Function()? now})
      : super(exerciseType: 'burpee', now: now, minRepMs: 700);

  String phaseName = 'stand';
  bool _touchedPlank = false;

  @override
  String get exerciseName => '波比跳';

  @override
  void reset() {
    phaseName = 'stand';
    _touchedPlank = false;
    _lastRepAt = null;
  }

  @override
  FsmTick tick(Map<String, LandmarkPoint> lm, {double sensitivity = 0.7}) {
    final lShoulder = lm['leftShoulder'];
    final rShoulder = lm['rightShoulder'];
    final lHip = lm['leftHip'];
    final rHip = lm['rightHip'];
    final lKnee = lm['leftKnee'];
    final rKnee = lm['rightKnee'];
    final lAnkle = lm['leftAnkle'];
    final rAnkle = lm['rightAnkle'];
    if (lShoulder == null ||
        rShoulder == null ||
        lHip == null ||
        rHip == null ||
        lKnee == null ||
        rKnee == null) {
      return FsmTick(
        phase: RepPhase.setup,
        exerciseName: exerciseName,
        cue: '请正对手机，全身入镜',
      );
    }

    final kneeL = lAnkle == null ? 180.0 : angleAt(lHip, lKnee, lAnkle);
    final kneeR = rAnkle == null ? 180.0 : angleAt(rHip, rKnee, rAnkle);
    final avgKnee = (kneeL + kneeR) / 2;
    final shoulderMidY = (lShoulder.y + rShoulder.y) / 2;
    final hipMidY = (lHip.y + rHip.y) / 2;
    final shoulderHipDiff = (shoulderMidY - hipMidY).abs();
    final motion = ((180.0 - avgKnee) / 90.0).clamp(0.0, 1.0);

    final standTh = 160.0;
    final squatTh = 130.0;
    final plankTh = 0.1;

    String? cue;
    switch (phaseName) {
      case 'stand':
        if (avgKnee < squatTh) {
          phaseName = 'squat';
          cue = '下蹲了';
        }
      case 'squat':
        // 平板优先：撑地时膝可接近伸直，不能当成「站起来」。
        if (shoulderHipDiff < plankTh) {
          phaseName = 'plank';
          _touchedPlank = true;
          cue = '进入平板支撑';
        } else if (avgKnee > standTh) {
          phaseName = 'stand';
          if (!_touchedPlank) {
            return FsmTick(
              phase: RepPhase.setup,
              exerciseName: exerciseName,
              shallow: true,
              cue: '还没下到平板，手脚撑地再跳起',
              motionLevel: motion,
              minKneeAngle: avgKnee,
            );
          }
        }
      case 'plank':
        if (shoulderHipDiff > plankTh && avgKnee < squatTh) {
          phaseName = 'jump';
          cue = '跳起来';
        } else if (shoulderHipDiff > plankTh && avgKnee > standTh) {
          phaseName = 'stand';
        }
      case 'jump':
        if (avgKnee > standTh) {
          final counted = debounceOk();
          phaseName = 'stand';
          final didPlank = _touchedPlank;
          _touchedPlank = false;
          if (!didPlank) {
            return FsmTick(
              phase: RepPhase.setup,
              exerciseName: exerciseName,
              shallow: true,
              cue: '幅度不够，蹲下撑地再跳起',
              motionLevel: motion,
              minKneeAngle: avgKnee,
            );
          }
          if (counted) {
            markRep();
            return FsmTick(
              phase: RepPhase.lock,
              exerciseName: exerciseName,
              counted: true,
              highlight: avgKnee > 170,
              feedback: avgKnee > 170 ? '标准波比跳' : '节奏不错',
              qualityAngle: avgKnee > 170 ? 1.0 : ((avgKnee - 130) / 40).clamp(0, 1),
              qualityDepth: shoulderHipDiff < 0.06 ? 1.0 : (1.0 - shoulderHipDiff / 0.1).clamp(0, 1),
              qualityBodyLine: 0.8,
              motionLevel: motion,
              minKneeAngle: avgKnee,
            );
          }
        }
    }

    return FsmTick(
      phase: phaseName == 'plank' ? RepPhase.bottom : RepPhase.eccentric,
      exerciseName: exerciseName,
      cue: cue,
      motionLevel: motion,
      minKneeAngle: avgKnee,
    );
  }
}

/// 登山跑：平板形态下左右收腿交替计次。
class MountainClimberFsm extends CameraMoveFsm {
  MountainClimberFsm({DateTime Function()? now})
      : super(exerciseType: 'mountainclimber', now: now, minRepMs: 220);

  String _state = 'left';

  @override
  String get exerciseName => '登山跑';

  @override
  void reset() {
    _state = 'left';
    _lastRepAt = null;
  }

  @override
  FsmTick tick(Map<String, LandmarkPoint> lm, {double sensitivity = 0.7}) {
    final lShoulder = lm['leftShoulder'];
    final rShoulder = lm['rightShoulder'];
    final lHip = lm['leftHip'];
    final rHip = lm['rightHip'];
    final lKnee = lm['leftKnee'];
    final rKnee = lm['rightKnee'];
    final lAnkle = lm['leftAnkle'];
    final rAnkle = lm['rightAnkle'];
    if (lShoulder == null ||
        rShoulder == null ||
        lHip == null ||
        rHip == null ||
        lKnee == null ||
        rKnee == null) {
      return FsmTick(
        phase: RepPhase.setup,
        exerciseName: exerciseName,
        cue: '请正对手机，全身入镜',
      );
    }

    final shoulderMidY = (lShoulder.y + rShoulder.y) / 2;
    final hipMidY = (lHip.y + rHip.y) / 2;
    final shoulderHipDiff = (shoulderMidY - hipMidY).abs();
    var hipAnkleDiff = 0.0;
    if (lAnkle != null && rAnkle != null) {
      hipAnkleDiff = (hipMidY - ((lAnkle.y + rAnkle.y) / 2)).abs();
    }
    final shTh = 0.08 * (1.0 + (1.0 - sensitivity) * 0.3);
    final haTh = 0.1 * (1.0 - (1.0 - sensitivity) * 0.3);
    final inPlank = shoulderHipDiff < shTh && hipAnkleDiff > haTh;
    if (!inPlank) {
      return FsmTick(
        phase: RepPhase.setup,
        exerciseName: exerciseName,
        cue: shoulderHipDiff >= shTh ? '腰往下塌了，收紧核心把髋抬平' : '请保持平板支撑姿势',
        motionLevel: 0.1,
      );
    }

    final midShoulder = LandmarkPoint(
      (lShoulder.x + rShoulder.x) / 2,
      (lShoulder.y + rShoulder.y) / 2,
    );
    final leftTuck = dist(lKnee, midShoulder);
    final rightTuck = dist(rKnee, midShoulder);
    final threshold = 0.04 * (1.0 + (1.0 - sensitivity) * 0.5);
    final leftForward = leftTuck + threshold < rightTuck;
    final rightForward = rightTuck + threshold < leftTuck;
    var next = _state;
    if (leftForward && !rightForward) {
      next = 'left';
    } else if (rightForward && !leftForward) {
      next = 'right';
    }

    if (_state == 'left' && next == 'right' && debounceOk()) {
      markRep();
      _state = next;
      return FsmTick(
        phase: RepPhase.lock,
        exerciseName: exerciseName,
        counted: true,
        highlight: true,
        feedback: '标准登山跑',
        qualityAngle: 0.9,
        qualityDepth: 0.8,
        qualityBodyLine: 0.7,
        motionLevel: 0.8,
      );
    }
    _state = next;
    return FsmTick(
      phase: RepPhase.eccentric,
      exerciseName: exerciseName,
      motionLevel: (leftTuck - rightTuck).abs() > threshold ? 0.8 : 0.3,
    );
  }
}

/// 开合跳：open → closed 计 1 次；过快节奏不计。
class JumpingJackFsm extends CameraMoveFsm {
  JumpingJackFsm({DateTime Function()? now})
      : super(exerciseType: 'jumping_jack', now: now, minRepMs: 300);

  String _state = 'closed';
  double _noseMinY = 999;
  double _noseMaxY = 0;

  @override
  String get exerciseName => '开合跳';

  @override
  void reset() {
    _state = 'closed';
    _noseMinY = 999;
    _noseMaxY = 0;
    _lastRepAt = null;
  }

  @override
  FsmTick tick(Map<String, LandmarkPoint> lm, {double sensitivity = 0.7}) {
    final lWrist = lm['leftWrist'];
    final rWrist = lm['rightWrist'];
    final lShoulder = lm['leftShoulder'];
    final rShoulder = lm['rightShoulder'];
    final nose = lm['nose'];
    final lHip = lm['leftHip'];
    final rHip = lm['rightHip'];
    final lAnkle = lm['leftAnkle'];
    final rAnkle = lm['rightAnkle'];
    if (lWrist == null || rWrist == null || lShoulder == null || rShoulder == null) {
      return FsmTick(
        phase: RepPhase.setup,
        exerciseName: exerciseName,
        cue: '请确保全身入镜',
      );
    }

    final shoulderY = (lShoulder.y + rShoulder.y) / 2;
    final wristY = (lWrist.y + rWrist.y) / 2;
    final handsUp = wristY < shoulderY - (1.0 - sensitivity) * 0.04;
    var feetSpread = 0.0;
    if (lAnkle != null && rAnkle != null && lHip != null && rHip != null) {
      final hipWidth = (lHip.x - rHip.x).abs();
      final feetWidth = (lAnkle.x - rAnkle.x).abs();
      feetSpread = hipWidth > 0 ? feetWidth / hipWidth : 1.0;
    }
    var jumpHeight = 0.0;
    if (nose != null) {
      if (nose.y < _noseMinY) _noseMinY = nose.y;
      if (nose.y > _noseMaxY) _noseMaxY = nose.y;
      if (_noseMaxY > _noseMinY) {
        jumpHeight = (_noseMaxY - _noseMinY) / _noseMaxY;
      }
    }
    final isOpen = handsUp && (feetSpread > 1.3 || jumpHeight > 0.03);
    final next = isOpen ? 'open' : 'closed';
    final motion = ((handsUp ? 0.5 : 0.1) + feetSpread * 0.2).clamp(0.0, 1.0);

    if (_state == 'open' && next == 'closed') {
      final shallow = !handsUp && feetSpread < 1.15 && jumpHeight < 0.02;
      _state = next;
      if (shallow) {
        _noseMinY = 999;
        _noseMaxY = 0;
        return FsmTick(
          phase: RepPhase.setup,
          exerciseName: exerciseName,
          shallow: true,
          cue: '手脚再张开一点，跳起来',
          motionLevel: motion,
        );
      }
      if (!debounceOk()) {
        _noseMinY = 999;
        _noseMaxY = 0;
        return FsmTick(
          phase: RepPhase.lock,
          exerciseName: exerciseName,
          motionLevel: motion,
        );
      }
      markRep();
      final jh = jumpHeight;
      final fs = feetSpread;
      _noseMinY = 999;
      _noseMaxY = 0;
      return FsmTick(
        phase: RepPhase.lock,
        exerciseName: exerciseName,
        counted: true,
        highlight: jh > 0.08 && fs > 1.5,
        feedback: jh > 0.04 ? '节奏不错' : '再跳高一点',
        qualityAngle: (jh / 0.08).clamp(0.0, 1.0),
        qualityDepth: (fs / 1.5).clamp(0.0, 1.0),
        qualityBodyLine: 0.85,
        motionLevel: motion,
      );
    }
    _state = next;
    return FsmTick(
      phase: isOpen ? RepPhase.bottom : RepPhase.setup,
      exerciseName: exerciseName,
      motionLevel: motion,
    );
  }
}
