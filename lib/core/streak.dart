import 'dart:math' as math;

/// 连续打卡相关纯判定函数（整合自 `store/slices/progressSlice`）。
///
/// 对应 web/src/core/streak.ts。
///
/// 这些函数从 progressSlice 的副作用方法中提取核心判定逻辑，
/// 不依赖 store 状态，便于双端复用。

/// 判断两个日期字符串（YYYY-MM-DD）是否连续（prevDate 是 today 的前一天）。
/// 跨月、跨年边界正确处理。
bool isConsecutiveDay(String prevDate, String today) {
  if (prevDate.isEmpty || today.isEmpty) return false;

  DateTime todayDate;
  try {
    todayDate = DateTime.parse(today);
  } catch (_) {
    // 解析失败视为非连续（对齐 TS 的 isNaN(todayDate.getTime()) 检查）
    return false;
  }

  final yesterday = todayDate.subtract(const Duration(days: 1));
  final yesterdayStr =
      '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  return prevDate == yesterdayStr;
}

/// 判断是否应在 streak 增加后授予 streak shield。
/// 规则（提取自 `incrementStreak`）：新 streak > 0 且为 7 的倍数，且当前没有 shield。
bool shouldGrantStreakShield(int newStreak, bool hasShield) {
  return newStreak > 0 && newStreak % 7 == 0 && !hasShield;
}

/// 判断是否可以使用 streak freeze。
/// 规则（提取自 `useStreakFreeze`）：freeze 数量 > 0 且 freeze 提示处于激活状态。
bool canUseStreakFreeze(int streakFreezeCount, bool isPromptActive) {
  return streakFreezeCount > 0 && isPromptActive;
}

/// 判断是否可以购买 streak freeze。
/// 规则（提取自 `buyStreakFreeze`）：当前 freeze < 3 且金币 >= 50。
bool canBuyStreakFreeze(int streakFreezeCount, int coins) {
  return streakFreezeCount < 3 && coins >= 50;
}

/// 判断是否应在今日补充 streak freeze。
/// 规则（提取自 `resetDailyIfNeeded`）：今天是周一（getDay() === 1）且今日尚未补充过。
///
/// 注意：[todayDayOfWeek] 遵循 JS `Date.getDay()` 约定，0=周日，1=周一，...，6=周六。
bool shouldRefillStreakFreeze(
  int todayDayOfWeek,
  String lastFreezeRefillDate,
  String today,
) {
  return todayDayOfWeek == 1 && lastFreezeRefillDate != today;
}

/// 计算 freeze 补充后的数量。
/// 规则：当前数量 + 1，上限为 maxCount（默认 2）。
int refillStreakFreeze(int currentCount, [int maxCount = 2]) {
  return math.min(currentCount + 1, maxCount);
}

/// 判断 streak 是否应被重置为 0。
///
/// 规则（提取自 `resetDailyIfNeeded`）：日期不连续，且 streak > 0，
/// 且无 shield 保护，且无可用 freeze。
///
/// 注意：当 freeze 可用时，streak 不立即重置（等待用户决定是否使用 freeze）。
bool shouldResetStreak(
  bool isConsecutive,
  int currentStreak,
  bool hasShield,
  int streakFreezeCount,
) {
  if (isConsecutive || currentStreak <= 0) return false;
  if (hasShield) return false;
  if (streakFreezeCount > 0) return false;
  return true;
}
