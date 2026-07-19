import type { MonsterState, Difficulty } from '../store/game-types'
import {
  getMonsterDefByLevel,
  calculateMonsterHp,
  calculateMonsterShield,
  type MonsterPhase,
} from '../data/monsters'

/**
 * 生成怪物完整状态（提取自 `game-utils.generateMonster`）。
 *
 * 护盾完全来自过量卡路里，初始为 0。
 * `maxShield` 初始为 0，会随护盾增长动态调整。
 *
 * @param level 怪物等级（决定怪物定义与 HP/护盾成长）
 * @param difficulty 难度，影响 HP 与护盾基数
 * @param hpMultiplier AI 教练动态 HP 倍率，默认 1
 */
export function generateMonster(
  level: number,
  difficulty: Difficulty = 'normal',
  hpMultiplier: number = 1,
): MonsterState {
  const def = getMonsterDefByLevel(level)
  const maxHp = Math.round(calculateMonsterHp(def, level, difficulty) * hpMultiplier)
  const hpPercentage = 1.0
  const phases = def.phases || []
  const currentPhase = phases.length > 0 ? phases[0] : null
  const isEnraged = hpPercentage <= def.enrageThreshold

  return {
    hp: maxHp,
    maxHp,
    level,
    name: def.name,
    emoji: def.emoji,
    type: def.id,
    defId: def.id,
    tier: def.tier,
    weakness: def.weakness,
    affinity: def.affinity,
    baseAttack: def.baseAttack,
    description: def.description,
    enrageThreshold: def.enrageThreshold,
    enrageMultiplier: def.enrageMultiplier,
    coinMultiplier: def.coinMultiplier,
    phaseIndex: 0,
    phaseName: currentPhase?.name || '',
    phaseEmoji: currentPhase?.emoji || def.emoji,
    isEnraged,
    season: def.season,
    hpMultiplier,
    isPhantom: false,
    // 护盾系统：护盾完全来自过量卡路里，初始为 0
    shield: 0,
    maxShield: 0,
    shieldReductionRate: def.shieldReductionRate,
  }
}

/**
 * 根据当前 HP 百分比更新怪物阶段与狂暴状态（纯函数版本）。
 *
 * 提取自 `game-utils.updateMonsterPhase`，去除对完整 monster 对象的依赖，
 * 仅需 HP 百分比与可选阶段定义，便于双端复用。
 *
 * @param hpPercent 当前 HP 占最大 HP 的比例 (0-1)
 * @param phases 阶段定义数组（来自怪物定义），默认空数组
 * @param enrageThreshold 狂暴阈值，默认 0.3
 * @returns 阶段索引、阶段名、阶段 emoji、是否狂暴
 */
export function updateMonsterPhase(
  hpPercent: number,
  phases: MonsterPhase[] = [],
  enrageThreshold: number = 0.3,
): { phaseIndex: number; phaseName: string; phaseEmoji: string; isEnraged: boolean } {
  let phaseIndex = 0
  let phaseName = ''
  let phaseEmoji = ''

  if (phases.length > 0) {
    for (let i = 0; i < phases.length; i++) {
      if (hpPercent <= phases[i].hpThreshold) {
        phaseIndex = i
        phaseName = phases[i].name
        phaseEmoji = phases[i].emoji
      }
    }
  }

  const isEnraged = hpPercent <= enrageThreshold

  return { phaseIndex, phaseName, phaseEmoji, isEnraged }
}

/**
 * 判断怪物是否处于狂暴状态（提取自 `data/monsters.isMonsterEnraged` 的纯函数版本）。
 *
 * @param hpPercent 当前 HP 占最大 HP 的比例 (0-1)
 * @param enrageThreshold 狂暴阈值，默认 0.3
 * @returns HP 百分比 <= 阈值时返回 true
 */
export function isMonsterEnraged(hpPercent: number, enrageThreshold: number = 0.3): boolean {
  return hpPercent <= enrageThreshold
}
