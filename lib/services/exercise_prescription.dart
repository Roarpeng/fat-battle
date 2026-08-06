import '../constants/app_constants.dart';
import '../models/game_models.dart';

/// 用户当次选定的锻炼偏好（会话级，不强制改档案）。
enum WorkoutFocus {
  strength, // 力量塑形
  burn, // 燃脂有氧（仅室内可识别动作）
  core, // 核心稳定
  mixed, // 综合
}

extension WorkoutFocusExt on WorkoutFocus {
  String get label {
    switch (this) {
      case WorkoutFocus.strength:
        return '力量';
      case WorkoutFocus.burn:
        return '燃脂';
      case WorkoutFocus.core:
        return '核心';
      case WorkoutFocus.mixed:
        return '综合';
    }
  }

  String get hint {
    switch (this) {
      case WorkoutFocus.strength:
        return '俯卧撑 / 深蹲 / 弓步';
      case WorkoutFocus.burn:
        return '开合跳 / 高抬腿 / 波比（无跑步）';
      case WorkoutFocus.core:
        return '平板 / 登山跑 / 弓步';
      case WorkoutFocus.mixed:
        return '力量 + 燃脂混合';
    }
  }
}

/// 组合内单式目标（次数或秒数）。
class WorkoutPlanItem {
  final int exerciseIndex;

  /// 目标值：次数动作为 reps，平板等为秒。
  final int target;

  /// true = 按秒计时（平板支撑）；false = 按次计数。
  final bool isTimed;

  const WorkoutPlanItem({
    required this.exerciseIndex,
    required this.target,
    required this.isTimed,
  });

  ExerciseType get exercise => Exercises.all[exerciseIndex];

  String get targetLabel =>
      isTimed ? '目标 $target 秒' : '目标 $target 次';
}

/// 一组可摄像头引导的推荐动作（不含跑步/骑行等无法入镜检测的项目）。
class WorkoutPlan {
  final List<WorkoutPlanItem> items;
  final String title;
  final String reason;
  final int estimatedMinutes;

  /// 渐进等级 Lv1-Lv6（随连续打卡天数递增）
  final int level;

  /// 本次训练目标消耗（千卡）
  final int targetBurnCal;

  /// 式间休息秒数
  final int restSeconds;

  const WorkoutPlan({
    required this.items,
    required this.title,
    required this.reason,
    required this.estimatedMinutes,
    this.level = 1,
    this.targetBurnCal = 0,
    this.restSeconds = 15,
  });

  List<int> get exerciseIndexes =>
      items.map((e) => e.exerciseIndex).toList(growable: false);

  List<ExerciseType> get exercises =>
      items.map((e) => e.exercise).toList(growable: false);

  /// 组合平均每分钟消耗（用于预估总时长）
  int get avgCalPerMin {
    if (items.isEmpty) return 8;
    final sum = exercises.fold<int>(0, (a, e) => a + e.calPerMin);
    return (sum / exercises.length).round().clamp(4, 15);
  }

  WorkoutPlanItem? itemAt(int seqIndex) {
    if (seqIndex < 0 || seqIndex >= items.length) return null;
    return items[seqIndex];
  }
}

/// 根据身材、目标体重、体能、今日待消耗卡路里与渐进等级，
/// 生成摄像头可教学的动作组合。
class ExercisePrescription {
  ExercisePrescription._();

  /// 渐进等级 Lv1-Lv6：由连续打卡天数推导，逐步加大训练量。
  /// Lv1-2 新手（3 动作），Lv3-4 进阶（4 动作），Lv5-6 强化（5 动作）。
  static int progressionLevel(int streak) => (1 + streak ~/ 3).clamp(1, 6);

  /// 等级对应的基础燃脂目标（千卡）：逐级递增，避免一上来就过量。
  static int baseBurnGoal(int level) => 90 + level * 35;

  /// 等级对应的动作数量上限
  static int itemCountForLevel(int level) =>
      level <= 2 ? 3 : (level <= 4 ? 4 : 5);

  /// 式间休息：Lv1≈15s，Lv6≈30s
  static int restSecondsForLevel(int level) => (12 + level * 3).clamp(15, 30);

  /// 仅摄像头可识别的动作索引。
  static List<int> cameraExerciseIndexes() {
    final out = <int>[];
    for (var i = 0; i < Exercises.all.length; i++) {
      if (Exercises.all[i].supportCamera) out.add(i);
    }
    return out;
  }

  static int? indexOfType(String type) {
    for (var i = 0; i < Exercises.all.length; i++) {
      if (Exercises.all[i].type == type && Exercises.all[i].supportCamera) {
        return i;
      }
    }
    return null;
  }

  /// 生成推荐组合（全部 supportCamera）。
  ///
  /// - [targetBurnCal]：今日还需要消耗的卡路里（>0 时按它反推训练时长；
  ///   为 0 时按渐进等级给基础目标）。
  /// - [streak]：连续打卡天数，用于推导渐进等级。
  static WorkoutPlan recommendCombo(
    User user, {
    WorkoutFocus focus = WorkoutFocus.mixed,
    int maxItems = 5,
    int targetBurnCal = 0,
    int streak = 0,
  }) {
    final bmi = _bmiOf(user);
    final toLose = user.weight - user.targetWeight; // >0 需减重
    final level = progressionLevel(streak);
    final itemCount = itemCountForLevel(level).clamp(3, maxItems);
    final pool = _poolFor(
      focus: focus,
      bmi: bmi,
      user: user,
      toLose: toLose,
      level: level,
    );

    final picked = <int>[];
    for (final type in pool) {
      final idx = indexOfType(type);
      if (idx == null) continue;
      if (picked.contains(idx)) continue;
      picked.add(idx);
      if (picked.length >= itemCount) break;
    }

    // 保底：至少塞满可识别基础三项
    for (final fallback in const ['squat', 'pushup', 'plank', 'lunge']) {
      if (picked.length >= itemCount.clamp(3, 5)) break;
      final idx = indexOfType(fallback);
      if (idx != null && !picked.contains(idx)) picked.add(idx);
    }

    // 目标消耗：优先用户今日待消耗，否则按等级给基础目标
    final burnGoal =
        targetBurnCal > 0 ? targetBurnCal : baseBurnGoal(level);

    // 按目标消耗反推总时长：总时长 = 目标 / 组合平均每分钟消耗
    final avgCal = picked.isEmpty
        ? 8
        : (picked
                    .map((i) => Exercises.all[i].calPerMin)
                    .reduce((a, b) => a + b) /
                picked.length)
            .round()
            .clamp(4, 15);
    // 渐进夹取：新手约 5–15 分钟，高等级最多约 40 分钟
    final minMinutes = 4 + level;
    final maxMinutes = 12 + level * 5;
    final minutes = (burnGoal / avgCal).ceil().clamp(minMinutes, maxMinutes);

    final rest = restSecondsForLevel(level);
    final workSeconds =
        (minutes * 60 - rest * (picked.length.clamp(1, 99) - 1))
            .clamp(60, minutes * 60);
    final perExerciseSec =
        picked.isEmpty ? 60 : (workSeconds / picked.length).round();

    final items = picked
        .map(
          (idx) => _buildItem(
            exerciseIndex: idx,
            secondsBudget: perExerciseSec,
            level: level,
          ),
        )
        .toList(growable: false);

    return WorkoutPlan(
      items: items,
      title: 'Lv.$level ${focus.label}组合 · ${items.length} 式',
      reason: _reason(user, focus, bmi, toLose, level, burnGoal),
      estimatedMinutes: minutes,
      level: level,
      targetBurnCal: burnGoal,
      restSeconds: rest,
    );
  }

  /// 兼容旧接口：返回组合内排序后的摄像头动作索引。
  static List<int> recommendCameraExerciseIndexes(
    User user, {
    WorkoutFocus focus = WorkoutFocus.mixed,
  }) {
    return recommendCombo(user, focus: focus).exerciseIndexes;
  }

  static int? primaryRecommendation(
    User user, {
    WorkoutFocus focus = WorkoutFocus.mixed,
  }) {
    final plan = recommendCombo(user, focus: focus);
    return plan.exerciseIndexes.isEmpty ? null : plan.exerciseIndexes.first;
  }

  static String reasonLabel(
    User user, {
    WorkoutFocus focus = WorkoutFocus.mixed,
  }) {
    return recommendCombo(user, focus: focus).reason;
  }

  // ---- internals ----

  static WorkoutPlanItem _buildItem({
    required int exerciseIndex,
    required int secondsBudget,
    required int level,
  }) {
    final ex = Exercises.all[exerciseIndex];
    final timed = ex.type == 'plank';
    final target = timed
        ? _plankSeconds(secondsBudget, level)
        : _repTarget(ex.type, secondsBudget, level);
    return WorkoutPlanItem(
      exerciseIndex: exerciseIndex,
      target: target,
      isTimed: timed,
    );
  }

  static int _plankSeconds(int secondsBudget, int level) {
    final raw = (secondsBudget * 0.85).round();
    return raw.clamp(20 + level * 5, 45 + level * 15);
  }

  static int _repTarget(String type, int secondsBudget, int level) {
    final repsPerMin = switch (type) {
      'burpee' => 8 + level,
      'pushup' || 'squat' || 'lunge' => 12 + level * 2,
      'jumping_jack' || 'highknee' || 'mountainclimber' => 28 + level * 3,
      _ => 15 + level,
    };
    final reps = (secondsBudget / 60.0 * repsPerMin).round();
    return reps.clamp(8 + level * 2, 20 + level * 8);
  }

  static double _bmiOf(User user) {
    if (user.bmi > 0) return user.bmi;
    if (user.height <= 0) return 22;
    final m = user.height / 100;
    return user.weight / (m * m);
  }

  /// 候选 type 列表（仅会出现在 supportCamera 池里；刻意不含 running/walking/cycling/swimming）。
  /// [level] 渐进等级：低等级只推低冲击动作，高等级解锁波比/登山者。
  static List<String> _poolFor({
    required WorkoutFocus focus,
    required double bmi,
    required User user,
    required double toLose,
    int level = 1,
  }) {
    // 偏好主池
    final focusPool = switch (focus) {
      WorkoutFocus.strength => ['pushup', 'squat', 'lunge', 'plank', 'burpee'],
      WorkoutFocus.burn => [
          'jumping_jack',
          'highknee',
          'burpee',
          'mountainclimber',
          'squat',
        ],
      WorkoutFocus.core => [
          'plank',
          'mountainclimber',
          'lunge',
          'pushup',
          'squat',
        ],
      WorkoutFocus.mixed => [
          'squat',
          'pushup',
          'jumping_jack',
          'plank',
          'lunge',
          'highknee',
        ],
    };

    // 身材 / 目标微调：插到前面提高优先级
    final boost = <String>[];
    if (toLose >= 8 || bmi >= 28) {
      // 减重压力大：低冲击优先，避免波比
      boost.addAll(['squat', 'lunge', 'plank', 'highknee', 'pushup']);
    } else if (toLose >= 3 || bmi >= 24) {
      boost.addAll(['squat', 'jumping_jack', 'lunge', 'pushup', 'plank']);
    } else if (bmi > 0 && bmi < 18.5) {
      // 增重/塑形：力量为主
      boost.addAll(['pushup', 'squat', 'plank', 'lunge']);
    }

    switch (user.fitnessLevel) {
      case FitnessLevel.low:
        boost.insertAll(0, ['squat', 'plank', 'lunge', 'pushup']);
        break;
      case FitnessLevel.high:
        if (focus == WorkoutFocus.burn || focus == WorkoutFocus.mixed) {
          boost.insertAll(0, ['burpee', 'mountainclimber', 'jumping_jack']);
        }
        break;
      case FitnessLevel.medium:
        break;
    }

    switch (user.difficulty) {
      case Difficulty.easy:
        boost.addAll(['plank', 'squat', 'lunge']);
        break;
      case Difficulty.hard:
        boost.insertAll(0, ['burpee', 'mountainclimber', 'jumping_jack']);
        break;
      case Difficulty.normal:
        break;
    }

    // 时段：早晨偏激活，晚上偏低冲击
    switch (user.exerciseTime) {
      case ExerciseTime.morning:
        boost.insertAll(0, ['jumping_jack', 'highknee', 'squat']);
        break;
      case ExerciseTime.evening:
        boost.insertAll(0, ['plank', 'lunge', 'pushup']);
        break;
      case ExerciseTime.afternoon:
        break;
    }

    // 合并：boost 在前，再 focus 池，去重保序
    final seen = <String>{};
    final ordered = <String>[];
    for (final t in [...boost, ...focusPool]) {
      if (seen.add(t)) ordered.add(t);
    }

    // 高 BMI / 低体能 / 新手等级时从组合中拿掉高冲击动作（渐进解锁）
    if (bmi >= 28 || user.fitnessLevel == FitnessLevel.low || level <= 2) {
      ordered.removeWhere((t) => t == 'burpee');
    }
    if (level <= 1) {
      // Lv1 纯新手：连登山者也先不给，避免挫败
      ordered.removeWhere((t) => t == 'mountainclimber');
    }

    return ordered;
  }

  static String _reason(
    User user,
    WorkoutFocus focus,
    double bmi,
    double toLose,
    int level,
    int burnGoal,
  ) {
    final parts = <String>[];
    parts.add('Lv.$level · 目标消耗 $burnGoal kcal');
    parts.add('偏好「${focus.label}」');
    if (toLose >= 1) {
      parts.add('距目标还差 ${toLose.toStringAsFixed(1)} kg');
    } else if (toLose <= -1) {
      parts.add('已达/低于目标体重，偏塑形');
    }
    if (bmi >= 28) {
      parts.add('BMI 偏高→低冲击可识别动作');
    } else if (bmi >= 24) {
      parts.add('BMI 略高→蹲类+燃脂');
    } else if (bmi > 0 && bmi < 18.5) {
      parts.add('BMI 偏低→力量为主');
    }
    parts.add('体能${_fitnessName(user.fitnessLevel)}');
    return parts.join(' · ');
  }

  static String _fitnessName(FitnessLevel f) {
    switch (f) {
      case FitnessLevel.low:
        return '偏低';
      case FitnessLevel.medium:
        return '中等';
      case FitnessLevel.high:
        return '较好';
    }
  }
}
