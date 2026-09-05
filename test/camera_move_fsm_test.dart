import 'package:flutter_test/flutter_test.dart';
import 'package:fat_battle/services/camera_move_fsm.dart';
import 'package:fat_battle/services/exercise_fsm.dart';

Map<String, LandmarkPoint> _pts(Map<String, List<double>> raw) {
  return {
    for (final e in raw.entries)
      e.key: LandmarkPoint(e.value[0], e.value[1], e.value.length > 2 ? e.value[2] : 0),
  };
}

/// 站姿：膝低于髋。
Map<String, LandmarkPoint> highKneeDown() => _pts({
      'leftShoulder': [0.40, 0.20],
      'rightShoulder': [0.60, 0.20],
      'leftHip': [0.42, 0.48],
      'rightHip': [0.58, 0.48],
      'leftKnee': [0.42, 0.70],
      'rightKnee': [0.58, 0.70],
      'leftAnkle': [0.42, 0.90],
      'rightAnkle': [0.58, 0.90],
    });

/// 高抬：左膝抬近髋。
Map<String, LandmarkPoint> highKneeUp() => _pts({
      'leftShoulder': [0.40, 0.20],
      'rightShoulder': [0.60, 0.20],
      'leftHip': [0.42, 0.48],
      'rightHip': [0.58, 0.48],
      'leftKnee': [0.42, 0.28],
      'rightKnee': [0.58, 0.68],
      'leftAnkle': [0.42, 0.50],
      'rightAnkle': [0.58, 0.88],
    });

Map<String, LandmarkPoint> highKneeShallow() => _pts({
      'leftShoulder': [0.40, 0.20],
      'rightShoulder': [0.60, 0.20],
      'leftHip': [0.42, 0.48],
      'rightHip': [0.58, 0.48],
      // 刚过 up 阈值但不够深，应记浅抬
      'leftKnee': [0.42, 0.435],
      'rightKnee': [0.58, 0.70],
      'leftAnkle': [0.42, 0.62],
      'rightAnkle': [0.58, 0.90],
    });

Map<String, LandmarkPoint> plankGood() => _pts({
      'leftShoulder': [0.22, 0.42],
      'rightShoulder': [0.28, 0.42],
      'leftHip': [0.52, 0.44],
      'rightHip': [0.58, 0.44],
      'leftAnkle': [0.82, 0.62],
      'rightAnkle': [0.88, 0.62],
      'leftKnee': [0.68, 0.54],
      'rightKnee': [0.74, 0.54],
    });

Map<String, LandmarkPoint> plankSag() => _pts({
      'leftShoulder': [0.22, 0.32],
      'rightShoulder': [0.28, 0.32],
      'leftHip': [0.52, 0.58],
      'rightHip': [0.58, 0.58],
      'leftAnkle': [0.82, 0.50],
      'rightAnkle': [0.88, 0.50],
      'leftKnee': [0.68, 0.54],
      'rightKnee': [0.74, 0.54],
    });

Map<String, LandmarkPoint> jackClosed() => _pts({
      'nose': [0.50, 0.18],
      'leftShoulder': [0.40, 0.28],
      'rightShoulder': [0.60, 0.28],
      'leftWrist': [0.36, 0.48],
      'rightWrist': [0.64, 0.48],
      'leftHip': [0.44, 0.52],
      'rightHip': [0.56, 0.52],
      'leftAnkle': [0.45, 0.90],
      'rightAnkle': [0.55, 0.90],
    });

Map<String, LandmarkPoint> jackOpen() => _pts({
      'nose': [0.50, 0.10],
      'leftShoulder': [0.40, 0.28],
      'rightShoulder': [0.60, 0.28],
      'leftWrist': [0.22, 0.08],
      'rightWrist': [0.78, 0.08],
      'leftHip': [0.40, 0.50],
      'rightHip': [0.60, 0.50],
      'leftAnkle': [0.28, 0.88],
      'rightAnkle': [0.72, 0.88],
    });

Map<String, LandmarkPoint> standBurpee() => _pts({
      'leftShoulder': [0.40, 0.22],
      'rightShoulder': [0.60, 0.22],
      'leftHip': [0.42, 0.48],
      'rightHip': [0.58, 0.48],
      'leftKnee': [0.42, 0.68],
      'rightKnee': [0.58, 0.68],
      'leftAnkle': [0.42, 0.90],
      'rightAnkle': [0.58, 0.90],
    });

Map<String, LandmarkPoint> squatBurpee() => _pts({
      'leftShoulder': [0.40, 0.36],
      'rightShoulder': [0.60, 0.36],
      'leftHip': [0.42, 0.58],
      'rightHip': [0.58, 0.58],
      'leftKnee': [0.34, 0.70],
      'rightKnee': [0.66, 0.70],
      'leftAnkle': [0.38, 0.88],
      'rightAnkle': [0.62, 0.88],
    });

Map<String, LandmarkPoint> climberLeft() {
  final p = plankGood();
  return {
    ...p,
    'leftKnee': const LandmarkPoint(0.30, 0.46),
    'rightKnee': const LandmarkPoint(0.74, 0.56),
  };
}

Map<String, LandmarkPoint> climberRight() {
  final p = plankGood();
  return {
    ...p,
    'leftKnee': const LandmarkPoint(0.74, 0.56),
    'rightKnee': const LandmarkPoint(0.30, 0.46),
  };
}

void main() {
  group('CameraMoveFsm.forType', () {
    test('镜头可引导动作都有 FSM，未知类型为 null', () {
      for (final type in const [
        'highknee',
        'plank',
        'burpee',
        'mountainclimber',
        'jumping_jack',
      ]) {
        expect(CameraMoveFsm.forType(type), isNotNull, reason: type);
      }
      expect(CameraMoveFsm.forType('squat'), isNull);
      expect(CameraMoveFsm.forType('running'), isNull);
    });
  });

  group('高抬腿', () {
    test('完整抬落计 1 次', () {
      var t = DateTime(2026, 1, 1);
      final fsm = HighKneeFsm(now: () => t);
      expect(fsm.tick(highKneeDown()).counted, isFalse);
      expect(fsm.tick(highKneeUp()).counted, isFalse);
      t = t.add(const Duration(milliseconds: 400));
      final down = fsm.tick(highKneeDown());
      expect(down.counted, isTrue);
      expect(down.shallow, isFalse);
    });

    test('浅抬只给口令、不计次', () {
      final fsm = HighKneeFsm();
      fsm.tick(highKneeDown());
      fsm.tick(highKneeShallow());
      final tick = fsm.tick(highKneeDown());
      expect(tick.counted, isFalse);
      expect(tick.shallow, isTrue);
      expect(tick.cue, contains('抬高'));
    });
  });

  group('平板支撑', () {
    test('标准体线按秒累计', () {
      var t = DateTime(2026, 1, 1);
      final fsm = PlankHoldFsm(now: () => t);
      expect(fsm.tick(plankGood()).counted, isFalse);
      t = t.add(const Duration(milliseconds: 1100));
      final tick = fsm.tick(plankGood());
      expect(tick.counted, isTrue);
      expect(fsm.accumulatedSeconds, greaterThan(1));
    });

    test('塌腰不计秒并出口令', () {
      var t = DateTime(2026, 1, 1);
      final fsm = PlankHoldFsm(now: () => t);
      fsm.tick(plankGood());
      t = t.add(const Duration(milliseconds: 400));
      final sag = fsm.tick(plankSag());
      expect(sag.counted, isFalse);
      expect(sag.cue, contains('塌'));
    });
  });

  group('开合跳', () {
    test('open→closed 计 1 次', () {
      var t = DateTime(2026, 1, 1);
      final fsm = JumpingJackFsm(now: () => t);
      fsm.tick(jackClosed());
      fsm.tick(jackOpen());
      t = t.add(const Duration(milliseconds: 400));
      expect(fsm.tick(jackClosed()).counted, isTrue);
    });
  });

  group('登山跑', () {
    test('平板下左右收腿计 1 次', () {
      var t = DateTime(2026, 1, 1);
      final fsm = MountainClimberFsm(now: () => t);
      fsm.tick(climberLeft());
      t = t.add(const Duration(milliseconds: 300));
      expect(fsm.tick(climberRight()).counted, isTrue);
    });

    test('不在平板形态不计次', () {
      final fsm = MountainClimberFsm();
      final tick = fsm.tick(plankSag());
      expect(tick.counted, isFalse);
      expect(tick.cue, isNotNull);
    });
  });

  group('波比跳', () {
    test('缺平板阶段记浅幅度', () {
      final fsm = BurpeePhaseFsm();
      fsm.tick(standBurpee());
      fsm.tick(squatBurpee());
      final back = fsm.tick(standBurpee());
      expect(back.counted, isFalse);
      expect(back.shallow, isTrue);
    });

    test('stand→squat→plank→jump→stand 计 1 次', () {
      var t = DateTime(2026, 1, 1);
      final fsm = BurpeePhaseFsm(now: () => t);
      fsm.tick(standBurpee());
      fsm.tick(squatBurpee());
      fsm.tick(plankGood());
      fsm.tick(squatBurpee());
      t = t.add(const Duration(milliseconds: 800));
      expect(fsm.tick(standBurpee()).counted, isTrue);
    });
  });

  group('目录', () {
    test('克制课镜头动作都在目录里且带伤病标记', () {
      expect(CameraGuidableCatalog.byType('highknee')!.kneeLoad, isTrue);
      expect(CameraGuidableCatalog.byType('plank')!.waistLoad, isTrue);
      expect(CameraGuidableCatalog.byType('burpee')!.kneeLoad, isTrue);
      expect(CameraGuidableCatalog.kneeLoadTypes(), containsAll(['squat', 'lunge', 'highknee']));
    });
  });
}
