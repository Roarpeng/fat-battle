import 'dart:math' as math;

import 'core_types.dart';

/// 运动质量评分共享层 —— 纯函数实现，为 poseService 集成做准备。
///
/// 基于角度（深度）、稳定性（晃动）、节奏（速度）、对称性（左右平衡）四个维度
/// 综合评估单次动作质量，输出总分、等级、伤害加成与改进建议。
///
/// 所有函数均为纯函数：无副作用、不依赖外部状态、相同输入产生相同输出。
/// 对应 Web 端 `web/src/core/exercise-quality.ts`。

// ============================================================
// 类型定义
// ============================================================

/// 运动质量等级。
/// 对应 web/src/core/exercise-quality.ts 中的 `QualityGrade`。
enum QualityGrade { perfect, good, fair, poor }

/// 质量评分结果。
/// 对应 web/src/core/exercise-quality.ts 中的 `QualityScore`。
class QualityScore {
  /// 总分 0-100
  final double total;

  /// 等级
  final QualityGrade grade;

  /// 动作深度 0-100（幅度是否到位）
  final double depth;

  /// 稳定性 0-100（是否晃动）
  final double stability;

  /// 节奏 0-100（速度是否合适）
  final double tempo;

  /// 对称性 0-100（左右是否平衡）
  final double symmetry;

  /// 改进建议
  final List<String> feedback;

  /// 伤害加成 0.8~1.5
  final double damageBonus;

  const QualityScore({
    required this.total,
    required this.grade,
    required this.depth,
    required this.stability,
    required this.tempo,
    required this.symmetry,
    required this.feedback,
    required this.damageBonus,
  });

  QualityScore copyWith({
    double? total,
    QualityGrade? grade,
    double? depth,
    double? stability,
    double? tempo,
    double? symmetry,
    List<String>? feedback,
    double? damageBonus,
  }) {
    return QualityScore(
      total: total ?? this.total,
      grade: grade ?? this.grade,
      depth: depth ?? this.depth,
      stability: stability ?? this.stability,
      tempo: tempo ?? this.tempo,
      symmetry: symmetry ?? this.symmetry,
      feedback: feedback ?? this.feedback,
      damageBonus: damageBonus ?? this.damageBonus,
    );
  }
}

/// 评分维度数据。
/// 对应 web/src/core/exercise-quality.ts 中的 `QualityMetrics`。
class QualityMetrics {
  /// 运动类型
  final PoseExerciseType exerciseType;

  /// 主要关节角度（如深蹲的膝盖角度）
  final double primaryAngle;

  /// 目标深度角度
  final double targetAngleDeep;

  /// 目标起始角度
  final double targetAngleShallow;

  /// 左侧角度（可选，用于对称性评分）
  final double? leftAngle;

  /// 右侧角度（可选，用于对称性评分）
  final double? rightAngle;

  /// 本次动作耗时（毫秒，可选）
  final double? repDurationMs;

  /// 目标耗时（毫秒，可选）
  final double? targetDurationMs;

  /// 晃动次数（可选，用于稳定性评分）
  final double? wobbleCount;

  const QualityMetrics({
    required this.exerciseType,
    required this.primaryAngle,
    required this.targetAngleDeep,
    required this.targetAngleShallow,
    this.leftAngle,
    this.rightAngle,
    this.repDurationMs,
    this.targetDurationMs,
    this.wobbleCount,
  });

  QualityMetrics copyWith({
    PoseExerciseType? exerciseType,
    double? primaryAngle,
    double? targetAngleDeep,
    double? targetAngleShallow,
    double? leftAngle,
    double? rightAngle,
    double? repDurationMs,
    double? targetDurationMs,
    double? wobbleCount,
  }) {
    return QualityMetrics(
      exerciseType: exerciseType ?? this.exerciseType,
      primaryAngle: primaryAngle ?? this.primaryAngle,
      targetAngleDeep: targetAngleDeep ?? this.targetAngleDeep,
      targetAngleShallow: targetAngleShallow ?? this.targetAngleShallow,
      leftAngle: leftAngle ?? this.leftAngle,
      rightAngle: rightAngle ?? this.rightAngle,
      repDurationMs: repDurationMs ?? this.repDurationMs,
      targetDurationMs: targetDurationMs ?? this.targetDurationMs,
      wobbleCount: wobbleCount ?? this.wobbleCount,
    );
  }
}

// ============================================================
// 各运动类型评分标准
// ============================================================

/// 单个运动的评分标准。
class ExerciseStandard {
  /// 目标深度角度
  final double targetAngleDeep;

  /// 目标起始角度
  final double targetAngleShallow;

  /// 目标耗时（毫秒）
  final double targetDurationMs;

  /// 描述
  final String description;

  const ExerciseStandard({
    required this.targetAngleDeep,
    required this.targetAngleShallow,
    required this.targetDurationMs,
    required this.description,
  });
}

/// 各运动类型的评分标准。
/// 对应 web/src/core/exercise-quality.ts 中的 `EXERCISE_STANDARDS`。
///
/// 注意：Web 端原名为 `EXERCISE_STANDARDS`（SCREAMING_SNAKE_CASE），
/// Dart 端遵循 lowerCamelCase 命名约定。
const Map<PoseExerciseType, ExerciseStandard> exerciseStandards = {
  PoseExerciseType.squat: ExerciseStandard(
    targetAngleDeep: 70, // 蹲至大腿与地面平行或更低
    targetAngleShallow: 160, // 站直
    targetDurationMs: 2000, // 2秒一个完整动作
    description: '深蹲',
  ),
  PoseExerciseType.pushup: ExerciseStandard(
    targetAngleDeep: 90, // 手肘90度
    targetAngleShallow: 150, // 接近伸直
    targetDurationMs: 1500,
    description: '俯卧撑',
  ),
  PoseExerciseType.jumprope: ExerciseStandard(
    targetAngleDeep: 130, // 落地时膝盖微屈
    targetAngleShallow: 170, // 起跳时接近伸直
    targetDurationMs: 500, // 快速节奏
    description: '跳绳',
  ),
  PoseExerciseType.highknee: ExerciseStandard(
    targetAngleDeep: 90, // 膝盖抬至水平
    targetAngleShallow: 170, // 站立时膝盖微屈
    targetDurationMs: 800,
    description: '高抬腿',
  ),
  PoseExerciseType.plank: ExerciseStandard(
    targetAngleDeep: 180, // 身体直线（髋角 180°）
    targetAngleShallow: 180, // 保持直线（静态动作无行程）
    targetDurationMs: 30000, // 30秒保持为一个计数周期
    description: '平板支撑',
  ),
  PoseExerciseType.burpee: ExerciseStandard(
    targetAngleDeep: 70, // 蹲下时膝盖角度
    targetAngleShallow: 170, // 站立时
    targetDurationMs: 2500, // 复合动作较慢
    description: '波比跳',
  ),
  PoseExerciseType.lunge: ExerciseStandard(
    targetAngleDeep: 90, // 前腿膝盖 90 度
    targetAngleShallow: 170, // 站立时
    targetDurationMs: 2000,
    description: '弓步蹲',
  ),
  PoseExerciseType.mountainclimber: ExerciseStandard(
    targetAngleDeep: 90, // 收腿时膝盖角度
    targetAngleShallow: 160, // 伸展时
    targetDurationMs: 600, // 快速交替
    description: '登山者',
  ),
};

// ============================================================
// 内部常量
// ============================================================

// 各维度权重：深度 40% + 稳定性 25% + 节奏 20% + 对称性 15%
const double _weightDepth = 0.4;
const double _weightStability = 0.25;
const double _weightTempo = 0.2;
const double _weightSymmetry = 0.15;

// 等级对应的伤害加成
const Map<QualityGrade, double> _damageBonus = {
  QualityGrade.perfect: 1.5,
  QualityGrade.good: 1.2,
  QualityGrade.fair: 1.0,
  QualityGrade.poor: 0.8,
};

// ============================================================
// 各维度独立评分函数
// ============================================================

/// 深度评分（0-100）。
///
/// 对于动态动作（shallow ≠ deep）：以从起始角度（shallow）向目标深度角度（deep）
/// 的完成比例评分。分段映射，与设计规约一致：
/// - 100% 深度 → 100
/// - 90% 深度 → 80
/// - 70% 深度 → 50
/// - 0% 深度 → 0
///
/// 对于静态保持型动作（shallow = deep，如平板支撑）：以 primaryAngle 与目标角度
/// 的偏差评分，每偏离 1° 扣 2 分。
double scoreDepth(QualityMetrics metrics) {
  final primaryAngle = metrics.primaryAngle;
  final targetAngleDeep = metrics.targetAngleDeep;
  final targetAngleShallow = metrics.targetAngleShallow;

  if (!primaryAngle.isFinite) return 0;

  final range = targetAngleShallow - targetAngleDeep;

  if (range.abs() < 0.001) {
    // 静态保持型动作：以与目标角度的偏差评分
    final deviation = (primaryAngle - targetAngleDeep).abs();
    return math.max(0.0, math.min(100.0, (100 - deviation * 2).roundToDouble()));
  }

  // 动态动作：完成比例
  final actualDepth = targetAngleShallow - primaryAngle;
  final ratio = actualDepth / range;
  final r = math.max(0.0, math.min(1.0, ratio));

  // 分段线性评分，匹配规约关键点：(100%,100) (90%,80) (70%,50) (0%,0)
  if (r >= 1) return 100;
  if (r >= 0.9) {
    // 90% → 80, 100% → 100
    return (80 + (r - 0.9) * 200).roundToDouble();
  }
  if (r >= 0.7) {
    // 70% → 50, 90% → 80
    return (50 + (r - 0.7) * 150).roundToDouble();
  }
  // 0% → 0, 70% → 50
  return ((r / 0.7) * 50).roundToDouble();
}

/// 稳定性评分（0-100）。
/// - wobbleCount = 0 → 100
/// - wobbleCount = 1 → 80
/// - wobbleCount = 2 → 60
/// - wobbleCount >= 3 → 40
double scoreStability(QualityMetrics metrics) {
  final wobble = metrics.wobbleCount ?? 0;
  if (!wobble.isFinite || wobble <= 0) return 100;
  if (wobble == 1) return 80;
  if (wobble == 2) return 60;
  return 40;
}

/// 节奏评分（0-100）。
/// - 过快（< 50% 目标耗时）→ 40（容易受伤）
/// - 偏离 ≤ 20% → 100
/// - 偏离 20%-40% → 80
/// - 偏离 > 40% → 60
///
/// 缺少耗时数据时返回 100（不惩罚）。
double scoreTempo(QualityMetrics metrics) {
  final repDurationMs = metrics.repDurationMs;
  final targetDurationMs = metrics.targetDurationMs;

  if (repDurationMs == null || targetDurationMs == null || targetDurationMs <= 0) {
    return 100;
  }
  if (!repDurationMs.isFinite || repDurationMs < 0) return 60;

  // 过快判定优先（容易受伤）
  if (repDurationMs < targetDurationMs * 0.5) return 40;

  final deviation = (repDurationMs - targetDurationMs).abs() / targetDurationMs;
  if (deviation <= 0.2) return 100;
  if (deviation <= 0.4) return 80;
  return 60;
}

/// 对称性评分（0-100）。
/// - 左右角度差 < 5° → 100
/// - 差 5°-10° → 80
/// - 差 10°-20° → 60
/// - 差 > 20° → 40
///
/// 缺少左右角度数据时返回 100（不惩罚）。
double scoreSymmetry(QualityMetrics metrics) {
  final leftAngle = metrics.leftAngle;
  final rightAngle = metrics.rightAngle;

  if (leftAngle == null || rightAngle == null) return 100;
  if (!leftAngle.isFinite || !rightAngle.isFinite) return 60;

  final diff = (leftAngle - rightAngle).abs();
  if (diff < 5) return 100;
  if (diff <= 10) return 80;
  if (diff <= 20) return 60;
  return 40;
}

// ============================================================
// 等级与伤害加成
// ============================================================

/// 等级判定。
/// - 90-100: perfect
/// - 75-89: good
/// - 60-74: fair
/// - < 60: poor
QualityGrade gradeFromScore(double score) {
  if (!score.isFinite) return QualityGrade.poor;
  if (score >= 90) return QualityGrade.perfect;
  if (score >= 75) return QualityGrade.good;
  if (score >= 60) return QualityGrade.fair;
  return QualityGrade.poor;
}

/// 伤害加成计算。
/// - perfect: ×1.5
/// - good: ×1.2
/// - fair: ×1.0
/// - poor: ×0.8
double damageBonusFromGrade(QualityGrade grade) {
  return _damageBonus[grade]!;
}

/// 伤害加成倍率别名（与 [damageBonusFromGrade] 等价）。
///
/// 提供此名称是为了对齐产品规约中的命名约定。
/// `getQualityMultiplier(grade)` 返回 1.5 / 1.2 / 1.0 / 0.8。
double getQualityMultiplier(QualityGrade grade) {
  return damageBonusFromGrade(grade);
}

// ============================================================
// 反馈建议
// ============================================================

/// 生成针对性改进建议。
/// 依据各维度评分给出具体提示；当所有维度均良好时返回鼓励语。
List<String> generateFeedback(QualityMetrics metrics, QualityScore score) {
  final feedback = <String>[];
  final std = exerciseStandards[metrics.exerciseType];
  final desc = std?.description ?? '动作';

  if (score.depth < 70) {
    feedback.add('$desc深度不足，请尽量达到目标幅度');
  }
  if (score.stability < 80) {
    feedback.add('身体晃动较大，注意保持核心稳定');
  }
  if (score.tempo < 80) {
    final repDurationMs = metrics.repDurationMs;
    final targetDurationMs = metrics.targetDurationMs;
    final tooFast = repDurationMs != null &&
        targetDurationMs != null &&
        targetDurationMs > 0 &&
        repDurationMs < targetDurationMs * 0.5;
    if (tooFast) {
      feedback.add('动作过快，容易受伤，请放慢节奏');
    } else {
      feedback.add('动作节奏偏离目标，注意控制速度');
    }
  }
  if (score.symmetry < 80) {
    feedback.add('左右两侧不对称，注意保持平衡');
  }

  if (feedback.isEmpty) {
    feedback.add('动作质量优秀，继续保持！');
  }
  return feedback;
}

// ============================================================
// 主评分函数
// ============================================================

/// 主评分函数：综合深度、稳定性、节奏、对称性得出总分与等级。
///
/// 总分 = 深度×40% + 稳定性×25% + 节奏×20% + 对称性×15%。
/// 等级与伤害加成由总分派生，反馈建议由各维度评分派生。
QualityScore scoreExerciseQuality(QualityMetrics metrics) {
  final depth = scoreDepth(metrics);
  final stability = scoreStability(metrics);
  final tempo = scoreTempo(metrics);
  final symmetry = scoreSymmetry(metrics);

  final total = (depth * _weightDepth +
          stability * _weightStability +
          tempo * _weightTempo +
          symmetry * _weightSymmetry)
      .roundToDouble();
  final grade = gradeFromScore(total);
  final damageBonus = damageBonusFromGrade(grade);

  final partial = QualityScore(
    total: total,
    grade: grade,
    depth: depth,
    stability: stability,
    tempo: tempo,
    symmetry: symmetry,
    damageBonus: damageBonus,
    feedback: const [],
  );
  final feedback = generateFeedback(metrics, partial);

  return partial.copyWith(feedback: feedback);
}
