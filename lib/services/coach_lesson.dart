import '../constants/app_constants.dart';
import '../core/core_types.dart';
import '../core/damage.dart';
import '../models/game_models.dart';
import 'coach_feel.dart';
import 'coach_injury.dart';
import 'exercise_prescription.dart';

/// 摄像头动作 type → 克制三角类别。
///
/// 对齐 web `EXERCISE_CATEGORY`，并补上 Flutter 独有的 `jumping_jack`。
ExerciseCategory categoryOfExercise(String type) {
  switch (type) {
    case 'running':
    case 'swimming':
    case 'cycling':
    case 'jumprope':
    case 'walking':
    case 'highknee':
    case 'jumping_jack':
      return ExerciseCategory.cardio;
    case 'squat':
    case 'pushup':
    case 'burpee':
    case 'lunge':
    case 'strength':
      return ExerciseCategory.strength;
    case 'plank':
    case 'yoga':
    case 'hiit':
    case 'mountainclimber':
      return ExerciseCategory.core;
    default:
      return ExerciseCategory.cardio;
  }
}

/// 克制三角：cardio→strength→core→cardio。
/// 返回能克制该怪物属性的运动类别。
ExerciseCategory counterCategoryOf(ExerciseCategory monsterAffinity) {
  switch (monsterAffinity) {
    case ExerciseCategory.strength:
      return ExerciseCategory.cardio;
    case ExerciseCategory.core:
      return ExerciseCategory.strength;
    case ExerciseCategory.cardio:
      return ExerciseCategory.core;
  }
}

String categoryLabel(ExerciseCategory c) => switch (c) {
      ExerciseCategory.cardio => '有氧',
      ExerciseCategory.strength => '力量',
      ExerciseCategory.core => '核心',
    };

String counterLessonSubtitle(ExerciseCategory monsterAffinity) {
  final counter = counterCategoryOf(monsterAffinity);
  return '${categoryLabel(counter)}破${categoryLabel(monsterAffinity)}';
}

/// 克制该属性时应优先挑选的摄像头动作（保序）。
List<String> counterCameraTypes(ExerciseCategory monsterAffinity) {
  switch (counterCategoryOf(monsterAffinity)) {
    case ExerciseCategory.cardio:
      return const ['jumping_jack', 'highknee', 'burpee'];
    case ExerciseCategory.strength:
      return const ['pushup', 'squat', 'lunge', 'burpee'];
    case ExerciseCategory.core:
      return const ['plank', 'mountainclimber', 'lunge'];
  }
}

/// Flutter 舞台怪按索引循环属性（对齐 core 小怪：史莱姆 core / 哥布林 cardio / 幽灵 strength）。
ExerciseCategory affinityForMonsterIndex(int index) {
  const cycle = [
    ExerciseCategory.core,
    ExerciseCategory.cardio,
    ExerciseCategory.strength,
  ];
  if (index < 0) return ExerciseCategory.core;
  return cycle[index % cycle.length];
}

/// 今日一课：用怪物克制 + 锻炼偏好 + 伤病过滤 + 手感量档，生成默认摄像头组合。
class CoachLesson {
  CoachLesson._();

  static WorkoutPlan recommendToday({
    required User user,
    WorkoutFocus focus = WorkoutFocus.mixed,
    ExerciseCategory? monsterAffinity,
    InjuryFlags injury = const InjuryFlags(),
    int feelNudge = 0,
    int targetBurnCal = 0,
    int streak = 0,
  }) {
    final scale = volumeScaleForNudge(feelNudge);
    final banned = injury.excludedTypes;
    final prefer = monsterAffinity == null
        ? const <String>[]
        : counterCameraTypes(monsterAffinity);

    var plan = ExercisePrescription.recommendCombo(
      user,
      focus: focus,
      targetBurnCal: targetBurnCal,
      streak: streak,
      excludeTypes: banned,
      preferTypes: prefer,
      volumeScale: scale,
    );

    plan = _ensureCameraOnly(plan, banned);
    plan = _scaleIfNeeded(plan, scale);

    final title = monsterAffinity == null
        ? '今日塑形课 · ${focus.label}'
        : '今日克制课 · ${counterLessonSubtitle(monsterAffinity)}';
    final reason = _lessonReason(
      focus: focus,
      affinity: monsterAffinity,
      injury: injury,
      feelNudge: feelNudge,
      baseReason: plan.reason,
    );

    return WorkoutPlan(
      items: plan.items,
      title: title,
      reason: reason,
      estimatedMinutes: plan.estimatedMinutes,
      level: plan.level,
      targetBurnCal: plan.targetBurnCal,
      restSeconds: plan.restSeconds,
    );
  }

  static WorkoutPlan _ensureCameraOnly(WorkoutPlan plan, Set<String> banned) {
    final kept = plan.items
        .where(
          (it) =>
              it.exercise.supportCamera &&
              !banned.contains(it.exercise.type),
        )
        .toList(growable: false);
    if (kept.length == plan.items.length) return plan;
    return WorkoutPlan(
      items: kept,
      title: plan.title,
      reason: plan.reason,
      estimatedMinutes: plan.estimatedMinutes,
      level: plan.level,
      targetBurnCal: plan.targetBurnCal,
      restSeconds: plan.restSeconds,
    );
  }

  static WorkoutPlan _scaleIfNeeded(WorkoutPlan plan, double scale) {
    if ((scale - 1.0).abs() < 0.001) return plan;
    final items = plan.items
        .map(
          (it) => WorkoutPlanItem(
            exerciseIndex: it.exerciseIndex,
            target: (it.target * scale).round().clamp(6, 80),
            isTimed: it.isTimed,
          ),
        )
        .toList(growable: false);
    final minutes =
        (plan.estimatedMinutes * scale).round().clamp(5, 45);
    return WorkoutPlan(
      items: items,
      title: plan.title,
      reason: plan.reason,
      estimatedMinutes: minutes,
      level: plan.level,
      targetBurnCal: plan.targetBurnCal,
      restSeconds: plan.restSeconds,
    );
  }

  static String _lessonReason({
    required WorkoutFocus focus,
    required ExerciseCategory? affinity,
    required InjuryFlags injury,
    required int feelNudge,
    required String baseReason,
  }) {
    final parts = <String>[];
    if (affinity != null) {
      parts.add('针对${categoryLabel(affinity)}型怪物');
      parts.add(counterLessonSubtitle(affinity));
    }
    parts.add('偏好「${focus.label}」');
    if (injury.kneeIssue) parts.add('已避开屈膝动作');
    if (injury.waistIssue) parts.add('已避开腰腹屈曲');
    if (feelNudge > 0) parts.add('手感偏轻松→加量');
    if (feelNudge < 0) parts.add('手感偏累→减量');
    if (parts.isEmpty) return baseReason;
    return parts.join(' · ');
  }
}

/// 判断该动作相对怪物是否克制（供结算标签）。
DamageEffectiveness counterEffectiveness({
  required String exerciseType,
  required ExerciseCategory monsterAffinity,
}) {
  return calculateDamageWithCounter(
    0,
    100,
    Difficulty.normal,
    categoryOfExercise(exerciseType),
    monsterAffinity,
  ).effectiveness;
}
