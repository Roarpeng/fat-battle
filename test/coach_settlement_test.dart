import 'package:flutter_test/flutter_test.dart';
import 'package:fat_battle/constants/app_constants.dart';
import 'package:fat_battle/core/core_types.dart';
import 'package:fat_battle/core/damage.dart';
import 'package:fat_battle/services/coach_cues.dart';
import 'package:fat_battle/services/coach_settlement.dart';

CoachSettlementInput _input({
  int calories = 100,
  int reps = 20,
  String grade = 'B',
  int combo = 0,
  double stamina = 100,
  String? type = 'squat',
  ExerciseCategory? affinity,
  Difficulty difficulty = Difficulty.normal,
  int intake = 0,
}) {
  return CoachSettlementInput(
    baseCalories: calories,
    reps: reps,
    grade: grade,
    peakCombo: combo,
    stamina: stamina,
    exerciseType: type,
    todayCalIn: intake,
    difficulty: difficulty,
    monsterAffinity: affinity,
  );
}

void main() {
  group('质量 / 连击 / 体力倍率', () {
    test('S 级倍率高于 D 级', () {
      expect(qualityMultiplierForGrade('S'), 1.5);
      expect(qualityMultiplierForGrade('D'), 0.7);
      expect(qualityMultiplierForGrade('S'), greaterThan(qualityMultiplierForGrade('A')));
      expect(qualityMultiplierForGrade('A'), greaterThan(qualityMultiplierForGrade('B')));
    });

    test('连击每 5 次加一档，上限 1.4', () {
      expect(comboMultiplierForPeak(0), 1.0);
      expect(comboMultiplierForPeak(5), 1.08);
      expect(comboMultiplierForPeak(25), 1.4);
    });

    test('体力耗尽低于满体力', () {
      expect(staminaMultiplierFor(0), lessThan(staminaMultiplierFor(100)));
      expect(staminaMultiplierFor(0), 0.85);
      expect(staminaMultiplierFor(100), 1.1);
    });
  });

  group('结算伤害', () {
    test('同消耗下 S 级伤害高于 D 级', () {
      final s = settleCoachSession(_input(grade: 'S', affinity: ExerciseCategory.core));
      final d = settleCoachSession(_input(grade: 'D', affinity: ExerciseCategory.core));
      expect(s.damage, greaterThan(d.damage));
      expect(s.calories, greaterThan(d.calories));
      expect(s.pendingAttack.grade, 'S');
      expect(s.pendingAttack.damage, s.damage);
    });

    test('高连击提高结算卡路里与伤害', () {
      final low = settleCoachSession(_input(combo: 0, grade: 'B'));
      final high = settleCoachSession(_input(combo: 20, grade: 'B'));
      expect(high.calories, greaterThan(low.calories));
      expect(high.damage, greaterThan(low.damage));
    });

    test('体力耗尽降低伤害', () {
      final fresh = settleCoachSession(_input(stamina: 100, grade: 'B'));
      final spent = settleCoachSession(_input(stamina: 0, grade: 'B'));
      expect(spent.damage, lessThan(fresh.damage));
    });

    test('深蹲克制核心怪：效果绝佳 ×1.5', () {
      final hit = settleCoachSession(
        _input(
          type: 'squat',
          affinity: ExerciseCategory.core,
          grade: 'B',
        ),
      );
      expect(hit.effectiveness, DamageEffectiveness.superEffective);
      expect(hit.counterMultiplier, 1.5);
      expect(hit.isCounter, isTrue);
      expect(hit.pendingAttack.isCounter, isTrue);
    });

    test('开合跳打核心怪被克 ×0.7', () {
      final hit = settleCoachSession(
        _input(
          type: 'jumping_jack',
          affinity: ExerciseCategory.core,
          grade: 'B',
        ),
      );
      expect(hit.effectiveness, DamageEffectiveness.weak);
      expect(hit.counterMultiplier, 0.7);
      expect(hit.isResisted, isTrue);
    });

    test('无怪物属性时仍能结算且不丢课', () {
      final hit = settleCoachSession(_input(affinity: null, calories: 80, reps: 12));
      expect(hit.damage, greaterThan(0));
      expect(hit.pendingAttack.damage, hit.damage);
      expect(hit.pendingAttack.isOvereat, isFalse);
    });

    test('摄像头基础消耗公式：时长 0.3 + 次数', () {
      // 7 kcal/min squat, 2 min, 30 reps → 7*2*0.3 + (7/30)*30 = 4.2 + 7 = 11.2 → 11
      expect(
        cameraBaseCalories(calPerMin: 7, elapsedMinutes: 2, reps: 30),
        11,
      );
      expect(
        cameraBaseCalories(calPerMin: 8, elapsedMinutes: 0, reps: 0),
        0,
      );
    });

    test('攻击特效按消耗分档', () {
      expect(attackTypeForCalories(10), 'missile');
      expect(attackTypeForCalories(40), 'knife');
      expect(attackTypeForCalories(80), 'lightning');
      expect(attackTypeForCalories(150), 'fireball');
      expect(attackTypeForCalories(300), 'bomb');
    });
  });

  group('纠姿口令', () {
    test('出画 / 过近走门控 tip', () {
      expect(resolveCoachCue(formTip: 'out_of_frame').kind, CoachCueKind.outOfFrame);
      expect(resolveCoachCue(formTip: 'too_close').kind, CoachCueKind.tooClose);
    });

    test('检测器深蹲深度反馈给出具体口令', () {
      final cue = resolveCoachCue(
        liveFeedback: '幅度不够哦，再蹲低一点~',
        exerciseType: 'squat',
      );
      expect(cue.kind, CoachCueKind.squatDepth);
      expect(cue.spoken, contains('平行地面'));
    });
  });
}
