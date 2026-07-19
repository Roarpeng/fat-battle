import '../constants/app_constants.dart';

/// 核心逻辑层共享类型 —— 双端（Web/Flutter）一致性基准。
///
/// 此文件集中定义 `lib/core/` 各模块共用的类型，对应 Web 端
/// `web/src/store/game-types.ts` 与 `web/src/data/monsters.ts` 中
/// 不在 `lib/models/game_models.dart` / `lib/constants/app_constants.dart` 内的类型。
/// 不修改现有 `game_models.dart`，避免破坏既有代码。

// ========== 性别 ==========

/// 性别（BMR 计算用）。
/// 对应 web/src/store/game-types.ts 中的 `Gender`。
enum Gender { male, female }

// ========== 运动克制系统 ==========

/// 运动类别（克制系统）：cardio / strength / core。
/// 对应 web/src/data/monsters.ts 与 web/src/core/damage.ts 中的 `ExerciseCategory`。
enum ExerciseCategory { cardio, strength, core }

// ========== 姿态识别运动类型（运动质量评分用） ==========

/// 姿态识别支持的运动类型（与姿态检测器一一对应）。
/// 对应 web/src/services/poseTypes.ts 中的 `ExerciseType`。
///
/// 注意：此枚举与 `lib/constants/app_constants.dart` 中的 `ExerciseType` 类
/// （UI 层运动元数据）不同，专供姿态识别质量评分使用。
enum PoseExerciseType {
  squat,
  pushup,
  jumprope,
  highknee,
  plank,
  burpee,
  lunge,
  mountainclimber,
}

// ========== 怪物层级与赛季 ==========

/// 怪物层级。
/// 对应 web/src/data/monsters.ts 中的 `MonsterTier`。
enum MonsterTier { minion, elite, boss, finalboss }

/// 赛季。
/// 对应 web/src/data/monsters.ts 中 `MonsterDef.season`。
enum Season { spring, summer, autumn, winter }

// ========== 卡路里相关枚举 ==========

/// 活动水平（TDEE 计算用）。
/// 对应 web/src/core/calories.ts 中的 `ActivityLevel`。
enum ActivityLevel { sedentary, light, moderate, active, veryActive }

/// 减重目标。
/// 对应 web/src/core/calories.ts 中 `calculateTargetCalories` 的 `goal` 参数。
enum CaloriesGoal { mildLoss, loss, extremeLoss }

// ========== 体重趋势 ==========

/// 体重趋势方向。
/// 对应 web/src/core/weight.ts 中的 `trend`。
enum WeightTrendDirection { increasing, decreasing, stable }

// ========== 怪物定义与状态 ==========

/// 怪物阶段定义。
/// 对应 web/src/data/monsters.ts 中的 `MonsterPhase`。
class MonsterPhase {
  /// 阶段名称
  final String name;

  /// 触发的血量百分比阈值 (0-1)
  final double hpThreshold;

  /// 该阶段的 emoji
  final String emoji;

  /// 该阶段的伤害加成
  final double damageBonus;

  /// 该阶段的额外描述
  final String desc;

  const MonsterPhase({
    required this.name,
    required this.hpThreshold,
    required this.emoji,
    required this.damageBonus,
    required this.desc,
  });
}

/// 怪物定义。
/// 对应 web/src/data/monsters.ts 中的 `MonsterDef`。
class MonsterDef {
  /// 怪物类型 ID
  final String id;

  /// 显示名称
  final String name;

  /// 默认 emoji
  final String emoji;

  /// 怪物层级
  final MonsterTier tier;

  /// 弱点运动类型
  final ExerciseCategory weakness;

  /// 怪物属性倾向（影响克制关系）
  final ExerciseCategory affinity;

  /// HP 基础值
  final int baseHp;

  /// 每级 HP 成长
  final int hpPerLevel;

  /// 基础攻击力（用于狂暴反击伤害计算）
  final int baseAttack;

  /// 描述
  final String description;

  /// 阶段定义（BOSS 才有，小怪/精英为空数组）
  final List<MonsterPhase> phases;

  /// 狂暴血量阈值 (0-1，低于此比例触发狂暴)
  final double enrageThreshold;

  /// 狂暴倍率
  final double enrageMultiplier;

  /// 击败奖励金币倍率
  final int coinMultiplier;

  /// 赛季标记（可选）
  final Season? season;

  /// 背景故事引用（可选）
  final String? story;

  // ========== 护盾系统 ==========

  /// 护盾基础值
  final int baseShield;

  /// 每级护盾成长
  final int shieldPerLevel;

  /// 护盾减伤率 (0-1)，护盾存在时怪物本体受到的伤害比例。
  /// 例如 0.3 表示护盾存在时，怪物本体只承受 30% 的伤害，护盾承担全额。
  final double shieldReductionRate;

  const MonsterDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.tier,
    required this.weakness,
    required this.affinity,
    required this.baseHp,
    required this.hpPerLevel,
    required this.baseAttack,
    required this.description,
    this.phases = const [],
    required this.enrageThreshold,
    required this.enrageMultiplier,
    required this.coinMultiplier,
    this.season,
    this.story,
    required this.baseShield,
    required this.shieldPerLevel,
    required this.shieldReductionRate,
  });
}

/// 怪物完整状态。
/// 对应 web/src/store/game-types.ts 中的 `MonsterState`。
class MonsterState {
  /// 当前 HP
  final int hp;

  /// 最大 HP
  final int maxHp;

  /// 怪物等级
  final int level;

  /// 显示名称
  final String name;

  /// emoji
  final String emoji;

  /// 怪物类型（兼容旧字段，可空）
  final String? type;

  // ===== BOSS 设计系统字段 =====

  /// 怪物定义 ID
  final String defId;

  /// 怪物层级
  final MonsterTier tier;

  /// 弱点运动类型
  final ExerciseCategory weakness;

  /// 怪物属性倾向
  final ExerciseCategory affinity;

  /// 基础攻击力
  final int baseAttack;

  /// 描述
  final String description;

  /// 狂暴血量阈值 (0-1)
  final double enrageThreshold;

  /// 狂暴倍率
  final double enrageMultiplier;

  /// 击败奖励金币倍率
  final int coinMultiplier;

  /// 当前阶段索引
  final int phaseIndex;

  /// 当前阶段名称
  final String phaseName;

  /// 当前阶段 emoji
  final String phaseEmoji;

  /// 是否处于狂暴状态
  final bool isEnraged;

  /// 赛季标记（可空）
  final Season? season;

  /// AI 教练动态难度倍率
  final double hpMultiplier;

  /// 虚影机制：击败后第二天的怪物以虚影形态出现
  final bool isPhantom;

  // ========== 护盾系统 ==========

  /// 当前护盾值
  final int shield;

  /// 最大护盾值
  final int maxShield;

  /// 护盾减伤率 (0-1)，护盾存在时怪物本体受到的伤害比例
  final double shieldReductionRate;

  const MonsterState({
    required this.hp,
    required this.maxHp,
    required this.level,
    required this.name,
    required this.emoji,
    this.type,
    required this.defId,
    required this.tier,
    required this.weakness,
    required this.affinity,
    required this.baseAttack,
    required this.description,
    required this.enrageThreshold,
    required this.enrageMultiplier,
    required this.coinMultiplier,
    required this.phaseIndex,
    required this.phaseName,
    required this.phaseEmoji,
    required this.isEnraged,
    this.season,
    required this.hpMultiplier,
    required this.isPhantom,
    required this.shield,
    required this.maxShield,
    required this.shieldReductionRate,
  });

  MonsterState copyWith({
    int? hp,
    int? maxHp,
    int? level,
    String? name,
    String? emoji,
    String? type,
    String? defId,
    MonsterTier? tier,
    ExerciseCategory? weakness,
    ExerciseCategory? affinity,
    int? baseAttack,
    String? description,
    double? enrageThreshold,
    double? enrageMultiplier,
    int? coinMultiplier,
    int? phaseIndex,
    String? phaseName,
    String? phaseEmoji,
    bool? isEnraged,
    Season? season,
    double? hpMultiplier,
    bool? isPhantom,
    int? shield,
    int? maxShield,
    double? shieldReductionRate,
  }) {
    return MonsterState(
      hp: hp ?? this.hp,
      maxHp: maxHp ?? this.maxHp,
      level: level ?? this.level,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      type: type ?? this.type,
      defId: defId ?? this.defId,
      tier: tier ?? this.tier,
      weakness: weakness ?? this.weakness,
      affinity: affinity ?? this.affinity,
      baseAttack: baseAttack ?? this.baseAttack,
      description: description ?? this.description,
      enrageThreshold: enrageThreshold ?? this.enrageThreshold,
      enrageMultiplier: enrageMultiplier ?? this.enrageMultiplier,
      coinMultiplier: coinMultiplier ?? this.coinMultiplier,
      phaseIndex: phaseIndex ?? this.phaseIndex,
      phaseName: phaseName ?? this.phaseName,
      phaseEmoji: phaseEmoji ?? this.phaseEmoji,
      isEnraged: isEnraged ?? this.isEnraged,
      season: season ?? this.season,
      hpMultiplier: hpMultiplier ?? this.hpMultiplier,
      isPhantom: isPhantom ?? this.isPhantom,
      shield: shield ?? this.shield,
      maxShield: maxShield ?? this.maxShield,
      shieldReductionRate: shieldReductionRate ?? this.shieldReductionRate,
    );
  }
}

// ========== 周数据（难度引擎用） ==========

/// 周数据中的单日记录。
/// 对应 web/src/store/game-types.ts 中 `WeeklyData.days` 的元素类型。
class WeeklyDayData {
  final String date;
  final double? weight;
  final double? calories;
  final double? exercise;

  const WeeklyDayData({
    required this.date,
    this.weight,
    this.calories,
    this.exercise,
  });
}

/// 周数据。
/// 对应 web/src/store/game-types.ts 中的 `WeeklyData`。
///
/// 注意：与 `lib/models/game_models.dart` 中的 `WeekData` 字段不同，
/// 本类专供难度引擎使用，结构对齐 Web 端 `WeeklyData`。
class WeeklyData {
  final String weekStart;
  final List<WeeklyDayData> days;

  const WeeklyData({
    required this.weekStart,
    required this.days,
  });
}

// ========== 难度调整建议 ==========

/// 难度调整建议。
/// 对应 web/src/core/difficulty.ts 中的 `DifficultyAdvice`。
class DifficultyAdvice {
  /// 怪物 HP 倍率
  final double monsterHpMultiplier;

  /// 任务目标调整倍率
  final double questTargetAdjustment;

  /// 建议难度
  final Difficulty suggestedDifficulty;

  /// 提示文案
  final String message;

  const DifficultyAdvice({
    required this.monsterHpMultiplier,
    required this.questTargetAdjustment,
    required this.suggestedDifficulty,
    required this.message,
  });
}
