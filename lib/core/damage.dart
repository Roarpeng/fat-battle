import 'dart:math' as math;
import '../constants/app_constants.dart';
import 'core_types.dart';

// ========== 运动克制系统 ==========

/// 克制关系（三角循环）：
/// - cardio → strength（有氧克制力量型怪物）
/// - strength → core（力量克制核心型怪物）
/// - core → cardio（核心克制有氧型怪物）
const Map<ExerciseCategory, ExerciseCategory> _counterMap = {
  ExerciseCategory.cardio: ExerciseCategory.strength,
  ExerciseCategory.strength: ExerciseCategory.core,
  ExerciseCategory.core: ExerciseCategory.cardio,
};

/// 克制伤害倍率：克制 ×1.5、被克 ×0.7、普通 ×1.0
const double _counterSuperEffective = 1.5; // 克制
const double _counterNormal = 1.0;
const double _counterNotVeryEffective = 0.7; // 被克

/// 伤害结算效果标签，供 UI 显示「效果绝佳！」/「效果不太好…」
enum DamageEffectiveness { superEffective, normal, weak }

/// 带克制信息的伤害结算结果。
/// 对应 web/src/core/damage.ts 中的 `DamageResult`。
class DamageResult {
  final int damage;
  final DamageEffectiveness effectiveness;
  final double multiplier;

  const DamageResult({
    required this.damage,
    required this.effectiveness,
    required this.multiplier,
  });
}

/// 内部使用的克制结算辅助结构。
class _DamageModifier {
  final double multiplier;
  final DamageEffectiveness effectiveness;

  const _DamageModifier({required this.multiplier, required this.effectiveness});
}

/// 根据运动类型与怪物属性计算克制倍率与效果标签（内部纯函数）。
///
/// - `_counterMap[exerciseCategory] == monsterAffinity` → 克制 ×1.5
/// - `_counterMap[monsterAffinity] == exerciseCategory` → 被克 ×0.7（怪物克制该运动类型）
/// - 否则 ×1.0
_DamageModifier _resolveCounter(
  ExerciseCategory exerciseCategory,
  ExerciseCategory monsterAffinity,
) {
  if (_counterMap[exerciseCategory] == monsterAffinity) {
    return const _DamageModifier(
      multiplier: _counterSuperEffective,
      effectiveness: DamageEffectiveness.superEffective,
    );
  }
  if (_counterMap[monsterAffinity] == exerciseCategory) {
    return const _DamageModifier(
      multiplier: _counterNotVeryEffective,
      effectiveness: DamageEffectiveness.weak,
    );
  }
  return const _DamageModifier(
    multiplier: _counterNormal,
    effectiveness: DamageEffectiveness.normal,
  );
}

/// 计算基础伤害值（不含克制倍率）。
///
/// 基础伤害来自运动消耗，保持原有 `attackMonster` 中「运动卡路里即伤害」的语义。
/// 难度倍率与怪物 HP 难度倍率反向：简单模式玩家伤害更高，困难模式更低。
/// 当处于热量赤字（运动消耗 > 摄入）时，减脂效果更显著，给予 10% 伤害加成。
///
/// 注意：过量摄入（intake > targetCalories）不在此处削减伤害，
/// 而是通过 `calculateOvereatCalories` + `calculateShieldFromOvereat` 转化为怪物护盾。
int calculateDamageBase(
  num intake,
  num exerciseBurn,
  Difficulty difficulty,
) {
  final diffMultiplier = difficulty == Difficulty.easy
      ? 1.3
      : (difficulty == Difficulty.hard ? 0.7 : 1.0);
  final burn = math.max(0, exerciseBurn.toInt());
  final food = math.max(0, intake.toInt());
  final deficitBonus = burn > food ? 1.1 : 1.0;
  return (burn * diffMultiplier * deficitBonus).round();
}

/// 计算对怪物的伤害值（不含克制参数，向后兼容版本）。
///
/// 等价于 TS 重载签名：
/// ```ts
/// function calculateDamage(intake, exerciseBurn, difficulty): number
/// ```
int calculateDamage(
  num intake,
  num exerciseBurn,
  Difficulty difficulty,
) {
  return calculateDamageBase(intake, exerciseBurn, difficulty);
}

/// 计算对怪物的伤害值（启用克制系统版本）。
///
/// 在基础伤害上叠加克制倍率：克制 ×1.5、被克 ×0.7、同属性/无克制关系 ×1.0，
/// 并返回 [DamageResult] 供 UI 显示「效果绝佳！」/「效果不太好…」。
///
/// 等价于 TS 重载签名：
/// ```ts
/// function calculateDamage(
///   intake, exerciseBurn, difficulty, exerciseCategory, monsterAffinity,
/// ): DamageResult
/// ```
DamageResult calculateDamageWithCounter(
  num intake,
  num exerciseBurn,
  Difficulty difficulty,
  ExerciseCategory exerciseCategory,
  ExerciseCategory monsterAffinity,
) {
  final baseDamage = calculateDamageBase(intake, exerciseBurn, difficulty);
  final mod = _resolveCounter(exerciseCategory, monsterAffinity);
  final finalDamage = (baseDamage * mod.multiplier).round();
  return DamageResult(
    damage: finalDamage,
    effectiveness: mod.effectiveness,
    multiplier: mod.multiplier,
  );
}

/// 计算过量摄入的卡路里。
/// 当摄入超过目标卡路里时，超出部分即为过量摄入；否则为 0。
/// 负输入会被归一化为 0。
int calculateOvereatCalories(num intake, num targetCalories) {
  return math.max(0, math.max(0, intake.toInt()) - math.max(0, targetCalories.toInt()));
}

/// 过量卡路里转化为怪物护盾。
///
/// [overeatCalories] 过量摄入的卡路里（建议由 [calculateOvereatCalories] 得到）
/// [ratio] 转化比例（每 ratio 卡路里 = 1 点护盾），默认 10:1
/// 返回护盾值（非负整数）。
///
/// 双端基准统一采用 10:1：暴食惩罚但不至于过强，
/// 避免高卡路里数值导致护盾条瞬间溢出。
/// `ratio <= 0` 时回退为默认 10。
int calculateShieldFromOvereat(num overeatCalories, [num ratio = 10]) {
  final safeRatio = ratio > 0 ? ratio.toInt() : 10;
  return (math.max(0, overeatCalories.toInt()) / safeRatio).floor();
}

/// 护盾感知的伤害结算（整合自 `monsterSlice.attackMonster` 的核心计算）。
///
/// 结算规则：
/// 1. 护盾存在时：护盾承受全额伤害，同时怪物本体受到穿透伤害
///    （穿透比例 = `shieldReductionRate`）。若护盾被击破，溢出伤害额外打到本体。
/// 2. 护盾不存在时：全额伤害打到本体。
/// 3. 本体 HP 不会降至 0 以下。
///
/// 该函数为纯函数：不修改输入对象，返回新的怪物状态。
MonsterState applyDamageToMonster(MonsterState monster, num damage) {
  if (damage <= 0 || monster.hp <= 0) return monster;

  var newHp = monster.hp;
  var newShield = monster.shield;
  final damageInt = damage.toInt();

  if (newShield > 0) {
    // 护盾存在：护盾承担全额伤害
    newShield -= damageInt;
    // 本体同时受到穿透伤害
    final hpDamage = (damageInt * monster.shieldReductionRate).round();
    newHp = math.max(0, newHp - hpDamage);
    // 护盾击破：溢出部分（newShield 为负）额外打到本体
    if (newShield < 0) {
      newHp = math.max(0, newHp + newShield);
      newShield = 0;
    }
  } else {
    // 护盾已破：全额伤害打到本体
    newHp = math.max(0, newHp - damageInt);
  }

  return monster.copyWith(hp: newHp, shield: newShield);
}
