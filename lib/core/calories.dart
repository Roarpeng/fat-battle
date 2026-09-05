import 'dart:math' as math;
import 'core_types.dart';

/// BMR / TDEE / 目标卡路里计算 —— 纯函数实现。
///
/// 对应 web/src/core/calories.ts（双端已对齐：性别下限 + BMR 热量下限，日赤字上限 750）。

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
const Map<Gender, int> safeMinCaloriesByGender = {
  Gender.male: 1500,
  Gender.female: 1200,
  Gender.other: 1500,
};

/// 每日赤字上限（kcal）。困难模式允许到 750，默认减脂 500。
const int kMaxDailyDeficitKcal = 750;
const int kDefaultDailyDeficitKcal = 500;
const int kMildDailyDeficitKcal = 250;

/// 档案未记录性别时的保守下限（取男性下限，避免建议过低摄入）。
const int defaultCalorieFloor = 1500;

/// 返回该性别的全日安全摄入下限。
int safeMinCalories(Gender gender) =>
    safeMinCaloriesByGender[gender] ?? defaultCalorieFloor;

/// 减重目标配置。
/// 对应 web/src/core/calories.ts 中的 `GOAL_CONFIGS`。
class _GoalConfig {
  final int dailyDeficit;
  final double weeklyLoss;
  const _GoalConfig({required this.dailyDeficit, required this.weeklyLoss});
}

const Map<CaloriesGoal, _GoalConfig> _goalConfigs = {
  CaloriesGoal.mildLoss:
      _GoalConfig(dailyDeficit: kMildDailyDeficitKcal, weeklyLoss: 0.25),
  CaloriesGoal.loss:
      _GoalConfig(dailyDeficit: kDefaultDailyDeficitKcal, weeklyLoss: 0.5),
  CaloriesGoal.extremeLoss:
      _GoalConfig(dailyDeficit: kMaxDailyDeficitKcal, weeklyLoss: 0.75),
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

  /// 实际每日赤字（受安全下限与赤字上限影响）
  final int dailyDeficit;

  /// 预计每周减重 (kg)
  final double estimatedWeeklyLoss;

  /// 实际采用的热量下限 = max(性别下限, BMR)
  final int calorieFloor;

  const TargetCaloriesResult({
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
    required this.dailyDeficit,
    required this.estimatedWeeklyLoss,
    required this.calorieFloor,
  });
}

// ========== 计算函数 ==========

/// 性别对应的最低安全摄入。
int safeMinCaloriesFor(Gender gender) => safeMinCalories(gender);

/// 热量下限：max(1200 女 / 1500 男, BMR)，永不低于该值生成目标。
int calorieFloorFor({required Gender gender, required int bmr}) {
  return math.max(safeMinCaloriesFor(gender), math.max(0, bmr));
}

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

/// 将计划赤字限制在 [0, kMaxDailyDeficitKcal]。
int capDailyDeficit(num deficit) {
  return math.max(0, math.min(kMaxDailyDeficitKcal, deficit.round()));
}

/// 计算目标卡路里摄入，结合减重目标、赤字上限与安全下限。
///
/// [gender] 性别
/// [weightKg] 体重 (kg)
/// [heightCm] 身高 (cm)
/// [age] 年龄（岁）
/// [activityLevel] 活动水平
/// [goal] 减重目标，默认 `CaloriesGoal.loss`
///
/// 规则：
/// - 日赤字上限 750 kcal（extremeLoss），默认 500，温和 250。
/// - 目标 = max(热量下限, TDEE − 赤字)；热量下限 = max(性别下限, BMR)。
/// - 永不生成低于下限的目标。
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
  final floor = calorieFloorFor(gender: gender, bmr: bmr);

  var desiredDeficit = capDailyDeficit(goalConfig.dailyDeficit);
  var targetCalories = tdee - desiredDeficit;

  if (targetCalories < floor) {
    targetCalories = floor;
  }

  var actualDeficit = math.max(0, tdee - targetCalories);
  actualDeficit = capDailyDeficit(actualDeficit);
  targetCalories = math.max(floor, tdee - actualDeficit);

  final actualWeeklyLoss = (actualDeficit * 7) / 7700;

  return TargetCaloriesResult(
    bmr: bmr,
    tdee: tdee,
    targetCalories: math.max(floor, targetCalories),
    dailyDeficit: math.max(0, actualDeficit),
    estimatedWeeklyLoss:
        math.max(0.0, (actualWeeklyLoss * 100).roundToDouble() / 100),
    calorieFloor: floor,
  );
}
