/**
 * 怪物定义库 —— 完整的BOSS设计系统
 *
 * 设计参考：
 * - 黑暗之魂：二阶段切换 + 属性弱点
 * - 原神：多阶段BOSS + 元素破盾 + 虚弱窗口
 * - FGO：职阶三角克制
 * - 健身环大冒险：运动即攻击 + 难度自适应
 * - 怪物弹珠：5档难度分级
 *
 * 怪物分3个层级：
 * - 小怪 (Minion)：Level 1-4, 6-9, 11-14...  简单战斗，无特殊机制
 * - 精英怪 (Elite)：Level 5, 15, 25...  有弱点 + 狂暴
 * - BOSS (Boss)：Level 10, 20, 30...  多阶段 + 弱点 + 狂暴 + 特殊技能
 * - 终极BOSS (FinalBoss)：Level 50  全阶段 + 全机制
 */

// ========== 运动克制系统 ==========

export type ExerciseCategory = 'cardio' | 'strength' | 'core'

/** 运动类型 → 分类映射 */
export const EXERCISE_CATEGORY: Record<string, ExerciseCategory> = {
  // 有氧运动 — 克制高HP型怪物
  running: 'cardio',
  swimming: 'cardio',
  cycling: 'cardio',
  jumprope: 'cardio',
  walking: 'cardio',
  highknee: 'cardio',
  // 力量运动 — 克制高防御型怪物
  squat: 'strength',
  pushup: 'strength',
  burpee: 'strength',
  lunge: 'strength',
  // 核心运动 — 克制高攻击型怪物
  plank: 'core',
  yoga: 'core',
  hiit: 'core',
  mountainclimber: 'core',
}

/** 克制关系：cardio → strength → core → cardio (三角循环) */
export const COUNTER_MAP: Record<ExerciseCategory, ExerciseCategory> = {
  cardio: 'strength',   // 有氧 克制 力量型怪物
  strength: 'core',     // 力量 克制 核心型怪物
  core: 'cardio',       // 核心 克制 有氧型怪物
}

/** 克制伤害倍率 */
export const COUNTER_MULTIPLIER = 1.5
/** 被克伤害倍率 */
export const WEAK_MULTIPLIER = 0.7

// ========== 阶段定义 ==========

export interface MonsterPhase {
  /** 阶段名称 */
  name: string
  /** 触发的血量百分比阈值 (0-1) */
  hpThreshold: number
  /** 该阶段的emoji */
  emoji: string
  /** 该阶段的伤害加成 */
  damageBonus: number
  /** 该阶段的额外描述 */
  desc: string
}

// ========== 怪物定义 ==========

export type MonsterTier = 'minion' | 'elite' | 'boss' | 'finalboss'

export type MonsterWeakness = ExerciseCategory

export interface MonsterDef {
  /** 怪物类型ID */
  id: string
  /** 显示名称 */
  name: string
  /** 默认emoji */
  emoji: string
  /** 怪物层级 */
  tier: MonsterTier
  /** 弱点运动类型 */
  weakness: MonsterWeakness
  /** 怪物属性倾向（影响克制关系） */
  affinity: ExerciseCategory
  /** HP基础值 */
  baseHp: number
  /** 每级HP成长 */
  hpPerLevel: number
  /** 基础攻击力（用于狂暴反击伤害计算） */
  baseAttack: number
  /** 描述 */
  description: string
  /** 阶段定义（BOSS才有，小怪/精英为空数组） */
  phases?: MonsterPhase[]
  /** 狂暴血量阈值 (0-1, 低于此比例触发狂暴) */
  enrageThreshold: number
  /** 狂暴倍率 */
  enrageMultiplier: number
  /** 击败奖励金币倍率 */
  coinMultiplier: number
  /** 赛季标记（可选） */
  season?: 'spring' | 'summer' | 'autumn' | 'winter'
  /** 背景故事引用（可选，详情见 monsterStories.ts） */
  story?: string
  // ========== 护盾系统 ==========
  /** 护盾基础值 */
  baseShield: number
  /** 每级护盾成长 */
  shieldPerLevel: number
  /** 护盾减伤率 (0-1)，护盾存在时怪物本体受到的伤害比例
   *  例如 0.3 表示护盾存在时，怪物本体只承受 30% 的伤害，护盾承担全额 */
  shieldReductionRate: number
}

// ========== 12种怪物定义 ==========

export const MONSTER_DEFS: MonsterDef[] = [
  // ---- 小怪 (Minion) ----
  {
    id: 'slime',
    name: '懒惰史莱姆',
    emoji: '🟢',
    tier: 'minion',
    weakness: 'cardio',
    affinity: 'core',
    baseHp: 100,
    hpPerLevel: 30,
    baseAttack: 5,
    description: '软绵绵的果冻怪，看上去人畜无害，但会让你越来越懒。',
    enrageThreshold: 0.2,
    enrageMultiplier: 1.3,
    coinMultiplier: 1,
    baseShield: 20,
    shieldPerLevel: 5,
    shieldReductionRate: 0.15,
  },
  {
    id: 'goblin',
    name: '贪吃哥布林',
    emoji: '👺',
    tier: 'minion',
    weakness: 'strength',
    affinity: 'cardio',
    baseHp: 120,
    hpPerLevel: 35,
    baseAttack: 8,
    description: '矮小的美食强盗，专门偷吃你的健康餐。',
    enrageThreshold: 0.2,
    enrageMultiplier: 1.3,
    coinMultiplier: 1,
    baseShield: 25,
    shieldPerLevel: 6,
    shieldReductionRate: 0.18,
  },
  {
    id: 'ghost',
    name: '肥胖幽灵',
    emoji: '👻',
    tier: 'minion',
    weakness: 'core',
    affinity: 'strength',
    baseHp: 110,
    hpPerLevel: 32,
    baseAttack: 7,
    description: '飘荡的脂肪之魂，你的每一口夜宵都在喂养它。',
    enrageThreshold: 0.2,
    enrageMultiplier: 1.4,
    coinMultiplier: 1,
    baseShield: 22,
    shieldPerLevel: 5,
    shieldReductionRate: 0.16,
  },
  {
    id: 'skeleton',
    name: '碳水骷髅',
    emoji: '💀',
    tier: 'minion',
    weakness: 'cardio',
    affinity: 'core',
    baseHp: 130,
    hpPerLevel: 38,
    baseAttack: 10,
    description: '由精制碳水构成的骨架，坚硬但脆弱。',
    enrageThreshold: 0.25,
    enrageMultiplier: 1.3,
    coinMultiplier: 1,
    baseShield: 28,
    shieldPerLevel: 6,
    shieldReductionRate: 0.2,
  },

  // ---- 精英怪 (Elite) ----
  {
    id: 'orc',
    name: '油腻兽人',
    emoji: '👹',
    tier: 'elite',
    weakness: 'strength',
    affinity: 'cardio',
    baseHp: 250,
    hpPerLevel: 50,
    baseAttack: 15,
    description: '浑身油脂的肌肉兽人，防御力极强，需要力量型运动才能击穿。',
    enrageThreshold: 0.3,
    enrageMultiplier: 1.5,
    coinMultiplier: 2,
    baseShield: 75,
    shieldPerLevel: 12,
    shieldReductionRate: 0.28,
    phases: [
      {
        name: '正常状态',
        hpThreshold: 1.0,
        emoji: '👹',
        damageBonus: 1.0,
        desc: '油腻兽人正在观察你的动作。',
      },
      {
        name: '油脂爆发',
        hpThreshold: 0.5,
        emoji: '😤',
        damageBonus: 1.3,
        desc: '兽人进入油脂爆发状态，攻击力提升！',
      },
    ],
  },
  {
    id: 'vampire',
    name: '甜点吸血鬼',
    emoji: '🧛',
    tier: 'elite',
    weakness: 'core',
    affinity: 'strength',
    baseHp: 280,
    hpPerLevel: 55,
    baseAttack: 18,
    description: '以甜点为食的暗夜贵族，会在你吃甜食时回复生命。',
    enrageThreshold: 0.3,
    enrageMultiplier: 1.5,
    coinMultiplier: 2,
    baseShield: 85,
    shieldPerLevel: 14,
    shieldReductionRate: 0.3,
    phases: [
      {
        name: '优雅形态',
        hpThreshold: 1.0,
        emoji: '🧛',
        damageBonus: 1.0,
        desc: '吸血鬼优雅地品鉴着你的意志力。',
      },
      {
        name: '嗜血形态',
        hpThreshold: 0.5,
        emoji: '🦇',
        damageBonus: 1.4,
        desc: '吸血鬼露出獠牙，进入嗜血狂暴！',
      },
    ],
  },
  {
    id: 'dragon',
    name: '脂肪巨龙',
    emoji: '🐉',
    tier: 'elite',
    weakness: 'cardio',
    affinity: 'strength',
    baseHp: 320,
    hpPerLevel: 60,
    baseAttack: 20,
    description: '千年脂肪凝结的巨龙，需要大量有氧运动才能消耗它的体力。',
    enrageThreshold: 0.3,
    enrageMultiplier: 1.6,
    coinMultiplier: 2,
    baseShield: 100,
    shieldPerLevel: 15,
    shieldReductionRate: 0.32,
    phases: [
      {
        name: '慵懒形态',
        hpThreshold: 1.0,
        emoji: '🐉',
        damageBonus: 1.0,
        desc: '巨龙慵懒地趴在脂肪堆上。',
      },
      {
        name: '怒火形态',
        hpThreshold: 0.5,
        emoji: '🔥',
        damageBonus: 1.5,
        desc: '巨龙喷出卡路里火焰，怒火中烧！',
      },
    ],
  },

  // ---- BOSS ----
  {
    id: 'calorie_demon',
    name: '卡路里魔王',
    emoji: '👿',
    tier: 'boss',
    weakness: 'strength',
    affinity: 'cardio',
    baseHp: 500,
    hpPerLevel: 80,
    baseAttack: 25,
    description: '卡路里的化身，所有过量饮食的最终产物。力量型运动是它的克星。',
    enrageThreshold: 0.3,
    enrageMultiplier: 1.8,
    coinMultiplier: 3,
    baseShield: 180,
    shieldPerLevel: 25,
    shieldReductionRate: 0.35,
    phases: [
      {
        name: '傲慢阶段',
        hpThreshold: 1.0,
        emoji: '👿',
        damageBonus: 1.0,
        desc: '卡路里魔王傲慢地看着你，认为你不可能坚持下来。',
      },
      {
        name: '暴食阶段',
        hpThreshold: 0.6,
        emoji: '😤',
        damageBonus: 1.3,
        desc: '魔王进入暴食状态，试图用美食诱惑你放弃！',
      },
      {
        name: '虚弱阶段',
        hpThreshold: 0.25,
        emoji: '😵',
        damageBonus: 0.8,
        desc: '魔王的脂肪护甲破碎，露出虚弱的核心！此时伤害加成！',
      },
    ],
  },
  {
    id: 'glutton_lord',
    name: '暴食魔王',
    emoji: '😋',
    tier: 'boss',
    weakness: 'core',
    affinity: 'strength',
    baseHp: 550,
    hpPerLevel: 90,
    baseAttack: 28,
    description: '永远无法满足的暴食之主，核心训练能击碎它贪婪的核心。',
    enrageThreshold: 0.3,
    enrageMultiplier: 1.8,
    coinMultiplier: 3,
    baseShield: 200,
    shieldPerLevel: 28,
    shieldReductionRate: 0.35,
    phases: [
      {
        name: '盛宴阶段',
        hpThreshold: 1.0,
        emoji: '😋',
        damageBonus: 1.0,
        desc: '暴食魔王正在享用盛宴，无暇顾及你。',
      },
      {
        name: '饥饿阶段',
        hpThreshold: 0.55,
        emoji: '🤤',
        damageBonus: 1.4,
        desc: '魔王陷入饥饿狂暴，攻击力大幅提升！',
      },
      {
        name: '消化不良阶段',
        hpThreshold: 0.2,
        emoji: '🤢',
        damageBonus: 0.7,
        desc: '魔王消化不良，核心暴露！全力输出！',
      },
    ],
  },

  // ---- 最终BOSS ----
  {
    id: 'sloth_king',
    name: '懒惰之王',
    emoji: '👑',
    tier: 'finalboss',
    weakness: 'cardio',
    affinity: 'core',
    baseHp: 1000,
    hpPerLevel: 150,
    baseAttack: 35,
    description: '懒惰的终极化身。它不攻击你，只是让你放弃。只有有氧运动能唤醒你的意志。',
    enrageThreshold: 0.25,
    enrageMultiplier: 2.0,
    coinMultiplier: 5,
    baseShield: 450,
    shieldPerLevel: 45,
    shieldReductionRate: 0.4,
    phases: [
      {
        name: '慵懒王座',
        hpThreshold: 1.0,
        emoji: '👑',
        damageBonus: 1.0,
        desc: '懒惰之王坐在沙发上，懒洋洋地看着你挣扎。',
      },
      {
        name: '烦躁阶段',
        hpThreshold: 0.65,
        emoji: '😒',
        damageBonus: 1.2,
        desc: '你的坚持让懒惰之王开始烦躁了。',
      },
      {
        name: '恐慌阶段',
        hpThreshold: 0.35,
        emoji: '😱',
        damageBonus: 1.6,
        desc: '懒惰之王发现你真的要改变了！它开始疯狂反击！',
      },
      {
        name: '崩溃阶段',
        hpThreshold: 0.1,
        emoji: '💀',
        damageBonus: 0.5,
        desc: '懒惰之王的王座崩塌！给予最后一击！',
      },
    ],
  },
  {
    id: 'desire_lord',
    name: '欲望之主',
    emoji: '😈',
    tier: 'finalboss',
    weakness: 'strength',
    affinity: 'cardio',
    baseHp: 1200,
    hpPerLevel: 180,
    baseAttack: 40,
    description: '所有食欲和惰欲的源头。力量训练能斩断它的欲望锁链。',
    enrageThreshold: 0.2,
    enrageMultiplier: 2.2,
    coinMultiplier: 5,
    baseShield: 550,
    shieldPerLevel: 55,
    shieldReductionRate: 0.42,
    phases: [
      {
        name: '诱惑阶段',
        hpThreshold: 1.0,
        emoji: '😈',
        damageBonus: 1.0,
        desc: '欲望之主用美食和安逸诱惑你放弃。',
      },
      {
        name: '威压阶段',
        hpThreshold: 0.6,
        emoji: '🔥',
        damageBonus: 1.4,
        desc: '欲望之主释放欲望威压，试图压垮你的意志！',
      },
      {
        name: '狂暴阶段',
        hpThreshold: 0.3,
        emoji: '💢',
        damageBonus: 1.8,
        desc: '欲望之主彻底狂暴！但它的防御已经破碎！',
      },
      {
        name: '消散阶段',
        hpThreshold: 0.08,
        emoji: '🌫️',
        damageBonus: 0.3,
        desc: '欲望之主正在消散...最后一击！',
      },
    ],
  },
]

// ========== 赛季限定怪物 ==========

export const SEASONAL_MONSTERS: MonsterDef[] = [
  {
    id: 'sakura_spirit',
    name: '樱花精灵',
    emoji: '🌸',
    tier: 'elite',
    weakness: 'cardio',
    affinity: 'core',
    baseHp: 300,
    hpPerLevel: 50,
    baseAttack: 15,
    description: '春季限定！樱花飘落间的慵懒精灵，用有氧运动唤醒它的活力。',
    enrageThreshold: 0.3,
    enrageMultiplier: 1.4,
    coinMultiplier: 3,
    baseShield: 80,
    shieldPerLevel: 12,
    shieldReductionRate: 0.28,
    season: 'spring',
    phases: [
      { name: '花眠', hpThreshold: 1.0, emoji: '🌸', damageBonus: 1.0, desc: '樱花精灵在花瓣中沉睡。' },
      { name: '花舞', hpThreshold: 0.5, emoji: '🌺', damageBonus: 1.3, desc: '樱花精灵翩翩起舞，速度加快！' },
    ],
  },
  {
    id: 'icecream_titan',
    name: '冰沙巨魔',
    emoji: '🍧',
    tier: 'boss',
    weakness: 'strength',
    affinity: 'cardio',
    baseHp: 600,
    hpPerLevel: 100,
    baseAttack: 30,
    description: '夏季限定！由冰淇淋和冷饮凝结而成的巨魔，力量训练能打碎它的冰甲。',
    enrageThreshold: 0.25,
    enrageMultiplier: 1.7,
    coinMultiplier: 4,
    baseShield: 210,
    shieldPerLevel: 28,
    shieldReductionRate: 0.35,
    season: 'summer',
    phases: [
      { name: '冰封', hpThreshold: 1.0, emoji: '🍧', damageBonus: 1.0, desc: '冰沙巨魔的冰甲闪闪发光。' },
      { name: '融化', hpThreshold: 0.5, emoji: '🧊', damageBonus: 1.3, desc: '冰甲开始融化，但巨魔更加凶猛！' },
      { name: '蒸发', hpThreshold: 0.2, emoji: '💨', damageBonus: 0.6, desc: '巨魔正在蒸发！全力输出！' },
    ],
  },
  {
    id: 'pumpkin_knight',
    name: '南瓜骑士',
    emoji: '🎃',
    tier: 'elite',
    weakness: 'strength',
    affinity: 'cardio',
    baseHp: 350,
    hpPerLevel: 60,
    baseAttack: 18,
    description: '秋季限定！丰收季的守护者，用甜食堆砌的盔甲坚不可摧。',
    enrageThreshold: 0.3,
    enrageMultiplier: 1.5,
    coinMultiplier: 3,
    baseShield: 100,
    shieldPerLevel: 15,
    shieldReductionRate: 0.3,
    season: 'autumn',
    phases: [
      { name: '丰收', hpThreshold: 1.0, emoji: '🎃', damageBonus: 1.0, desc: '南瓜骑士守护着丰收的甜食。' },
      { name: '枯萎', hpThreshold: 0.5, emoji: '🍂', damageBonus: 1.4, desc: '南瓜开始枯萎，骑士陷入狂暴！' },
    ],
  },
  {
    id: 'frost_troll',
    name: '寒霜巨魔',
    emoji: '❄️',
    tier: 'boss',
    weakness: 'core',
    affinity: 'strength',
    baseHp: 650,
    hpPerLevel: 110,
    baseAttack: 32,
    description: '冬季限定！由冬季惰性凝聚的巨魔，核心训练能击碎它的冰核。',
    enrageThreshold: 0.25,
    enrageMultiplier: 1.7,
    coinMultiplier: 4,
    baseShield: 230,
    shieldPerLevel: 30,
    shieldReductionRate: 0.35,
    season: 'winter',
    phases: [
      { name: '冰封', hpThreshold: 1.0, emoji: '❄️', damageBonus: 1.0, desc: '寒霜巨魔在暴风雪中沉睡。' },
      { name: '觉醒', hpThreshold: 0.5, emoji: '🥶', damageBonus: 1.4, desc: '巨魔被惊醒，暴风雪肆虐！' },
      { name: '碎裂', hpThreshold: 0.2, emoji: '💠', damageBonus: 0.5, desc: '冰核暴露！一击必杀！' },
    ],
  },
]

// ========== 辅助函数 ==========

/** 根据等级获取怪物定义 */
export function getMonsterDefByLevel(level: number): MonsterDef {
  const allMonsters = [...MONSTER_DEFS, ...SEASONAL_MONSTERS]

  // 每10级 = BOSS
  if (level % 10 === 0) {
    const bosses = allMonsters.filter(m => m.tier === 'boss')
    const idx = Math.floor(level / 10 - 1) % bosses.length
    return bosses[idx]
  }
  // 每5级 = 精英
  if (level % 5 === 0) {
    const elites = allMonsters.filter(m => m.tier === 'elite')
    const idx = Math.floor(level / 5 - 1) % elites.length
    return elites[idx]
  }
  // Level 50 = 最终BOSS
  if (level >= 50) {
    const finalBosses = allMonsters.filter(m => m.tier === 'finalboss')
    const idx = Math.floor((level - 50) / 10) % finalBosses.length
    return finalBosses[idx]
  }
  // 其余 = 小怪
  const minions = allMonsters.filter(m => m.tier === 'minion')
  const idx = (level - 1) % minions.length
  return minions[idx]
}

/** 计算怪物在指定等级的HP */
export function calculateMonsterHp(def: MonsterDef, level: number, difficulty: 'easy' | 'normal' | 'hard' = 'normal'): number {
  const diffMultiplier = difficulty === 'easy' ? 0.7 : difficulty === 'hard' ? 1.3 : 1.0
  return Math.round((def.baseHp + def.hpPerLevel * (level - 1)) * diffMultiplier)
}

/** 计算怪物在指定等级的护盾值 */
export function calculateMonsterShield(def: MonsterDef, level: number, difficulty: 'easy' | 'normal' | 'hard' = 'normal'): number {
  const diffMultiplier = difficulty === 'easy' ? 0.7 : difficulty === 'hard' ? 1.3 : 1.0
  return Math.round((def.baseShield + def.shieldPerLevel * (level - 1)) * diffMultiplier)
}

/** 计算运动类型对怪物的伤害倍率 */
export function getExerciseMultiplier(exerciseId: string, monsterWeakness: MonsterWeakness, monsterAffinity: ExerciseCategory): {
  multiplier: number
  isCounter: boolean
  isResisted: boolean
  label: string
} {
  const category = EXERCISE_CATEGORY[exerciseId]
  if (!category) return { multiplier: 1.0, isCounter: false, isResisted: false, label: '' }

  // 运动克制怪物 → 命中弱点
  if (COUNTER_MAP[category] === monsterAffinity) {
    return { multiplier: COUNTER_MULTIPLIER, isCounter: true, isResisted: false, label: '弱点命中' }
  }
  // 怪物抗性 → 伤害降低
  if (category === monsterWeakness) {
    // 运动类型正好是怪物弱点 → 额外加成
    return { multiplier: COUNTER_MULTIPLIER, isCounter: true, isResisted: false, label: '克制' }
  }
  // 怪物亲和性类型 → 被抵抗
  if (category === monsterAffinity) {
    return { multiplier: WEAK_MULTIPLIER, isCounter: false, isResisted: true, label: '被抵抗' }
  }

  return { multiplier: 1.0, isCounter: false, isResisted: false, label: '' }
}

/** 获取怪物当前阶段 */
export function getCurrentPhase(def: MonsterDef, hpPercentage: number): MonsterPhase | null {
  if (!def.phases || def.phases.length === 0) return null

  let currentPhase = def.phases[0]
  for (const phase of def.phases) {
    if (hpPercentage <= phase.hpThreshold) {
      currentPhase = phase
    }
  }
  return currentPhase
}

/** 判断怪物是否处于狂暴状态 */
export function isMonsterEnraged(def: MonsterDef, hpPercentage: number): boolean {
  return hpPercentage <= def.enrageThreshold
}

/** 获取怪物层级显示名称 */
export function getTierName(tier: MonsterTier): string {
  switch (tier) {
    case 'minion': return '小怪'
    case 'elite': return '精英'
    case 'boss': return 'BOSS'
    case 'finalboss': return '最终BOSS'
  }
}

/** 获取弱点运动类型显示名称 */
export function getWeaknessLabel(weakness: MonsterWeakness): string {
  switch (weakness) {
    case 'cardio': return '有氧运动'
    case 'strength': return '力量训练'
    case 'core': return '核心训练'
  }
}

/** 获取运动分类显示名称 */
export function getCategoryLabel(category: ExerciseCategory): string {
  switch (category) {
    case 'cardio': return '有氧'
    case 'strength': return '力量'
    case 'core': return '核心'
  }
}

/** 获取运动分类emoji */
export function getCategoryEmoji(category: ExerciseCategory): string {
  switch (category) {
    case 'cardio': return '🏃'
    case 'strength': return '💪'
    case 'core': return '🧘'
  }
}
