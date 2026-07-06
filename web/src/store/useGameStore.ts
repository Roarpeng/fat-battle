import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'
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
}

export interface PendingAttack {
  damage: number
  attackType: 'missile' | 'knife' | 'bomb' | 'fireball' | 'lightning' | 'grease'
  isOvereat: boolean
  overeatCalories?: number
}

export interface DailyStatus {
  intake: number
  exerciseBurn: number
  damage: number
  date: string
  pendingAttack: PendingAttack | null
  overeatCalories: number
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

export interface GameStateData {
  user: UserInfo
  monster: MonsterState
  daily: DailyStatus
  dietRecords: DietRecord[]
  exerciseRecords: ExerciseRecord[]
  coins: number
  days: number
  streak: number
  weeklyData: WeeklyData | null
  // 游戏化新增
  playerLevel: PlayerLevel
  achievements: AchievementProgress[]
  dailyQuests: DailyQuest[]
  skills: Skill[]
  items: Item[]
  lastQuestDate: string
  // 自定义数据
  customFoods: Food[]
  customExercises: Exercise[]
}

export interface GameStateActions {
  setUser: (user: Partial<UserInfo>) => void
  updateWeight: (weight: number) => void
  setDifficulty: (difficulty: Difficulty) => void
  attackMonster: (damage: number) => void
  healMonster: () => void
  levelUpMonster: () => void
  addDietRecord: (record: Omit<DietRecord, 'id'>) => void
  removeDietRecord: (id: string) => void
  addExerciseRecord: (record: Omit<ExerciseRecord, 'id'>) => void
  removeExerciseRecord: (id: string) => void
  addCoins: (amount: number) => void
  spendCoins: (amount: number) => boolean
  incrementStreak: () => void
  resetDailyIfNeeded: () => void
  resetGame: () => void
  // 虚标系统
  setPendingAttack: (attack: PendingAttack | null) => void
  setOvereatCalories: (calories: number) => void
  // 游戏化新增
  addXp: (amount: number) => { leveledUp: boolean; newLevel?: number }
  checkAchievements: () => AchievementProgress[]
  generateDailyQuests: () => void
  updateQuestProgress: (type: string, amount: number) => void
  useItem: (itemId: string) => boolean
  getActiveSkills: () => Skill[]
  // 自定义数据管理
  addCustomFood: (food: Food) => void
  removeCustomFood: (id: string) => void
  addCustomExercise: (exercise: Exercise) => void
  removeCustomExercise: (id: string) => void
}

export type GameState = GameStateData & GameStateActions

const MONSTER_NAMES = ['脂肪怪', '油腻龙', '卡路里魔王', '肥肉巨人', '懒惰史莱姆', '肥胖幽灵', '甜点恶魔', '碳水巨兽']
const MONSTER_EMOJIS = ['👹', '🐉', '👿', '🧟', '🟢', '👻', '😈', '🦣']

const getTodayStr = () => {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

const calculateBmi = (weight: number, height: number) => {
  if (height <= 0) return 0
  const h = height / 100
  return Number((weight / (h * h)).toFixed(1))
}

const generateMonster = (level: number): MonsterState => {
  const idx = (level - 1) % MONSTER_NAMES.length
  const baseHp = 100 + (level - 1) * 50
  return {
    hp: baseHp,
    maxHp: baseHp,
    level,
    name: MONSTER_NAMES[idx],
    emoji: MONSTER_EMOJIS[idx],
  }
}

// ========== XP & 等级系统 ==========
const XP_BASE = 100
const getXpToNextLevel = (level: number) => Math.floor(XP_BASE * Math.pow(1.15, level - 1))

const LEVEL_TITLES = [
  '健身新手', '初级勇士', '运动学徒', '减脂先锋', '卡路里猎人',
  '脂肪终结者', '健身达人', '传奇勇士', '神话英雄', '减肥之神',
  '超越者', '永恒战士', '宇宙健身王', '时间主宰', '无限可能',
]

export const getLevelTitle = (level: number) => {
  if (level <= 0) return LEVEL_TITLES[0]
  if (level > LEVEL_TITLES.length) return LEVEL_TITLES[LEVEL_TITLES.length - 1]
  return LEVEL_TITLES[level - 1]
}

// ========== 成就定义库 ==========
export const ACHIEVEMENTS_DEF: AchievementDef[] = [
  // 运动类
  { id: 'first_exercise', name: '初次锻炼', description: '完成第一次运动记录', icon: '🏃', category: 'exercise', rarity: 'common', conditionType: 'exercise_count', conditionValue: 1, reward: 10 },
  { id: 'exercise_10', name: '运动达人', description: '累计完成10次运动', icon: '🏆', category: 'exercise', rarity: 'common', conditionType: 'exercise_count', conditionValue: 10, reward: 30 },
  { id: 'exercise_50', name: '健身狂热', description: '累计完成50次运动', icon: '💪', category: 'exercise', rarity: 'rare', conditionType: 'exercise_count', conditionValue: 50, reward: 100 },
  { id: 'exercise_100', name: '运动传奇', description: '累计完成100次运动', icon: '👑', category: 'exercise', rarity: 'epic', conditionType: 'exercise_count', conditionValue: 100, reward: 300 },
  { id: 'reps_1000', name: '千次打卡', description: '累计完成1000个动作', icon: '🔢', category: 'exercise', rarity: 'epic', conditionType: 'total_reps', conditionValue: 1000, reward: 200 },
  { id: 'reps_10000', name: '万次王者', description: '累计完成10000个动作', icon: '🔥', category: 'exercise', rarity: 'legendary', conditionType: 'total_reps', conditionValue: 10000, reward: 1000 },
  // 饮食类
  { id: 'first_diet', name: '健康饮食', description: '记录第一餐', icon: '🥗', category: 'diet', rarity: 'common', conditionType: 'diet_count', conditionValue: 1, reward: 10 },
  { id: 'diet_30', name: '营养师', description: '累计记录30餐', icon: '🍎', category: 'diet', rarity: 'rare', conditionType: 'diet_count', conditionValue: 30, reward: 80 },
  // 战斗类
  { id: 'first_kill', name: '首杀', description: '击败第一只怪物', icon: '⚔️', category: 'battle', rarity: 'common', conditionType: 'monster_kills', conditionValue: 1, reward: 20 },
  { id: 'kill_10', name: '怪物猎人', description: '击败10只怪物', icon: '🎯', category: 'battle', rarity: 'rare', conditionType: 'monster_kills', conditionValue: 10, reward: 100 },
  { id: 'kill_50', name: '魔王克星', description: '击败50只怪物', icon: '💀', category: 'battle', rarity: 'epic', conditionType: 'monster_kills', conditionValue: 50, reward: 500 },
  { id: 'damage_1000', name: '千钧一击', description: '累计造成1000点伤害', icon: '💥', category: 'battle', rarity: 'rare', conditionType: 'total_damage', conditionValue: 1000, reward: 150 },
  // 连胜类
  { id: 'streak_3', name: '坚持三天', description: '连续打卡3天', icon: '🔥', category: 'streak', rarity: 'common', conditionType: 'streak_days', conditionValue: 3, reward: 30 },
  { id: 'streak_7', name: '一周战士', description: '连续打卡7天', icon: '📅', category: 'streak', rarity: 'rare', conditionType: 'streak_days', conditionValue: 7, reward: 100 },
  { id: 'streak_30', name: '月度冠军', description: '连续打卡30天', icon: '🏅', category: 'streak', rarity: 'epic', conditionType: 'streak_days', conditionValue: 30, reward: 500 },
  // 里程碑
  { id: 'level_5', name: '初露锋芒', description: '达到5级', icon: '⭐', category: 'milestone', rarity: 'common', conditionType: 'player_level', conditionValue: 5, reward: 50 },
  { id: 'level_10', name: '锋芒毕露', description: '达到10级', icon: '🌟', category: 'milestone', rarity: 'rare', conditionType: 'player_level', conditionValue: 10, reward: 150 },
  { id: 'level_20', name: '巅峰王者', description: '达到20级', icon: '👑', category: 'milestone', rarity: 'epic', conditionType: 'player_level', conditionValue: 20, reward: 500 },
  { id: 'coins_100', name: '小有积蓄', description: '累计获得100金币', icon: '💰', category: 'milestone', rarity: 'common', conditionType: 'total_coins', conditionValue: 100, reward: 20 },
  { id: 'coins_1000', name: '富翁', description: '累计获得1000金币', icon: '💎', category: 'milestone', rarity: 'epic', conditionType: 'total_coins', conditionValue: 1000, reward: 300 },
]

// ========== 技能定义库 ==========
export const SKILLS_DEF: Skill[] = [
  { id: 'crit_strike', name: '暴击', description: '运动时有几率造成双倍伤害', icon: '⚡', unlocked: false, unlockedAtLevel: 3, effectDesc: '20%几率伤害x2' },
  { id: 'endurance_aura', name: '耐力光环', description: '体力恢复速度提升', icon: '🛡️', unlocked: false, unlockedAtLevel: 5, effectDesc: '体力恢复+50%' },
  { id: 'xp_boost', name: '经验增幅', description: '获得的经验值增加', icon: '📈', unlocked: false, unlockedAtLevel: 7, effectDesc: 'XP获取+25%' },
  { id: 'coin_magnet', name: '吸金术', description: '击败怪物获得额外金币', icon: '🧲', unlocked: false, unlockedAtLevel: 10, effectDesc: '金币奖励+30%' },
  { id: 'second_wind', name: '第二 wind', description: '体力耗尽时自动恢复一次', icon: '💨', unlocked: false, unlockedAtLevel: 12, effectDesc: '每日1次自动回满体力' },
  { id: 'boss_weakness', name: '弱点洞察', description: 'Boss狂暴时伤害提升', icon: '🔍', unlocked: false, unlockedAtLevel: 15, effectDesc: 'Boss HP<30%时伤害+50%' },
]

// ========== 道具定义库 ==========
export const ITEMS_DEF: Omit<Item, 'quantity'>[] = [
  { id: 'energy_drink', name: '能量饮料', description: '恢复50点体力', icon: '🥤', effectDesc: '恢复50体力' },
  { id: 'lucky_coin', name: '幸运币', description: '使用后下次攻击伤害翻倍', icon: '🪙', effectDesc: '下次伤害x2' },
  { id: 'xp_scroll', name: '经验卷轴', description: '立即获得100经验值', icon: '📜', effectDesc: '+100 XP' },
  { id: 'shield_breaker', name: '破盾器', description: '清除怪物当前护盾', icon: '🔨', effectDesc: '清除护盾' },
]

// ========== 每日任务生成器 ==========
const QUEST_TEMPLATES = [
  { type: 'exercise_count', title: '运动打卡', desc: '完成 {target} 次运动', baseTarget: [1, 2, 3] },
  { type: 'exercise_reps', title: '动作达人', desc: '累计完成 {target} 个动作', baseTarget: [20, 30, 50] },
  { type: 'diet_record', title: '健康饮食', desc: '记录 {target} 餐饮食', baseTarget: [2, 3, 4] },
  { type: 'calorie_limit', title: '热量控制', desc: '今日摄入不超过 {target} 千卡', baseTarget: [1500, 1800, 2000] },
  { type: 'attack_damage', title: '输出训练', desc: '对怪物造成 {target} 点伤害', baseTarget: [50, 100, 150] },
  { type: 'combo_count', title: '连击大师', desc: '达成 {target} 次连击', baseTarget: [3, 5, 8] },
]

const getInitialWeeklyData = (): WeeklyData => {
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

const initialState: GameStateData = {
  user: {
    height: 170,
    weight: 70,
    targetWeight: 60,
    bmi: calculateBmi(70, 170),
    difficulty: 'normal',
    role: '战士',
    gender: 'male',
  },
  monster: generateMonster(1),
  daily: {
    intake: 0,
    exerciseBurn: 0,
    damage: 0,
    date: getTodayStr(),
    pendingAttack: null,
    overeatCalories: 0,
  },
  dietRecords: [],
  exerciseRecords: [],
  coins: 0,
  days: 1,
  streak: 0,
  weeklyData: getInitialWeeklyData(),
  // 游戏化初始状态
  playerLevel: { level: 1, xp: 0, totalXp: 0 },
  achievements: ACHIEVEMENTS_DEF.map((a) => ({ id: a.id, unlocked: false, progress: 0 })),
  dailyQuests: [],
  skills: JSON.parse(JSON.stringify(SKILLS_DEF)),
  items: ITEMS_DEF.map((i) => ({ ...i, quantity: 0 })),
  lastQuestDate: '',
  customFoods: [],
  customExercises: [],
}

export const useGameStore = create<GameState>()(
  persist(
    (set, get) => ({
      ...initialState,

      setUser: (user) =>
        set((state) => ({
          user: {
            ...state.user,
            ...user,
            bmi: calculateBmi(user.weight ?? state.user.weight, user.height ?? state.user.height),
          },
        })),

      updateWeight: (weight) =>
        set((state) => {
        const bmi = calculateBmi(weight, state.user.height)
        return { user: { ...state.user, weight, bmi } }
      }),

      setDifficulty: (difficulty) =>
        set((state) => ({ user: { ...state.user, difficulty } })),

      attackMonster: (damage) =>
        set((state) => {
          const newHp = Math.max(0, state.monster.hp - damage)
          const newDaily = { ...state.daily, damage: state.daily.damage + damage }
          if (newHp === 0) {
            const coinsEarned = state.monster.level * 10
            return {
              monster: generateMonster(state.monster.level + 1),
              coins: state.coins + coinsEarned,
              daily: newDaily,
            }
          }
          return { monster: { ...state.monster, hp: newHp }, daily: newDaily }
        }),

      healMonster: () =>
        set((state) => ({ monster: { ...state.monster, hp: state.monster.maxHp } })),

      levelUpMonster: () =>
        set((state) => ({ monster: generateMonster(state.monster.level + 1) })),

      addDietRecord: (record) =>
        set((state) => {
          const newRecord: DietRecord = {
            ...record,
            id: Date.now().toString() + Math.random().toString(36).slice(2, 8),
          }
          return {
            dietRecords: [newRecord, ...state.dietRecords],
            daily: { ...state.daily, intake: state.daily.intake + record.calories },
          }
        }),

      removeDietRecord: (id) =>
        set((state) => {
          const record = state.dietRecords.find((r) => r.id === id)
          if (!record) return state
          return {
            dietRecords: state.dietRecords.filter((r) => r.id !== id),
            daily: { ...state.daily, intake: Math.max(0, state.daily.intake - record.calories) },
          }
        }),

      addExerciseRecord: (record) =>
        set((state) => {
          const newRecord: ExerciseRecord = {
            ...record,
            id: Date.now().toString() + Math.random().toString(36).slice(2, 8),
          }
          return {
            exerciseRecords: [newRecord, ...state.exerciseRecords],
            daily: { ...state.daily, exerciseBurn: state.daily.exerciseBurn + record.calories },
          }
        }),

      removeExerciseRecord: (id) =>
        set((state) => {
          const record = state.exerciseRecords.find((r) => r.id === id)
          if (!record) return state
          return {
            exerciseRecords: state.exerciseRecords.filter((r) => r.id !== id),
            daily: {
              ...state.daily,
              exerciseBurn: Math.max(0, state.daily.exerciseBurn - record.calories),
            },
          }
        }),

      addCoins: (amount) => set((state) => ({ coins: state.coins + amount })),

      spendCoins: (amount) => {
        const state = get()
        if (state.coins < amount) return false
        set({ coins: state.coins - amount })
        return true
      },

      incrementStreak: () => set((state) => ({ streak: state.streak + 1 })),

      resetDailyIfNeeded: () => {
        const today = getTodayStr()
        const state = get()
        if (state.daily.date === today) return

        const yesterdayData = {
          date: state.daily.date,
          weight: state.user.weight,
          calories: state.daily.intake,
          exercise: state.daily.exerciseBurn,
        }
        let newWeekly: WeeklyData | null = state.weeklyData
        if (newWeekly) {
          newWeekly = {
            ...newWeekly,
            days: newWeekly.days.map((d) =>
              d.date === state.daily.date ? { ...d, ...yesterdayData } : d
            ),
          }
        }

        set({
          daily: { intake: 0, exerciseBurn: 0, damage: 0, date: today, pendingAttack: null, overeatCalories: 0 },
          days: state.days + 1,
          weeklyData: newWeekly,
        })
      },

      resetGame: () => set(initialState),

      setPendingAttack: (attack) =>
        set((state) => ({ daily: { ...state.daily, pendingAttack: attack } })),

      setOvereatCalories: (calories: number) =>
        set((state) => ({ daily: { ...state.daily, overeatCalories: calories } })),

      // ========== 游戏化核心 Action ==========

      /** 增加经验值，自动处理升级 */
      addXp: (amount) => {
        const state = get()
        let { level, xp, totalXp } = state.playerLevel
        totalXp += amount
        xp += amount
        let leveledUp = false
        let newLevel = level

        while (xp >= getXpToNextLevel(level)) {
          xp -= getXpToNextLevel(level)
          level += 1
          leveledUp = true
          newLevel = level
          // 升级时解锁技能
          const newSkills = state.skills.map((s) =>
            s.unlockedAtLevel <= level && !s.unlocked ? { ...s, unlocked: true } : s
          )
          set({ skills: newSkills })
        }

        set({ playerLevel: { level, xp, totalXp } })
        return { leveledUp, newLevel: leveledUp ? newLevel : undefined }
      },

      /** 检查并解锁成就，返回新解锁的成就 */
      checkAchievements: () => {
        const state = get()
        const today = getTodayStr()
        const totalReps = state.exerciseRecords.reduce((sum, r) => sum + (r.reps ?? 0), 0)
        const totalDamage = state.exerciseRecords.reduce((sum, r) => sum + (r.calories * 2), 0)
        const monsterKills = state.monster.level - 1
        const exerciseCount = state.exerciseRecords.length
        const dietCount = state.dietRecords.length
        const streakDays = state.streak
        const playerLvl = state.playerLevel.level

        let totalCoinReward = 0
        const newAchievements = state.achievements.map((ach) => {
          if (ach.unlocked) return ach
          const def = ACHIEVEMENTS_DEF.find((a) => a.id === ach.id)
          if (!def) return ach

          let progress = 0
          let shouldUnlock = false

          switch (def.conditionType) {
            case 'exercise_count':
              progress = exerciseCount
              shouldUnlock = exerciseCount >= def.conditionValue
              break
            case 'total_reps':
              progress = totalReps
              shouldUnlock = totalReps >= def.conditionValue
              break
            case 'diet_count':
              progress = dietCount
              shouldUnlock = dietCount >= def.conditionValue
              break
            case 'monster_kills':
              progress = monsterKills
              shouldUnlock = monsterKills >= def.conditionValue
              break
            case 'total_damage':
              progress = totalDamage
              shouldUnlock = totalDamage >= def.conditionValue
              break
            case 'streak_days':
              progress = streakDays
              shouldUnlock = streakDays >= def.conditionValue
              break
            case 'player_level':
              progress = playerLvl
              shouldUnlock = playerLvl >= def.conditionValue
              break
            case 'total_coins':
              progress = state.coins
              shouldUnlock = state.coins >= def.conditionValue
              break
          }

          if (shouldUnlock) {
            totalCoinReward += def.reward
            return { ...ach, unlocked: true, unlockedAt: today, progress: def.conditionValue }
          }
          return { ...ach, progress }
        })

        const newlyUnlocked = newAchievements.filter(
          (a) => a.unlocked && !state.achievements.find((sa) => sa.id === a.id)?.unlocked
        )

        if (totalCoinReward > 0) {
          set({ coins: state.coins + totalCoinReward, achievements: newAchievements })
        } else {
          set({ achievements: newAchievements })
        }
        return newlyUnlocked
      },

      /** 生成每日任务 */
      generateDailyQuests: () => {
        const state = get()
        const today = getTodayStr()
        if (state.lastQuestDate === today) return

        // 随机选3个任务
        const shuffled = [...QUEST_TEMPLATES].sort(() => Math.random() - 0.5)
        const selected = shuffled.slice(0, 3)

        const quests: DailyQuest[] = selected.map((q, i) => {
          const target = q.baseTarget[Math.floor(Math.random() * q.baseTarget.length)]
          return {
            id: `quest-${today}-${i}`,
            title: q.title,
            description: q.desc.replace('{target}', String(target)),
            type: q.type as DailyQuest['type'],
            target,
            current: 0,
            completed: false,
            rewardCoins: Math.floor(target * 0.5) + 5,
            rewardXp: Math.floor(target * 0.8) + 10,
          }
        })

        set({ dailyQuests: quests, lastQuestDate: today })
      },

      /** 更新任务进度 */
      updateQuestProgress: (type, amount) => {
        const state = get()
        const updatedQuests = state.dailyQuests.map((q) => {
          if (q.completed || q.type !== type) return q
          const newCurrent = q.current + amount
          const completed = newCurrent >= q.target
          if (completed) {
            // 完成任务奖励
            set({
              coins: state.coins + q.rewardCoins,
            })
            // 经验值通过 addXp 处理
          }
          return { ...q, current: Math.min(newCurrent, q.target), completed }
        })
        set({ dailyQuests: updatedQuests })
      },

      /** 使用道具 */
      useItem: (itemId) => {
        const state = get()
        const item = state.items.find((i) => i.id === itemId)
        if (!item || item.quantity <= 0) return false

        const newItems = state.items.map((i) =>
          i.id === itemId ? { ...i, quantity: i.quantity - 1 } : i
        )
        set({ items: newItems })
        return true
      },

      /** 获取已解锁的活跃技能 */
      getActiveSkills: () => {
        const state = get()
        return state.skills.filter((s) => s.unlocked)
      },

      // ========== 自定义数据管理 ==========
      addCustomFood: (food) =>
        set((state) => ({
          customFoods: [...state.customFoods, food],
        })),

      removeCustomFood: (id) =>
        set((state) => ({
          customFoods: state.customFoods.filter((f) => f.id !== id),
        })),

      addCustomExercise: (exercise) =>
        set((state) => ({
          customExercises: [...state.customExercises, exercise],
        })),

      removeCustomExercise: (id) =>
        set((state) => ({
          customExercises: state.customExercises.filter((e) => e.id !== id),
        })),
    }),
    {
      name: 'fat-battle-game-store',
      storage: createJSONStorage(() => localStorage),
      partialize: (state) => ({
        user: state.user,
        monster: state.monster,
        daily: state.daily,
        dietRecords: state.dietRecords,
        exerciseRecords: state.exerciseRecords,
        coins: state.coins,
        days: state.days,
        streak: state.streak,
        weeklyData: state.weeklyData,
        // 游戏化持久化
        playerLevel: state.playerLevel,
        achievements: state.achievements,
        dailyQuests: state.dailyQuests,
        skills: state.skills,
        items: state.items,
        lastQuestDate: state.lastQuestDate,
        // 自定义数据持久化
        customFoods: state.customFoods,
        customExercises: state.customExercises,
      }),
    }
  )
)
