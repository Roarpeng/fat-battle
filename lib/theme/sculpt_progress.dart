/// 雕刻进度：维纳斯 / 大卫两条线，同一 0–7 阶梯。
///
/// **未完成作品（sculpt）**：0 粘土 → 1 石块 → 2 粗坯 → 3 成形 → 4 杰作。
/// 建档按身体数据给 floor，再靠结算次数走向 4；只升不降。
///
/// **已是作品（maintenance）**：不再往 4 之后继续凿，只在
/// 5 保养 / 6 蒙尘 / 7 回潮 之间切换。从蒙尘/回潮恢复训练回到保养，
/// 不掉回粘土（除非新建角色）。回潮是粘土覆在雕像上，不是重置杰作。
library;

import '../constants/app_constants.dart';
import '../core/core_types.dart';

/// 雕塑线：女维纳斯 / 男大卫。`other` 自选，默认维纳斯。
enum SculptLine { venus, david }

extension SculptLineX on SculptLine {
  String get folder => name;

  String get label => this == SculptLine.david ? '大卫' : '维纳斯';
}

SculptLine sculptLineFromName(String? raw, {SculptLine fallback = SculptLine.venus}) {
  switch (raw) {
    case 'david':
      return SculptLine.david;
    case 'venus':
      return SculptLine.venus;
    default:
      return fallback;
  }
}

/// 男→大卫，女→维纳斯，其他用一次选择（默认维纳斯）。
SculptLine sculptLineFor({
  required Gender gender,
  SculptLine? chosen,
}) {
  switch (gender) {
    case Gender.male:
      return SculptLine.david;
    case Gender.female:
      return SculptLine.venus;
    case Gender.other:
      return chosen ?? SculptLine.venus;
  }
}

const sculptStageFileStems = <String>[
  '0-clay',
  '1-block',
  '2-rough',
  '3-emerge',
  '4-master',
  '5-polish',
  '6-dust',
  '7-rebound',
];

const sculptStageLabels = <String>[
  '粘土',
  '石块',
  '粗坯',
  '成形',
  '杰作',
  '保养',
  '蒙尘',
  '回潮',
];

/// 兼容旧测试/调用：五阶段关键帧路径（维纳斯 0–4）。
const sculptStageAssetPaths = <String>[
  'assets/branding/sculpt/venus/0-clay.png',
  'assets/branding/sculpt/venus/1-block.png',
  'assets/branding/sculpt/venus/2-rough.png',
  'assets/branding/sculpt/venus/3-emerge.png',
  'assets/branding/sculpt/venus/4-master.png',
];

String sculptAssetPath({
  required SculptLine line,
  required int stage,
}) {
  final s = stage.clamp(0, 7);
  return 'assets/branding/sculpt/${line.folder}/${sculptStageFileStems[s]}.png';
}

/// 等级 → 0..100 质量分（无等级按中性 50）。
int qualityScoreForGrade(String? grade) {
  switch ((grade ?? '').toUpperCase()) {
    case 'S':
      return 92;
    case 'A':
      return 80;
    case 'B':
      return 68;
    case 'C':
      return 55;
    case 'D':
      return 35;
    default:
      return 50;
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

/// 建档 floor 对应的“已等效结算次数”，再叠加真实结算走向 4。
int sculptSettlementsForFloor(int floor) {
  switch (floor.clamp(0, 4)) {
    case 0:
      return 0;
    case 1:
      return 3;
    case 2:
      return 10;
    case 3:
      return 21;
    default:
      return 30;
  }
}

/// 由结算次数与平均质量算出 0..1 进度（对应阶段 0–4）。不含“只升不降”。
double sculptProgressFromSettlements({
  required int settledCount,
  required double averageQuality,
  int floor = 0,
}) {
  final n = sculptSettlementsForFloor(floor) + settledCount;
  if (n <= 0) return 0;
  late final double raw;
  if (n < 3) {
    raw = _lerp(0, 0.25, n / 3);
  } else if (n < 10) {
    raw = _lerp(0.25, 0.50, (n - 3) / 7);
  } else if (n < 21) {
    raw = _lerp(0.50, 0.75, (n - 10) / 11);
  } else if (n < 30) {
    raw = _lerp(0.75, 0.95, (n - 21) / 9);
  } else {
    raw = averageQuality >= 55 ? 1.0 : 0.92;
  }
  final floorProgress = floor.clamp(0, 4) / 4.0;
  final v = raw < floorProgress ? floorProgress : raw;
  return v.clamp(0.0, 1.0);
}

/// 进度 → 雕刻阶段 0..4（关键帧中心：0 / 0.25 / 0.5 / 0.75 / 1）。
int sculptStageFromProgress(double progress) {
  final p = progress.clamp(0.0, 1.0);
  if (p < 0.125) return 0;
  if (p < 0.375) return 1;
  if (p < 0.625) return 2;
  if (p < 0.875) return 3;
  return 4;
}

/// 交叉淡入用的相邻关键帧（仅 0–4）。
({int low, int high, double t}) sculptCrossfade(double progress) {
  final p = progress.clamp(0.0, 1.0);
  final x = p * 4;
  final low = x.floor().clamp(0, 4);
  final high = x.ceil().clamp(0, 4);
  return (low: low, high: high, t: (x - low).clamp(0.0, 1.0));
}

/// 建档起点：floor 0–4；floor==4 时立刻进入 maintenance。
class SculptOnboarding {
  final int floor;
  final bool maintenance;

  const SculptOnboarding({
    required this.floor,
    required this.maintenance,
  });
}

double sculptBmi(double weightKg, double heightCm) {
  if (heightCm <= 0) return 0;
  final m = heightCm / 100.0;
  return weightKg / (m * m);
}

/// 由建档身体数据决定起点。偏瘦不当粘土；素质很好直接杰作并进维护。
SculptOnboarding sculptOnboardingFromBody({
  required double heightCm,
  required double weightKg,
  required double targetWeightKg,
  required int weeklyFreq,
  required int pushupCount,
  required int runDuration,
  required WorkType workType,
  double? bmi,
}) {
  final bmiVal = bmi ?? sculptBmi(weightKg, heightCm);
  final gap = weightKg - targetWeightKg;
  final nearTarget = targetWeightKg > 0 &&
      (weightKg - targetWeightKg).abs() / targetWeightKg <= 0.03;
  final highOutput = pushupCount >= 20 || runDuration >= 25;
  final excellent = bmiVal >= 18.5 &&
      bmiVal < 24 &&
      nearTarget &&
      weeklyFreq >= 4 &&
      (workType != WorkType.sedentary || highOutput);
  if (excellent) {
    return const SculptOnboarding(floor: 4, maintenance: true);
  }

  final trained = weeklyFreq >= 3 && (pushupCount >= 12 || runDuration >= 20);
  if (bmiVal < 18.5) {
    return SculptOnboarding(floor: trained ? 3 : 2, maintenance: false);
  }

  if (bmiVal >= 28 || gap >= 15) {
    return const SculptOnboarding(floor: 0, maintenance: false);
  }
  if (bmiVal >= 24 && bmiVal < 28) {
    return const SculptOnboarding(floor: 1, maintenance: false);
  }
  if (gap >= 8 && gap < 15 && bmiVal >= 24) {
    return const SculptOnboarding(floor: 1, maintenance: false);
  }

  final lowTraining = workType == WorkType.sedentary ||
      weeklyFreq <= 2 ||
      pushupCount <= 8;
  if (bmiVal >= 18.5 && bmiVal < 24 && lowTraining) {
    return const SculptOnboarding(floor: 2, maintenance: false);
  }
  if (bmiVal >= 18.5 && bmiVal < 24) {
    return const SculptOnboarding(floor: 3, maintenance: false);
  }
  return const SculptOnboarding(floor: 1, maintenance: false);
}

int sculptDaysSince({
  required String lastSettledDate,
  required String today,
}) {
  if (lastSettledDate.isEmpty || today.isEmpty) return 0;
  final a = DateTime.tryParse(lastSettledDate);
  final b = DateTime.tryParse(today);
  if (a == null || b == null) return 0;
  return b.difference(a).inDays;
}

/// 近几条体重整体上扬（末条比窗口首条高 ≥ 0.5kg）。
bool sculptWeightTrendingUp(List<({double weight})> recent) {
  if (recent.length < 2) return false;
  final window = recent.length >= 3 ? recent.sublist(recent.length - 3) : recent;
  return window.last.weight - window.first.weight >= 0.5;
}

/// 维护阶段：3 天内有结算且未反复暴食 → 5；4–10 天没练 → 6；
/// 体重上扬 / 反复暴食(≥2) / 超过 10 天没练 → 7。
int evaluateSculptMaintenanceStage({
  required int daysSinceSettlement,
  required int overeatSinceSettle,
  required bool weightTrendingUp,
}) {
  if (weightTrendingUp ||
      overeatSinceSettle >= 2 ||
      daysSinceSettlement > 10) {
    return 7;
  }
  if (daysSinceSettlement >= 4) return 6;
  return 5;
}
