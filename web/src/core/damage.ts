import type { Difficulty, MonsterState } from '../store/game-types'

// ========== 运动克制系统 ==========

export type ExerciseCategory = 'cardio' | 'strength' | 'core'
export type MonsterAffinity = 'cardio' | 'strength' | 'core'

/**
 * 克制关系（三角循环）：
 * - cardio → strength（有氧克制力量型怪物）
 * - strength → core（力量克制核心型怪物）
 * - core → cardio（核心克制有氧型怪物）
 */
const COUNTER_MAP: Record<ExerciseCategory, MonsterAffinity> = {
  cardio: 'strength',
  strength: 'core',
  core: 'cardio',
}

/** 克制伤害倍率：克制 ×1.5、被克 ×0.7、普通 ×1.0 */
const COUNTER_MULTIPLIER = {
  superEffective: 1.5, // 克制
  normal: 1.0,
  notVeryEffective: 0.7, // 被克
} as const

/** 热量预算带：目标 ±10%，且至少 ±100 kcal。与 Flutter `lib/core/damage.dart` 对齐。 */
export const CALORIE_BAND_RATIO = 0.10
export const CALORIE_BAND_MIN_ABS_KCAL = 100
/** 打中预算带时的伤害加成（奖励贴近目标，而不是吃得越少越好）。 */
export const CALORIE_BAND_HIT_BONUS = 1.15

/** 伤害结算效果标签，供 UI 显示「效果绝佳！」/「效果不太好…」 */
export type DamageEffectiveness = 'super' | 'normal' | 'weak'

/** 带克制信息的伤害结算结果 */
export interface DamageResult {
  damage: number
  effectiveness: DamageEffectiveness
  multiplier: number
}

/**
 * 根据运动类型与怪物属性计算克制倍率与效果标签（内部纯函数）。
 *
 * - `COUNTER_MAP[exerciseCategory] === monsterAffinity` → 克制 ×1.5
 * - `COUNTER_MAP[monsterAffinity] === exerciseCategory` → 被克 ×0.7（怪物克制该运动类型）
 * - 否则 ×1.0
 */
function resolveCounter(
  exerciseCategory: ExerciseCategory,
  monsterAffinity: MonsterAffinity,
): { multiplier: number; effectiveness: DamageEffectiveness } {
  if (COUNTER_MAP[exerciseCategory] === monsterAffinity) {
    return { multiplier: COUNTER_MULTIPLIER.superEffective, effectiveness: 'super' }
  }
  if (COUNTER_MAP[monsterAffinity] === exerciseCategory) {
    return { multiplier: COUNTER_MULTIPLIER.notVeryEffective, effectiveness: 'weak' }
  }
  return { multiplier: COUNTER_MULTIPLIER.normal, effectiveness: 'normal' }
}

/** 预算带半宽（kcal）。 */
export function calorieBandHalfWidth(targetCalories: number): number {
  const target = Math.max(0, Math.round(targetCalories))
  return Math.max(CALORIE_BAND_MIN_ABS_KCAL, Math.round(target * CALORIE_BAND_RATIO))
}

/** 当日摄入是否落在目标热量预算带内。 */
export function isIntakeInCalorieBand(intake: number, targetCalories: number): boolean {
  const target = Math.max(0, Math.round(targetCalories))
  if (target <= 0) return false
  const food = Math.max(0, Math.round(intake))
  return Math.abs(food - target) <= calorieBandHalfWidth(target)
}

/** 打中预算带 → 1.15，否则 1.0。吃得更少不会额外加伤。 */
export function calorieBandHitBonus(intake: number, targetCalories?: number): number {
  if (targetCalories === undefined) return 1.0
  return isIntakeInCalorieBand(intake, targetCalories) ? CALORIE_BAND_HIT_BONUS : 1.0
}

/**
 * 计算对怪物的伤害值（统一双端伤害模型基准）。
 *
 * 基础伤害来自运动消耗，保持原有 `attackMonster` 中「运动卡路里即伤害」的语义。
 * 难度倍率与怪物 HP 难度倍率反向：简单模式玩家伤害更高，困难模式更低。
 * 传入 `targetCalories` 时，打中热量预算带给予 1.15 加成；不再奖励「吃得越少越好」
 * （已去掉旧的 burn>food ×1.1 赤字加成，与 Flutter 对齐）。
 *
 * 当同时提供 `exerciseCategory` 与 `monsterAffinity` 时，启用运动克制系统：
 * 克制 ×1.5、被克 ×0.7、同属性/无克制关系 ×1.0，并返回 `DamageResult`
 * 供 UI 显示「效果绝佳！」/「效果不太好…」。
 *
 * 注意：过量摄入（intake > targetCalories）不在此处削减伤害，
 * 而是通过 `calculateOvereatCalories` + `calculateShieldFromOvereat` 转化为怪物护盾。
 *
 * 重载（保持向后兼容）：
 * 1. 仅传 (intake, exerciseBurn, difficulty, targetCalories?) → 返回 number
 * 2. 额外传入 (exerciseCategory, monsterAffinity, targetCalories?) → 返回 DamageResult
 */
export function calculateDamage(
  intake: number,
  exerciseBurn: number,
  difficulty: Difficulty,
  targetCalories?: number,
): number
export function calculateDamage(
  intake: number,
  exerciseBurn: number,
  difficulty: Difficulty,
  exerciseCategory: ExerciseCategory,
  monsterAffinity: MonsterAffinity,
  targetCalories?: number,
): DamageResult
export function calculateDamage(
  intake: number,
  exerciseBurn: number,
  difficulty: Difficulty,
  exerciseCategoryOrTarget?: ExerciseCategory | number,
  monsterAffinity?: MonsterAffinity,
  targetCalories?: number,
): number | DamageResult {
  let exerciseCategory: ExerciseCategory | undefined
  let affinity: MonsterAffinity | undefined
  let target: number | undefined

  if (typeof exerciseCategoryOrTarget === 'number') {
    target = exerciseCategoryOrTarget
  } else if (exerciseCategoryOrTarget !== undefined) {
    exerciseCategory = exerciseCategoryOrTarget
    affinity = monsterAffinity
    target = targetCalories
  }

  const diffMultiplier = difficulty === 'easy' ? 1.3 : difficulty === 'hard' ? 0.7 : 1.0
  const burn = Math.max(0, exerciseBurn)
  const bandBonus = calorieBandHitBonus(intake, target)
  const baseDamage = Math.round(burn * diffMultiplier * bandBonus)

  // 未提供完整克制参数：返回数字（向后兼容）
  if (exerciseCategory === undefined || affinity === undefined) {
    return baseDamage
  }

  // 启用克制系统：在基础伤害上叠加克制倍率
  const { multiplier, effectiveness } = resolveCounter(exerciseCategory, affinity)
  const finalDamage = Math.round(baseDamage * multiplier)
  return { damage: finalDamage, effectiveness, multiplier }
}

/**
 * 计算过量摄入的卡路里。
 * 当摄入超过目标卡路里时，超出部分即为过量摄入；否则为 0。
 * 负输入会被归一化为 0。
 */
export function calculateOvereatCalories(intake: number, targetCalories: number): number {
  return Math.max(0, Math.max(0, intake) - Math.max(0, targetCalories))
}

/**
 * 过量卡路里转化为怪物护盾。
 *
 * @param overeatCalories 过量摄入的卡路里（建议由 `calculateOvereatCalories` 得到）
 * @param ratio 转化比例（每 ratio 卡路里 = 1 点护盾），默认 10:1
 * @returns 护盾值（非负整数）
 *
 * 双端基准统一采用 10:1：超出预算会生成护盾（玩法机制，不是羞辱），
 * 避免高卡路里数值导致护盾条瞬间溢出。`monsterSlice.addMonsterShield` 也复用此函数。
 * ratio <= 0 时回退为默认 10。
 */
export function calculateShieldFromOvereat(overeatCalories: number, ratio: number = 10): number {
  const safeRatio = ratio > 0 ? ratio : 10
  return Math.floor(Math.max(0, overeatCalories) / safeRatio)
}

/**
 * 护盾感知的伤害结算（整合自 `monsterSlice.attackMonster` 的核心计算）。
 *
 * 结算规则：
 * 1. 护盾存在时：护盾承受全额伤害，同时怪物本体受到穿透伤害
 *    （穿透比例 = `shieldReductionRate`）。若护盾被击破，溢出伤害额外打到本体。
 * 2. 护盾不存在时：全额伤害打到本体。
 * 3. 本体 HP 不会降至 0 以下。
 *
 * 该函数为纯函数：不修改输入对象，返回新的怪物状态。
 */
export function applyDamageToMonster(
  monster: MonsterState,
  damage: number,
): MonsterState {
  if (damage <= 0 || monster.hp <= 0) return { ...monster }

  let newHp = monster.hp
  let newShield = monster.shield

  if (newShield > 0) {
    // 护盾存在：护盾承担全额伤害
    newShield -= damage
    // 本体同时受到穿透伤害
    const hpDamage = Math.round(damage * monster.shieldReductionRate)
    newHp = Math.max(0, newHp - hpDamage)
    // 护盾击破：溢出部分（newShield 为负）额外打到本体
    if (newShield < 0) {
      newHp = Math.max(0, newHp + newShield)
      newShield = 0
    }
  } else {
    // 护盾已破：全额伤害打到本体
    newHp = Math.max(0, newHp - damage)
  }

  return { ...monster, hp: newHp, shield: newShield }
}
