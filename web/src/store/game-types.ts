import type { Food, Exercise } from '../types/game'

export type Difficulty = 'easy' | 'normal' | 'hard'

export type Gender = 'male' | 'female'

export interface UserInfo {
  height: number
  weight: number
  targetWeight: number
  bmi: number
  difficulty: Difficulty
  role: string
  gender: Gender
}

export interface MonsterState {
  hp: number
  maxHp: number
  level: number
  name: string
  emoji: string
  type?: string
  // BOSS设计系统新增字段
  defId: string
  tier: 'minion' | 'elite' | 'boss' | 'finalboss'
  weakness: import('../data/monsters').ExerciseCategory
  affinity: import('../data/monsters').ExerciseCategory
  baseAttack: number
  description: string
  enrageThreshold: number
  enrageMultiplier: number
  coinMultiplier: number
  phaseIndex: number
  phaseName: string
  phaseEmoji: string
  isEnraged: boolean
  season?: 'spring' | 'summer' | 'autumn' | 'winter'
  // AI 教练动态难度倍率
  hpMultiplier?: number
  // 虚影机制：击败后第二天的怪物以虚影形态出现
  isPhantom: boolean
}

export interface PendingAttack {
  damage: number
  attackType: 'missile' | 'knife' | 'bomb' | 'fireball' | 'lightning' | 'grease'
  isOvereat: boolean
  overeatCalories?: number
  exerciseId?: string
  isCounter?: boolean
  isResisted?: boolean
  counterLabel?: string
}

export interface DailyStatus {
  intake: number
  exerciseBurn: number
  damage: number
  date: string
  pendingAttack: PendingAttack | null
  overeatCalories: number
  monsterDefeated: boolean
}

export interface DietRecord {
  id: string
  name: string
  calories: number
  time: number
}

export interface ExerciseRecord {
  id: string
  name: string
  calories: number
  time: number
  reps?: number
}

export interface WeeklyData {
  weekStart: string
  days: { date: string; weight?: number; calories?: number; exercise?: number }[]
}

// ========== 游戏化核心系统 ==========

/** 玩家等级系统 */
export interface PlayerLevel {
  level: number      // 当前等级 1-30
  xp: number         // 当前等级内的经验值
  totalXp: number    // 累计总经验值
}

/** 成就定义 */
export interface AchievementDef {
  id: string
  name: string
  description: string
  icon: string
  category: 'exercise' | 'diet' | 'battle' | 'streak' | 'milestone'
  rarity: 'common' | 'rare' | 'epic' | 'legendary'
  conditionType: string
  conditionValue: number
  reward: number
}

/** 成就进度 */
export interface AchievementProgress {
  id: string
  unlocked: boolean
  unlockedAt?: string
  progress: number
}

/** 每日任务 */
export interface DailyQuest {
  id: string
  title: string
  description: string
  type: 'exercise_count' | 'exercise_reps' | 'diet_record' | 'calorie_limit' | 'attack_damage' | 'combo_count'
  target: number
  current: number
  completed: boolean
  rewardCoins: number
  rewardXp: number
}

/** 技能 */
export interface Skill {
  id: string
  name: string
  description: string
  icon: string
  unlocked: boolean
  unlockedAtLevel: number
  effectDesc: string
}

/** 道具 */
export interface Item {
  id: string
  name: string
  description: string
  icon: string
  quantity: number
  effectDesc: string
}

// 向后兼容：重导出常量与工具函数
export * from './game-constants'
export * from './game-utils'
