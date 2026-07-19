import 'dart:math' as math;
import 'core_types.dart';

/// BMR / TDEE / 目标卡路里计算 —— 纯函数实现。
///
/// 对应 web/src/core/calories.ts。

// ========== 常量配置 ==========

/// 活动水平 → TDEE 倍率映射。
/// 对应 web/src/core/calories.ts 中的 `ACTIVITY_FACTORS`。
const Map<ActivityLevel, double> activityFactors = {
  ActivityLevel.sedentary: 1.2,
  ActivityLevel.light: 1.375,
  ActivityLevel.moderate: 1.55,
  ActivityLevel.active: 1.725,
  ActivityLevel.veryActive: 1.9,
};

/// 性别 → 最低安全卡路里摄入。
/// 对应 web/src/core/calories.ts 中的 `SAFE_MIN_CALORIES`。
const Map<Gender, int> _safeMinCalories = {
  Gender.male: 1500,
  Gender.female: 1200,
};

/// 减重目标配置。
/// 对应 web/src/core/calories.ts 中的 `GOAL_CONFIGS`。
class _GoalConfig {
  final int dailyDeficit;
  final double weeklyLoss;
  const _GoalConfig({required this.dailyDeficit, required this.weeklyLoss});
}

const Map<CaloriesGoal, _GoalConfig> _goalConfigs = {
  CaloriesGoal.mildLoss: _GoalConfig(dailyDeficit: 250, weeklyLoss: 0.25),
  CaloriesGoal.loss: _GoalConfig(dailyDeficit: 500, weeklyLoss: 0.5),
  CaloriesGoal.extremeLoss: _GoalConfig(dailyDeficit: 1000, weeklyLoss: 1.0),
};

/// `calculateTargetCalories` 的返回结果。
/// 对应 web/src/core/calories.ts 中 `calculateTargetCalories` 的返回值结构。
class TargetCaloriesResult {
  /// 基础代谢率
  final int bmr;

  /// 总日常能量消耗
  final int tdee;

  /// 目标每日摄入卡路里
  final int targetCalories;

  /// 实际每日赤字（受安全下限影响）
  final int dailyDeficit;

  /// 预计每周减重 (kg)
  final double estimatedWeeklyLoss;

  const TargetCaloriesResult({
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
    required this.dailyDeficit,
    required this.estimatedWeeklyLoss,
  });
}

// ========== 计算函数 ==========

/// 计算 BMR（基础代谢率），采用 Mifflin-St Jeor 公式。
///
/// [gender] 性别
/// [weightKg] 体重 (kg)
/// [heightCm] 身高 (cm)
/// [age] 年龄（岁）
/// 返回四舍五入的 BMR 整数值。
int calculateBmr(Gender gender, num weightKg, num heightCm, num age) {
  final weight = math.max(0.0, weightKg.toDouble());
  final height = math.max(0.0, heightCm.toDouble());
  final ageYears = math.max(0.0, age.toDouble());

  if (gender == Gender.male) {
    return (10 * weight + 6.25 * height - 5 * ageYears + 5).round();
  }
  return (10 * weight + 6.25 * height - 5 * ageYears - 161).round();
}

/// 计算 TDEE（总日常能量消耗）= BMR × 活动倍率。
///
/// [bmr] 基础代谢率
/// [activityLevel] 活动水平
/// 返回四舍五入的 TDEE 整数值。
int calculateTdee(num bmr, ActivityLevel activityLevel) {
  final baseBmr = math.max(0, bmr.toInt());
  final factor = activityFactors[activityLevel]!;
  return (baseBmr * factor).round();
}

/// 计算目标卡路里摄入，结合减重目标与安全下限。
///
/// [gender] 性别
/// [weightKg] 体重 (kg)
/// [heightCm] 身高 (cm)
/// [age] 年龄（岁）
/// [activityLevel] 活动水平
/// [goal] 减重目标，默认 `CaloriesGoal.loss`
///
/// 当目标摄入低于性别对应的安全下限时，回退到安全下限，
/// 并按安全下限重新计算实际赤字与每周减重。
TargetCaloriesResult calculateTargetCalories(
  Gender gender,
  num weightKg,
  num heightCm,
  num age,
  ActivityLevel activityLevel, [
  CaloriesGoal goal = CaloriesGoal.loss,
]) {
  final bmr = calculateBmr(gender, weightKg, heightCm, age);
  final tdee = calculateTdee(bmr, activityLevel);
  final goalConfig = _goalConfigs[goal]!;
  final safeMin = _safeMinCalories[gender]!;

  var targetCalories = tdee - goalConfig.dailyDeficit;
  var actualDeficit = goalConfig.dailyDeficit;
  var actualWeeklyLoss = goalConfig.weeklyLoss;

  if (targetCalories < safeMin) {
    targetCalories = safeMin;
    actualDeficit = tdee - safeMin;
    actualWeeklyLoss = (actualDeficit * 7) / 7700;
  }

  return TargetCaloriesResult(
    bmr: bmr,
    tdee: tdee,
    targetCalories: math.max(0, targetCalories),
    dailyDeficit: math.max(0, actualDeficit),
    estimatedWeeklyLoss:
        math.max(0.0, (actualWeeklyLoss * 100).roundToDouble() / 100),
  );
}
