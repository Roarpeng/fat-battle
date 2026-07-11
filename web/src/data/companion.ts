export interface CompanionDef {
  id: string
  name: string
  emoji: string
  description: string
  stages: CompanionStage[]
}

export interface CompanionStage {
  name: string
  emoji: string
  minLevel: number
  description: string
}

export interface CompanionState {
  defId: string
  name: string
  emoji: string
  level: number
  xp: number
  xpToNext: number
  mood: 'happy' | 'normal' | 'tired' | 'sad'
  hunger: number
  energy: number
  totalExercises: number
  totalDiets: number
  lastActiveDate: string
}

export const DEFAULT_COMPANION: CompanionDef = {
  id: 'cat',
  name: '咪咪',
  emoji: '🐱',
  description: '一只忠诚的战斗伙伴，陪伴主人一起变强！',
  stages: [
    {
      name: '小猫崽',
      emoji: '🐱',
      minLevel: 1,
      description: '刚出生的小猫咪，对一切都充满好奇~',
    },
    {
      name: '少年猫',
      emoji: '🐈',
      minLevel: 5,
      description: '活泼好动的少年猫，已经开始展现战斗天赋！',
    },
    {
      name: '成年猫',
      emoji: '🐈‍⬛',
      minLevel: 10,
      description: '成熟稳重的成年猫，是主人可靠的伙伴。',
    },
    {
      name: '猫战士',
      emoji: '🦁',
      minLevel: 20,
      description: '传说中的猫战士，威风凛凛，战无不胜！',
    },
  ],
}

export const COMPANIONS: CompanionDef[] = [DEFAULT_COMPANION]

export function getXpToNextLevel(level: number): number {
  return Math.round(50 * Math.pow(1.2, level - 1))
}

export function getCompanionStage(defId: string, level: number): CompanionStage {
  const def = COMPANIONS.find((c) => c.id === defId) || DEFAULT_COMPANION
  for (let i = def.stages.length - 1; i >= 0; i--) {
    if (level >= def.stages[i].minLevel) {
      return def.stages[i]
    }
  }
  return def.stages[0]
}

export function getCompanionDef(defId: string): CompanionDef {
  return COMPANIONS.find((c) => c.id === defId) || DEFAULT_COMPANION
}

export function getMoodLabel(mood: CompanionState['mood']): string {
  const labels: Record<CompanionState['mood'], string> = {
    happy: '开心',
    normal: '平静',
    tired: '疲惫',
    sad: '难过',
  }
  return labels[mood]
}

export function getMoodDescription(mood: CompanionState['mood']): string {
  const descriptions: Record<CompanionState['mood'], string> = {
    happy: '主人今天好棒！咪咪最喜欢你啦~',
    normal: '咪咪在悠闲地晒太阳呢~',
    tired: '主人... 咪咪有点累了，想休息一下...',
    sad: '主人... 咪咪好饿... 能不能给我一点吃的...',
  }
  return descriptions[mood]
}
