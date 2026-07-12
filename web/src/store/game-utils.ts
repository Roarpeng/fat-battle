import type { MonsterState, WeeklyData } from './game-types'
import { getMonsterDefByLevel, calculateMonsterHp, calculateMonsterShield } from '../data/monsters'

export const getTodayStr = () => {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

export const calculateBmi = (weight: number, height: number) => {
  if (height <= 0) return 0
  const h = height / 100
  return Number((weight / (h * h)).toFixed(1))
}

/** 根据怪物定义和等级生成完整的怪物状态 */
export const generateMonster = (level: number, difficulty: 'easy' | 'normal' | 'hard' = 'normal', hpMultiplier: number = 1): MonsterState => {
  const def = getMonsterDefByLevel(level)
  const maxHp = Math.round(calculateMonsterHp(def, level, difficulty) * hpMultiplier)
  const maxShield = calculateMonsterShield(def, level, difficulty)
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
    // ========== 护盾系统（护盾完全来自过量卡路里，初始为0） ==========
    shield: 0,
    maxShield: 0,
    shieldReductionRate: def.shieldReductionRate,
  }
}

/** 根据当前HP百分比更新怪物阶段和狂暴状态 */
export const updateMonsterPhase = (monster: MonsterState): Partial<MonsterState> => {
  const def = getMonsterDefByLevel(monster.level)
  const phases = def.phases || []
  const hpPercentage = monster.hp / monster.maxHp

  let phaseIndex = 0
  let phaseName = ''
  let phaseEmoji = monster.emoji

  if (phases.length > 0) {
    for (let i = 0; i < phases.length; i++) {
      if (hpPercentage <= phases[i].hpThreshold) {
        phaseIndex = i
        phaseName = phases[i].name
        phaseEmoji = phases[i].emoji
      }
    }
  }

  const isEnraged = hpPercentage <= monster.enrageThreshold

  return { phaseIndex, phaseName, phaseEmoji, isEnraged }
}

// ========== XP & 等级系统 ==========
export const getXpToNextLevel = (level: number) => Math.floor(100 * Math.pow(1.15, level - 1))

export const getLevelTitle = (level: number) => {
  const LEVEL_TITLES = [
    '健身新手', '初级勇士', '运动学徒', '减脂先锋', '卡路里猎人',
    '脂肪终结者', '健身达人', '传奇勇士', '神话英雄', '减肥之神',
    '超越者', '永恒战士', '宇宙健身王', '时间主宰', '无限可能',
  ]
  if (level <= 0) return LEVEL_TITLES[0]
  if (level > LEVEL_TITLES.length) return LEVEL_TITLES[LEVEL_TITLES.length - 1]
  return LEVEL_TITLES[level - 1]
}

export const getInitialWeeklyData = (): WeeklyData => {
  const today = new Date()
  const dayOfWeek = today.getDay()
  const monday = new Date(today)
  monday.setDate(today.getDate() - (dayOfWeek === 0 ? 6 : dayOfWeek - 1))
  const days = []
  for (let i = 0; i < 7; i++) {
    const d = new Date(monday)
    d.setDate(monday.getDate() + i)
    days.push({
      date: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`,
    })
  }
  return {
    weekStart: days[0].date, days }
}
