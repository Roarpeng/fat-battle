import 'dart:math' as math;
import 'core_types.dart';

/// 体重趋势分析 —— 纯函数实现。
///
/// 对应 web/src/core/weight.ts。

// ========== 数据类型 ==========

/// 体重记录条目。
///
/// 对应 web/src/core/weight.ts 中的 `WeightRecord`。
/// 命名为 [WeightLogEntry] 以避免与 `lib/models/game_models.dart` 中的
/// `WeightRecord`（字段为 `date` / `weight`）冲突。
class WeightLogEntry {
  /// 日期字符串（YYYY-MM-DD）
  final String date;

  /// 体重 (kg)
  final double weightKg;

  /// 备注（可空）
  final String? note;

  const WeightLogEntry({
    required this.date,
    required this.weightKg,
    this.note,
  });

  WeightLogEntry copyWith({
    String? date,
    double? weightKg,
    String? note,
  }) {
    return WeightLogEntry(
      date: date ?? this.date,
      weightKg: weightKg ?? this.weightKg,
      note: note ?? this.note,
    );
  }
}

/// 体重趋势分析结果。
/// 对应 web/src/core/weight.ts 中的 `WeightTrend`。
class WeightTrend {
  /// 当前体重
  final double currentWeight;

  /// 起始体重
  final double startWeight;

  /// 目标体重
  final double targetWeight;

  /// 总变化量（current - start）
  final double totalChange;

  /// 每周变化量
  final double weeklyChange;

  /// 距离目标还需天数（无法达成时为 [double.infinity]）
  final double daysToTarget;

  /// 进度百分比 (0-100)
  final double progressPercent;

  /// 趋势方向
  final WeightTrendDirection trend;

  const WeightTrend({
    required this.currentWeight,
    required this.startWeight,
    required this.targetWeight,
    required this.totalChange,
    required this.weeklyChange,
    required this.daysToTarget,
    required this.progressPercent,
    required this.trend,
  });
}

// ========== 内部辅助函数 ==========

/// 解析日期字符串为毫秒时间戳。
int _parseDate(String dateStr) {
  return DateTime.parse(dateStr).millisecondsSinceEpoch;
}

/// 按日期升序排序记录（返回新数组，不改原数组）。
List<WeightLogEntry> _sortRecordsByDate(List<WeightLogEntry> records) {
  return [...records]..sort((a, b) => _parseDate(a.date).compareTo(_parseDate(b.date)));
}

/// 计算两个日期字符串之间的天数（至少为 1）。
int _calculateDaysBetween(String startDate, String endDate) {
  final start = _parseDate(startDate);
  final end = _parseDate(endDate);
  final diffMs = end - start;
  return math.max(1, (diffMs / (1000 * 60 * 60 * 24)).round());
}

// ========== 公共纯函数 ==========

/// 检测体重趋势方向（升 / 降 / 稳定）。
///
/// 规则：取最近 7 条记录，比较首尾体重差：
/// - diff > 0.5 → increasing
/// - diff < -0.5 → decreasing
/// - 否则 → stable
WeightTrendDirection detectTrend(List<WeightLogEntry> records) {
  if (records.length < 2) return WeightTrendDirection.stable;

  final sorted = _sortRecordsByDate(records);
  final takeCount = math.min(7, sorted.length);
  final recentRecords = sorted.sublist(sorted.length - takeCount);

  if (recentRecords.length < 2) return WeightTrendDirection.stable;

  final firstWeight = recentRecords[0].weightKg;
  final lastWeight = recentRecords[recentRecords.length - 1].weightKg;
  final diff = lastWeight - firstWeight;

  const threshold = 0.5;

  if (diff > threshold) return WeightTrendDirection.increasing;
  if (diff < -threshold) return WeightTrendDirection.decreasing;
  return WeightTrendDirection.stable;
}

/// 估算距离目标体重还需的天数。
///
/// - 当前体重已 <= 目标 → 0
/// - 周变化率 <= 0 → [double.infinity]（无法达成）
/// - 否则 → 向上取整的周数 × 7
double estimateDaysToTarget(
  num currentWeight,
  num targetWeight,
  num weeklyChangeRate,
) {
  final weightDiff = currentWeight.toDouble() - targetWeight.toDouble();

  if (weightDiff <= 0) return 0;
  if (weeklyChangeRate <= 0) return double.infinity;

  final weeksNeeded = weightDiff / weeklyChangeRate.toDouble();
  return (weeksNeeded * 7).ceilToDouble();
}

/// 计算减重进度百分比 (0-100)。
///
/// - 起始体重已 <= 目标 → 100
/// - 当前体重未下降 → 0
/// - 否则 → (已减 / 应减) × 100，保留 1 位小数
double calculateProgress(
  num startWeight,
  num currentWeight,
  num targetWeight,
) {
  final totalToLose = startWeight.toDouble() - targetWeight.toDouble();
  final alreadyLost = startWeight.toDouble() - currentWeight.toDouble();

  if (totalToLose <= 0) return 100;
  if (alreadyLost <= 0) return 0;

  final progress = (alreadyLost / totalToLose) * 100;
  return math.min(100.0, math.max(0.0, (progress * 10).roundToDouble() / 10));
}

/// 新增或更新体重记录（按日期去重），返回排序后的新列表。
///
/// 若已存在相同日期的记录，则覆盖；否则追加。
List<WeightLogEntry> addWeightRecord(
  List<WeightLogEntry> records,
  WeightLogEntry newRecord,
) {
  final existingIndex = records.indexWhere((r) => r.date == newRecord.date);

  if (existingIndex >= 0) {
    final updated = [...records];
    updated[existingIndex] = newRecord;
    return _sortRecordsByDate(updated);
  }

  return _sortRecordsByDate([...records, newRecord]);
}

/// 综合分析体重趋势。
///
/// [records] 体重记录列表
/// [targetWeight] 目标体重
/// 返回 [WeightTrend]；记录为空时返回 null。
WeightTrend? analyzeWeightTrend(
  List<WeightLogEntry> records,
  num targetWeight,
) {
  if (records.isEmpty) return null;

  final sorted = _sortRecordsByDate(records);
  final startWeight = sorted[0].weightKg;
  final currentWeight = sorted[sorted.length - 1].weightKg;
  final totalChange = currentWeight - startWeight;

  final daysSpan = _calculateDaysBetween(sorted[0].date, sorted[sorted.length - 1].date);
  final weeklyChange = (totalChange / daysSpan) * 7;

  final weeklyLossRate = weeklyChange < 0 ? weeklyChange.abs() : 0.0;
  final daysToTarget =
      estimateDaysToTarget(currentWeight, targetWeight, weeklyLossRate);

  final progressPercent =
      calculateProgress(startWeight, currentWeight, targetWeight);
  final trend = detectTrend(records);

  return WeightTrend(
    currentWeight: currentWeight,
    startWeight: startWeight,
    targetWeight: targetWeight.toDouble(),
    totalChange: (totalChange * 100).roundToDouble() / 100,
    weeklyChange: (weeklyChange * 100).roundToDouble() / 100,
    daysToTarget: daysToTarget,
    progressPercent: progressPercent,
    trend: trend,
  );
}
