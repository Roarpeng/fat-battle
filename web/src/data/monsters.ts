import type { Monster, MonsterType } from '../types/game';

export interface MonsterConfig {
  type: MonsterType;
  name: string;
  baseHp: number;
  baseAttack: number;
  baseDefense: number;
  emoji: string;
  description: string;
  unlockDay: number;
}

export const monsterConfigs: MonsterConfig[] = [
  {
    type: 'slime',
    name: '史莱姆',
    baseHp: 100,
    baseAttack: 5,
    baseDefense: 2,
    emoji: '🟢',
    description: '软绵绵的小怪物，是新手的最佳练习对象。它代表着减肥初期的小懒惰。',
    unlockDay: 1,
  },
  {
    type: 'goblin',
    name: '哥布林',
    baseHp: 200,
    baseAttack: 10,
    baseDefense: 5,
    emoji: '👺',
    description: '贪吃的小妖精，总是诱惑你吃垃圾食品。击败它需要坚定的意志力。',
    unlockDay: 4,
  },
  {
    type: 'ghost',
    name: '幽灵',
    baseHp: 350,
    baseAttack: 15,
    baseDefense: 8,
    emoji: '👻',
    description: '飘忽不定的幽灵，代表着难以捉摸的食欲。需要坚持运动才能驱散它。',
    unlockDay: 7,
  },
  {
    type: 'skeleton',
    name: '骷髅战士',
    baseHp: 500,
    baseAttack: 20,
    baseDefense: 12,
    emoji: '💀',
    description: '坚硬的骷髅战士，象征着顽固的脂肪。需要高强度训练才能击破。',
    unlockDay: 10,
  },
  {
    type: 'orc',
    name: '兽人',
    baseHp: 700,
    baseAttack: 28,
    baseDefense: 18,
    emoji: '👹',
    description: '强壮的兽人，代表着平台期的困难。需要改变策略才能继续前进。',
    unlockDay: 15,
  },
  {
    type: 'vampire',
    name: '吸血鬼',
    baseHp: 950,
    baseAttack: 35,
    baseDefense: 22,
    emoji: '🧛',
    description: '狡猾的吸血鬼，在夜晚尤其活跃。代表着夜宵和熬夜的诱惑。',
    unlockDay: 20,
  },
  {
    type: 'dragon',
    name: '恶龙',
    baseHp: 1300,
    baseAttack: 45,
    baseDefense: 30,
    emoji: '🐉',
    description: '强大的恶龙，是减肥路上的巨大挑战。需要全面的生活方式改变。',
    unlockDay: 25,
  },
  {
    type: 'boss',
    name: '脂肪魔王',
    baseHp: 2000,
    baseAttack: 60,
    baseDefense: 40,
    emoji: '👑',
    description: '最终Boss！脂肪的化身。只有最强的意志力和最健康的生活方式才能击败它。',
    unlockDay: 30,
  },
];

export function createMonster(
  config: MonsterConfig,
  day: number,
  playerBmi: number
): Monster {
  const dayMultiplier = 1 + (day - 1) * 0.15;
  const bmiMultiplier = Math.max(0.8, Math.min(1.5, playerBmi / 22));
  const maxHp = Math.round(config.baseHp * dayMultiplier * bmiMultiplier);
  const attack = Math.round(config.baseAttack * (1 + (day - 1) * 0.1));
  const defense = Math.round(config.baseDefense * (1 + (day - 1) * 0.08));

  return {
    id: `${config.type}-${day}-${Date.now()}`,
    type: config.type,
    name: config.name,
    maxHp,
    currentHp: maxHp,
    attack,
    defense,
    level: Math.ceil(day / 3),
    day,
    emoji: config.emoji,
    description: config.description,
    isDefeated: false,
  };
}

export function getMonsterByDay(day: number): MonsterConfig | null {
  const available = monsterConfigs.filter((m) => m.unlockDay <= day);
  if (available.length === 0) return null;

  const index = Math.min(
    Math.floor((day - 1) / 3),
    available.length - 1
  );
  return available[index];
}

export function getMonsterByType(type: MonsterType): MonsterConfig | undefined {
  return monsterConfigs.find((m) => m.type === type);
}

export const MONSTERS_PER_STAGE = 3;

export function getCurrentStage(day: number): number {
  return Math.ceil(day / MONSTERS_PER_STAGE);
}

export function getStageName(stage: number): string {
  const stages = [
    '新手村',
    '幽暗森林',
    '幽灵墓地',
    '骷髅洞窟',
    '兽人要塞',
    '暗夜城堡',
    '龙之巢穴',
    '魔王殿堂',
  ];
  return stages[Math.min(stage - 1, stages.length - 1)] || '未知区域';
}
