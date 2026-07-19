import '../constants/app_constants.dart';
import 'core_types.dart';

/// 难度调整引擎 —— 纯函数实现。
///
/// 对应 web/src/core/difficulty.ts（提取自 web/src/lib/difficultyEngine.ts）。

/// 计算最近 3 天的运动完成率
/// （提取自 `lib/difficultyEngine.getLast3DaysCompletionRate`）。
///
/// 规则：
/// - 无数据或空天数 → 0.5
/// - 按日期降序取最近 3 天
/// - 完成率 = 有运动记录（exercise > 0）的天数 / 取出的天数
double getLast3DaysCompletionRate(WeeklyData? weeklyData) {
  if (weeklyData == null || weeklyData.days.isEmpty) {
    return 0.5;
  }

  final sortedDays = weeklyData.days
      .where((d) => d.date.isNotEmpty)
      .toList()
    ..sort((a, b) => DateTime.parse(b.date).millisecondsSinceEpoch
        .compareTo(DateTime.parse(a.date).millisecondsSinceEpoch));

  final last3 = sortedDays.take(3).toList();
  if (last3.isEmpty) return 0.5;

  var completed = 0;
  for (final day in last3) {
    if (day.exercise != null && day.exercise! > 0) {
      completed++;
    }
  }

  return completed / last3.length;
}

/// 分析用户最近运动数据，返回难度调整建议
/// （提取自 `lib/difficultyEngine.analyzeUserPerformance`）。
///
/// 难度调整是渐进的，避免一天之内剧烈变化：
/// - streak >= 14 → 困难，HP 倍率 1.5
/// - 完成率 > 0.8 且 streak >= 5 → 提升，HP 倍率 1.2
/// - 完成率 < 0.5 → 简单，HP 倍率 0.7
/// - BMI > 28 强制简单；BMI < 22 且完成率高时强制困难
/// - 最终倍率限制在安全范围（HP: 0.5-1.5，任务: 0.7-1.3）
DifficultyAdvice analyzeUserPerformance(
  WeeklyData? weeklyData,
  int currentStreak,
  Difficulty currentDifficulty,
  double bmi,
) {
  final completionRate = getLast3DaysCompletionRate(weeklyData);

  var monsterHpMultiplier = 1.0;
  var questTargetAdjustment = 1.0;
  var suggestedDifficulty = currentDifficulty;
  var message = '主人~ 今天也要加油哦！我会一直陪着你的！';

  // 连续两周最高优先级
  if (currentStreak >= 14) {
    monsterHpMultiplier = 1.5;
    questTargetAdjustment = 1.2;
    suggestedDifficulty = Difficulty.hard;
    message = '连续两周了！你已经是健身大师啦！太厉害了主人！';
  } else if (completionRate > 0.8 && currentStreak >= 5) {
    monsterHpMultiplier = 1.2;
    questTargetAdjustment = 1.1;
    suggestedDifficulty = currentStreak >= 7 ? Difficulty.hard : Difficulty.normal;
    message = '主人好厉害！要不要挑战更高难度？我会为你加油的！';
  } else if (completionRate < 0.5) {
    monsterHpMultiplier = 0.7;
    questTargetAdjustment = 0.7;
    suggestedDifficulty = Difficulty.easy;
    message = '主人~ 最近有点累吗？我帮你调低难度啦，休息好再继续哦！';
  }

  // BMI 相关建议
  if (bmi > 28) {
    if (suggestedDifficulty != Difficulty.easy) {
      suggestedDifficulty = Difficulty.easy;
      if (completionRate >= 0.5) {
        message = '主人~ 健康第一，我们先从轻松模式开始吧！慢慢来，你是最棒的！';
      }
    }
  } else if (bmi < 22 && completionRate > 0.8) {
    if (suggestedDifficulty != Difficulty.hard) {
      suggestedDifficulty = Difficulty.hard;
      message = '主人身材好棒！来试试困难模式吧，你绝对可以的！';
    }
  }

  // 渐进保护：确保倍率在安全范围内，避免剧烈变化
  monsterHpMultiplier = monsterHpMultiplier.clamp(0.5, 1.5);
  questTargetAdjustment = questTargetAdjustment.clamp(0.7, 1.3);

  return DifficultyAdvice(
    monsterHpMultiplier: monsterHpMultiplier,
    questTargetAdjustment: questTargetAdjustment,
    suggestedDifficulty: suggestedDifficulty,
    message: message,
  );
}
