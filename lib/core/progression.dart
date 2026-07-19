import 'dart:math' as math;

/// 升级公式与经验值计算 —— 纯函数实现。
///
/// 对应 web/src/core/progression.ts 与 web/src/store/game-constants.ts 中
/// 的 `XP_BASE` 与 `LEVEL_TITLES` 常量。

// ========== 常量 ==========

/// XP 升级公式基础值。
/// 对应 web/src/store/game-constants.ts 中的 `XP_BASE`。
const int xpBase = 100;

/// 等级称号表（1-15 级）。
/// 对应 web/src/store/game-constants.ts 中的 `LEVEL_TITLES`。
const List<String> levelTitles = [
  '健身新手', '初级勇士', '运动学徒', '减脂先锋', '卡路里猎人',
  '脂肪终结者', '健身达人', '传奇勇士', '神话英雄', '减肥之神',
  '超越者', '永恒战士', '宇宙健身王', '时间主宰', '无限可能',
];

/// 增加经验值的返回结果。
/// 对应 web/src/core/progression.ts 中 `addXp` 的返回值结构。
class AddXpResult {
  /// 新的经验值
  final int xp;

  /// 新的等级
  final int level;

  /// 本次升级级数
  final int levelsGained;

  const AddXpResult({
    required this.xp,
    required this.level,
    required this.levelsGained,
  });
}

// ========== 公式函数 ==========

/// 升到下一级所需的经验值。
/// 公式：`xpBase * 1.15^(level-1)`，向下取整。
/// level <= 0 时按 1 处理（pow 指数为非正数），仍返回正整数。
int getXpToNextLevel(num level) {
  final safeLevel = level.isFinite ? level.toInt() : 1;
  return (xpBase * math.pow(1.15, safeLevel - 1)).floor();
}

/// 根据等级返回称号。
/// 等级 <= 0 返回首个称号；等级超出称号表范围返回最后一个称号。
String getLevelTitle(num level) {
  final levelInt = level.toInt();
  if (levelInt <= 0) return levelTitles[0];
  if (levelInt > levelTitles.length) return levelTitles[levelTitles.length - 1];
  return levelTitles[levelInt - 1];
}

/// 增加经验值并处理连续升级。
///
/// [currentXp] 当前等级内的经验值
/// [currentLevel] 当前等级（< 1 时按 1 处理）
/// [amount] 增加的经验值（可为负，但 XP 不会降至 0 以下）
/// 返回新的经验值、等级、本次升级级数。
///
/// 注意：本函数不处理降级；XP 下限为 0。升级阈值 <= 0 时终止以防死循环。
AddXpResult addXp(num currentXp, num currentLevel, num amount) {
  var xp = math.max(0, (currentXp + amount).floor());
  var level = math.max(1, currentLevel.floor());
  var levelsGained = 0;

  var guard = 0;
  while (guard < 1000) {
    final need = getXpToNextLevel(level);
    if (need <= 0 || xp < need) break;
    xp -= need;
    level += 1;
    levelsGained += 1;
    guard += 1;
  }

  return AddXpResult(xp: xp, level: level, levelsGained: levelsGained);
}

/// 计算 BMI。
/// [weight] 体重 (kg)
/// [height] 身高 (cm)
/// 返回 BMI 值（保留 1 位小数）；身高 <= 0 时返回 0。
double calculateBmi(num weight, num height) {
  if (height <= 0) return 0;
  final h = height.toDouble() / 100;
  final bmi = weight.toDouble() / (h * h);
  // 保留 1 位小数：四舍五入到 1 位
  return (bmi * 10).roundToDouble() / 10;
}
