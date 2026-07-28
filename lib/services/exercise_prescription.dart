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

/// 一组可摄像头引导的推荐动作（不含跑步/骑行等无法入镜检测的项目）。
class WorkoutPlan {
  final List<int> exerciseIndexes;
  final String title;
  final String reason;
  final int estimatedMinutes;

  const WorkoutPlan({
    required this.exerciseIndexes,
    required this.title,
    required this.reason,
    required this.estimatedMinutes,
  });

  List<ExerciseType> get exercises =>
      exerciseIndexes.map((i) => Exercises.all[i]).toList(growable: false);
}

/// 根据身材、目标体重、体能与锻炼偏好，生成摄像头可教学的动作组合。
class ExercisePrescription {
  ExercisePrescription._();

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

  /// 生成 3～4 个动作的推荐组合（全部 supportCamera）。
  static WorkoutPlan recommendCombo(
    User user, {
    WorkoutFocus focus = WorkoutFocus.mixed,
    int maxItems = 4,
  }) {
    final bmi = _bmiOf(user);
    final toLose = user.weight - user.targetWeight; // >0 需减重
    final pool = _poolFor(focus: focus, bmi: bmi, user: user, toLose: toLose);

    final picked = <int>[];
    for (final type in pool) {
      final idx = indexOfType(type);
      if (idx == null) continue;
      if (picked.contains(idx)) continue;
      picked.add(idx);
      if (picked.length >= maxItems) break;
    }

    // 保底：至少塞满可识别基础三项
    for (final fallback in const ['squat', 'pushup', 'plank', 'lunge']) {
      if (picked.length >= maxItems.clamp(3, 4)) break;
      final idx = indexOfType(fallback);
      if (idx != null && !picked.contains(idx)) picked.add(idx);
    }

    final minutes = _estimateMinutes(user, picked.length);
    return WorkoutPlan(
      exerciseIndexes: picked,
      title: '${focus.label}组合 · ${picked.length} 式',
      reason: _reason(user, focus, bmi, toLose),
      estimatedMinutes: minutes,
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

  static double _bmiOf(User user) {
    if (user.bmi > 0) return user.bmi;
    if (user.height <= 0) return 22;
    final m = user.height / 100;
    return user.weight / (m * m);
  }

  /// 候选 type 列表（仅会出现在 supportCamera 池里；刻意不含 running/walking/cycling/swimming）。
  static List<String> _poolFor({
    required WorkoutFocus focus,
    required double bmi,
    required User user,
    required double toLose,
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
      WorkoutFocus.core => ['plank', 'mountainclimber', 'lunge', 'pushup', 'squat'],
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

    // 高 BMI / 低体能时从组合中拿掉波比
    if (bmi >= 28 || user.fitnessLevel == FitnessLevel.low) {
      ordered.removeWhere((t) => t == 'burpee');
    }

    return ordered;
  }

  static int _estimateMinutes(User user, int count) {
    final per = switch (user.fitnessLevel) {
      FitnessLevel.low => 4,
      FitnessLevel.medium => 5,
      FitnessLevel.high => 6,
    };
    return (count * per).clamp(10, 30);
  }

  static String _reason(
    User user,
    WorkoutFocus focus,
    double bmi,
    double toLose,
  ) {
    final parts = <String>[];
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
    parts.add('仅含摄像头可引导动作（不含跑步/骑行等）');
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
