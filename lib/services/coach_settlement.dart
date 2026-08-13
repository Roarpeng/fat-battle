import '../constants/app_constants.dart';
import '../core/core_types.dart';
import '../core/damage.dart';
import '../models/game_models.dart';
import 'coach_lesson.dart';

/// 教练课结算输入（一次或连训累计）。
class CoachSettlementInput {
  /// 由时长 + 次数算出的基础消耗（千卡）。
  final int baseCalories;

  /// 有效次数 / 秒数累计。
  final int reps;

  /// 质量等级 S–D；空则按 D。
  final String grade;

  /// 质量分 0–100 的平均（可选，缺省由等级反推）。
  final int? qualityScore;

  /// 本课最高连击。
  final int peakCombo;

  /// 结束时体力 0–100。
  final double stamina;

  /// 本次主动作 type（用于克制）；可空。
  final String? exerciseType;

  /// 今日已摄入。
  final int todayCalIn;

  /// 用户难度。
  final Difficulty difficulty;

  /// 今日怪物属性（可空：无克制）。
  final ExerciseCategory? monsterAffinity;

  const CoachSettlementInput({
    required this.baseCalories,
    required this.reps,
    this.grade = 'D',
    this.qualityScore,
    this.peakCombo = 0,
    this.stamina = 100,
    this.exerciseType,
    this.todayCalIn = 0,
    this.difficulty = Difficulty.normal,
    this.monsterAffinity,
  });
}

/// 教练课结算结果：卡路里 + 待攻伤害。
class CoachSettlement {
  final int calories;
  final int damage;
  final double qualityMultiplier;
  final double comboMultiplier;
  final double staminaMultiplier;
  final double counterMultiplier;
  final DamageEffectiveness effectiveness;
  final String grade;
  final String attackType;
  final bool isCounter;
  final bool isResisted;
  final String? counterLabel;
  final PendingAttack pendingAttack;

  const CoachSettlement({
    required this.calories,
    required this.damage,
    required this.qualityMultiplier,
    required this.comboMultiplier,
    required this.staminaMultiplier,
    required this.counterMultiplier,
    required this.effectiveness,
    required this.grade,
    required this.attackType,
    required this.isCounter,
    required this.isResisted,
    required this.counterLabel,
    required this.pendingAttack,
  });
}

/// S–D 质量倍率（夹在 0.7～1.5，对齐 [ExerciseGameLogic] 等级）。
double qualityMultiplierForGrade(String grade) {
  switch (grade.toUpperCase()) {
    case 'S':
      return 1.5;
    case 'A':
      return 1.25;
    case 'B':
      return 1.0;
    case 'C':
      return 0.85;
    default:
      return 0.7;
  }
}

/// 连击对结算的贡献：每 5 连 +0.08，上限 +0.4（对应 2.0x 游戏连击的折半）。
double comboMultiplierForPeak(int peakCombo) {
  if (peakCombo <= 0) return 1.0;
  final tiers = peakCombo ~/ 5;
  return (1.0 + tiers * 0.08).clamp(1.0, 1.4);
}

/// 结束时体力：耗尽略惩罚，留有余力略加成。范围 0.85～1.1。
double staminaMultiplierFor(double stamina) {
  final s = stamina.clamp(0.0, 100.0);
  return (0.85 + s / 100.0 * 0.25).clamp(0.85, 1.1);
}

/// 由消耗档位挑选首页攻击特效。
String attackTypeForCalories(int calories) {
  if (calories >= 300) return 'bomb';
  if (calories >= 150) return 'fireball';
  if (calories >= 80) return 'lightning';
  if (calories >= 40) return 'knife';
  return 'missile';
}

String _normalizeGrade(String raw) {
  final g = raw.toUpperCase();
  if (g == 'S' || g == 'A' || g == 'B' || g == 'C' || g == 'D') return g;
  return 'D';
}

/// 把质量 / 连击 / 体力 / 次数消耗折成伤害，并生成 [PendingAttack]。
///
/// 卡路里仍走现有「时长 + 次数」基数，再叠质量倍率；伤害走
/// [calculateDamageWithCounter]（有怪物属性时）或 [calculateDamage]。
CoachSettlement settleCoachSession(CoachSettlementInput input) {
  final grade = _normalizeGrade(input.grade);
  final qMul = qualityMultiplierForGrade(grade);
  final cMul = comboMultiplierForPeak(input.peakCombo);
  final sMul = staminaMultiplierFor(input.stamina);

  final scaledCal =
      (input.baseCalories * qMul * cMul * sMul).round().clamp(0, 9999);

  final category = input.exerciseType == null
      ? null
      : categoryOfExercise(input.exerciseType!);
  final affinity = input.monsterAffinity;

  late final int damage;
  late final double counterMul;
  late final DamageEffectiveness effectiveness;
  var isCounter = false;
  var isResisted = false;
  String? counterLabel;

  if (category != null && affinity != null) {
    final result = calculateDamageWithCounter(
      input.todayCalIn,
      scaledCal,
      input.difficulty,
      category,
      affinity,
    );
    damage = result.damage;
    counterMul = result.multiplier;
    effectiveness = result.effectiveness;
    isCounter = result.effectiveness == DamageEffectiveness.superEffective;
    isResisted = result.effectiveness == DamageEffectiveness.weak;
    if (isCounter) {
      counterLabel = '效果绝佳';
    } else if (isResisted) {
      counterLabel = '效果不太好';
    }
  } else {
    damage = calculateDamage(input.todayCalIn, scaledCal, input.difficulty);
    counterMul = 1.0;
    effectiveness = DamageEffectiveness.normal;
  }

  final attackType = attackTypeForCalories(scaledCal);
  final pending = PendingAttack(
    damage: damage,
    attackType: attackType,
    isOvereat: false,
    exerciseType: input.exerciseType,
    isCounter: isCounter,
    isResisted: isResisted,
    counterLabel: counterLabel,
    grade: grade,
    calories: scaledCal,
    reps: input.reps,
  );

  return CoachSettlement(
    calories: scaledCal,
    damage: damage,
    qualityMultiplier: qMul,
    comboMultiplier: cMul,
    staminaMultiplier: sMul,
    counterMultiplier: counterMul,
    effectiveness: effectiveness,
    grade: grade,
    attackType: attackType,
    isCounter: isCounter,
    isResisted: isResisted,
    counterLabel: counterLabel,
    pendingAttack: pending,
  );
}

/// 摄像头课基础消耗：与 [ExercisePage] 原公式对齐。
/// `cal = calPerMin * minutes * 0.3 + (calPerMin / 30) * reps`
int cameraBaseCalories({
  required int calPerMin,
  required double elapsedMinutes,
  required int reps,
}) {
  final safeMin = elapsedMinutes < 0 ? 0.0 : elapsedMinutes;
  final safeReps = reps < 0 ? 0 : reps;
  final calPerRep = calPerMin / 30.0;
  return ((calPerMin * safeMin * 0.3) + (calPerRep * safeReps)).round().clamp(0, 9999);
}
