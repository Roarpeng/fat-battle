import 'package:flutter_test/flutter_test.dart';
import 'package:fat_battle/services/exercise_fsm.dart';

Map<String, LandmarkPoint> _legPose({
  required double hipY,
  required double kneeX,
  required double kneeY,
  required double ankleY,
  double hipX = 0.42,
  double ankleX = 0.42,
}) {
  LandmarkPoint l(double x, double y) => LandmarkPoint(x, y);
  LandmarkPoint r(double x, double y) => LandmarkPoint(x + 0.18, y);
  return {
    'leftHip': l(hipX, hipY),
    'rightHip': r(hipX, hipY),
    'leftKnee': l(kneeX, kneeY),
    'rightKnee': r(kneeX, kneeY),
    'leftAnkle': l(ankleX, ankleY),
    'rightAnkle': r(ankleX, ankleY),
    'leftShoulder': l(hipX, hipY - 0.22),
    'rightShoulder': r(hipX, hipY - 0.22),
  };
}

/// 站立：髋-膝-踝接近共线。
Map<String, LandmarkPoint> standingSquat() => _legPose(
      hipY: 0.42,
      kneeX: 0.42,
      kneeY: 0.64,
      ankleY: 0.90,
    );

/// 标准深蹲底：膝角约 90°，髋明显下沉。
Map<String, LandmarkPoint> deepSquat() => _legPose(
      hipY: 0.60,
      kneeX: 0.58,
      kneeY: 0.70,
      ankleY: 0.86,
      hipX: 0.42,
      ankleX: 0.42,
    );

/// 浅蹲：膝角仍较大，髋几乎没下沉。
Map<String, LandmarkPoint> shallowSquat() => _legPose(
      hipY: 0.455,
      kneeX: 0.52,
      kneeY: 0.67,
      ankleY: 0.90,
    );

Map<String, LandmarkPoint> _armPose({
  required double shoulderY,
  required double elbowX,
  required double elbowY,
  required double wristY,
  double hipY = 0.36,
}) {
  LandmarkPoint l(double x, double y) => LandmarkPoint(x, y);
  LandmarkPoint r(double x, double y) => LandmarkPoint(x + 0.16, y);
  const sx = 0.36;
  return {
    'leftShoulder': l(sx, shoulderY),
    'rightShoulder': r(sx, shoulderY),
    'leftElbow': l(elbowX, elbowY),
    'rightElbow': r(elbowX, elbowY),
    'leftWrist': l(sx, wristY),
    'rightWrist': r(sx, wristY),
    'leftHip': l(0.52, hipY),
    'rightHip': r(0.52, hipY),
    'leftAnkle': l(0.78, hipY + 0.04),
    'rightAnkle': r(0.78, hipY + 0.04),
  };
}

Map<String, LandmarkPoint> plankUp() => _armPose(
      shoulderY: 0.30,
      elbowX: 0.36,
      elbowY: 0.46,
      wristY: 0.62,
      hipY: 0.32,
    );

Map<String, LandmarkPoint> plankDown() => _armPose(
      shoulderY: 0.48,
      elbowX: 0.52,
      elbowY: 0.50,
      wristY: 0.58,
      hipY: 0.50,
    );

Map<String, LandmarkPoint> plankShallow() => _armPose(
      shoulderY: 0.31,
      elbowX: 0.42,
      elbowY: 0.46,
      wristY: 0.60,
      hipY: 0.33,
    );

Map<String, LandmarkPoint> lerpPose(
  Map<String, LandmarkPoint> a,
  Map<String, LandmarkPoint> b,
  double t,
) {
  final out = <String, LandmarkPoint>{};
  for (final key in a.keys) {
    final pa = a[key]!;
    final pb = b[key]!;
    out[key] = LandmarkPoint(
      pa.x + (pb.x - pa.x) * t,
      pa.y + (pb.y - pa.y) * t,
      pa.z + (pb.z - pa.z) * t,
    );
  }
  return out;
}

void _calibrate(ExerciseRepFsm fsm, Map<String, LandmarkPoint> stand) {
  for (var i = 0; i < 12; i++) {
    fsm.ingestCalibration(stand);
  }
  fsm.commitCalibration();
}

void _play(
  ExerciseRepFsm fsm,
  Map<String, LandmarkPoint> from,
  Map<String, LandmarkPoint> to, {
  int frames = 10,
  List<FsmTick>? ticks,
}) {
  for (var i = 0; i <= frames; i++) {
    final t = i / frames;
    ticks?.add(fsm.tick(lerpPose(from, to, t)));
  }
}

void main() {
  group('深蹲 FSM', () {
    test('合成关键点：完整 ROM 计 1 次', () {
      var t = DateTime(2026, 1, 1);
      final fsm = ExerciseRepFsm(exerciseType: 'squat', now: () => t);
      _calibrate(fsm, standingSquat());
      expect(fsm.calibration.isReady, isTrue);

      final ticks = <FsmTick>[];
      _play(fsm, standingSquat(), deepSquat(), ticks: ticks);
      for (var i = 0; i < 3; i++) {
        ticks.add(fsm.tick(deepSquat()));
      }
      _play(fsm, deepSquat(), standingSquat(), ticks: ticks);

      expect(ticks.where((e) => e.counted).length, 1);
      expect(ticks.any((e) => e.shallow), isFalse);
      final rep = ticks.firstWhere((e) => e.counted);
      expect(rep.minKneeAngle, lessThan(120));
      expect(rep.qualityAngle, isNotNull);
      expect(fsm.phase, RepPhase.setup);
    });

    test('浅 ROM 只给口令、不计次', () {
      var t = DateTime(2026, 1, 1);
      final fsm = ExerciseRepFsm(exerciseType: 'squat', now: () => t);
      _calibrate(fsm, standingSquat());

      final ticks = <FsmTick>[];
      _play(fsm, standingSquat(), shallowSquat(), frames: 8, ticks: ticks);
      _play(fsm, shallowSquat(), standingSquat(), frames: 8, ticks: ticks);

      expect(ticks.any((e) => e.counted), isFalse);
      expect(ticks.any((e) => e.shallow), isTrue);
      expect(ticks.any((e) => (e.cue ?? '').contains('再蹲低')), isTrue);
    });

    test('校准后用站姿髋高作基线，而不是全局阈值', () {
      final fsm = ExerciseRepFsm(exerciseType: 'squat');
      _calibrate(fsm, standingSquat());
      expect(fsm.calibration.standingHipY, closeTo(0.42, 0.03));
      expect(fsm.calibration.standingKneeAngle, greaterThan(160));
    });
  });

  group('俯卧撑 FSM', () {
    test('合成关键点：完整下压计 1 次', () {
      var t = DateTime(2026, 1, 1);
      final fsm = ExerciseRepFsm(exerciseType: 'pushup', now: () => t);
      _calibrate(fsm, plankUp());

      final ticks = <FsmTick>[];
      _play(fsm, plankUp(), plankDown(), ticks: ticks);
      for (var i = 0; i < 3; i++) {
        ticks.add(fsm.tick(plankDown()));
      }
      _play(fsm, plankDown(), plankUp(), ticks: ticks);

      expect(ticks.where((e) => e.counted).length, 1);
      expect(ticks.any((e) => e.shallow), isFalse);
    });

    test('浅下压不计次', () {
      var t = DateTime(2026, 1, 1);
      final fsm = ExerciseRepFsm(exerciseType: 'pushup', now: () => t);
      _calibrate(fsm, plankUp());

      final ticks = <FsmTick>[];
      _play(fsm, plankUp(), plankShallow(), frames: 8, ticks: ticks);
      _play(fsm, plankShallow(), plankUp(), frames: 8, ticks: ticks);

      expect(ticks.any((e) => e.counted), isFalse);
      expect(ticks.any((e) => e.shallow), isTrue);
      expect(ticks.any((e) => (e.cue ?? '').contains('再往下压')), isTrue);
    });
  });

  group('缺关键点', () {
    test('没有腿点给出入镜口令', () {
      final fsm = ExerciseRepFsm(exerciseType: 'squat');
      fsm.commitCalibration();
      final tick = fsm.tick({});
      expect(tick.counted, isFalse);
      expect(tick.cue, contains('入镜'));
    });
  });
}
