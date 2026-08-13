/// 塑身安全规则：热量下限危机、战斗奖励衰减、求助文案。
///
/// 纯函数，不依赖 Flutter / SharedPreferences。
library;

/// 连续极端赤字达到该天数后：降低战斗奖励、停止成就、展示求助文案。
const int kExtremeDeficitDaysThreshold = 7;

/// 危机状态下的战斗奖励 / 伤害倍率。
const double kExtremeDeficitRewardMultiplier = 0.5;

/// 北京心理危机研究与干预中心热线（https://www.crisis.org.cn/lists/5.html）。
const String kCrisisHotlineBeijing1 = '800-810-1117';
const String kCrisisHotlineBeijing2 = '010-82951332';
const String kCrisisOrgUrl = 'https://www.crisis.org.cn/lists/5.html';

/// 首次使用医疗免责声明的本地存储 key。
const String kMedicalDisclaimerPrefKey = 'medical_disclaimer_accepted';

/// 当日是否算「极端赤字」：有活动记录，且摄入低于热量安全下限。
bool wasExtremeDeficitDay({
  required int intake,
  required int calorieFloor,
  required bool hadActivity,
}) {
  if (!hadActivity) return false;
  return intake < calorieFloor;
}

/// 根据昨日是否极端赤字，更新连续天数。
int nextExtremeDeficitStreak({
  required int currentStreak,
  required bool yesterdayWasExtreme,
}) {
  if (yesterdayWasExtreme) return currentStreak + 1;
  return 0;
}

/// 是否处于连续极端赤字危机。
bool isExtremeDeficitCrisis(int consecutiveDays) {
  return consecutiveDays >= kExtremeDeficitDaysThreshold;
}

/// 危机时降低战斗奖励与伤害；未达阈值则为 1.0。
double extremeDeficitCombatMultiplier(int consecutiveDays) {
  return isExtremeDeficitCrisis(consecutiveDays)
      ? kExtremeDeficitRewardMultiplier
      : 1.0;
}

/// 危机求助文案（不含羞耻用语）。
String extremeDeficitHelpCopy() {
  return '连续多日摄入低于安全下限。请先吃够、好好休息，身体比战斗更重要。\n'
      '如需帮助，可联系北京心理危机研究与干预中心：\n'
      '$kCrisisHotlineBeijing1 / $kCrisisHotlineBeijing2\n'
      '$kCrisisOrgUrl';
}
