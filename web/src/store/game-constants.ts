import type { AchievementDef, Skill, Item } from './game-types'

export const MONSTER_NAMES = ['脂肪怪', '油腻龙', '卡路里魔王', '肥肉巨人', '懒惰史莱姆', '肥胖幽灵', '甜点恶魔', '碳水巨兽']
export const MONSTER_EMOJIS = ['👹', '🐉', '👿', '🧟', '🟢', '👻', '😈', '🦣']

// ========== XP & 等级系统 ==========
export const XP_BASE = 100

export const LEVEL_TITLES = [
  '健身新手', '初级勇士', '运动学徒', '减脂先锋', '卡路里猎人',
  '脂肪终结者', '健身达人', '传奇勇士', '神话英雄', '减肥之神',
  '超越者', '永恒战士', '宇宙健身王', '时间主宰', '无限可能',
]

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
export const QUEST_TEMPLATES = [
  { type: 'exercise_count', title: '运动打卡', desc: '完成 {target} 次运动', baseTarget: [1, 2, 3] },
  { type: 'exercise_reps', title: '动作达人', desc: '累计完成 {target} 个动作', baseTarget: [20, 30, 50] },
  { type: 'diet_record', title: '健康饮食', desc: '记录 {target} 餐饮食', baseTarget: [2, 3, 4] },
  { type: 'calorie_limit', title: '热量控制', desc: '今日摄入不超过 {target} 千卡', baseTarget: [1500, 1800, 2000] },
  { type: 'attack_damage', title: '输出训练', desc: '对怪物造成 {target} 点伤害', baseTarget: [50, 100, 150] },
  { type: 'combo_count', title: '连击大师', desc: '达成 {target} 次连击', baseTarget: [3, 5, 8] },
]
