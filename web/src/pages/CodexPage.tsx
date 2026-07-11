import { useState, useMemo } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import {
  BookOpen,
  Lock,
  Unlock,
  Search,
  Star,
  ChevronDown,
  ChevronUp,
  Swords,
  Shield,
  Zap,
  Sparkles,
  Crown,
  Ghost,
  Snowflake,
  Flower2,
  IceCreamCone,
  Carrot,
  Skull,
} from 'lucide-react'
import { useGameStore } from '../store/useGameStore'
import { MONSTER_DEFS, SEASONAL_MONSTERS, getMonsterDefByLevel, getTierName, getWeaknessLabel, getCategoryLabel, getCategoryEmoji, type MonsterTier } from '../data/monsters'
import { MONSTER_STORIES, getMonsterStory } from '../data/monsterStories'
import MobileHeader from '../components/MobileHeader'
import Card from '../components/Card'

type TierFilter = 'all' | MonsterTier

const tierTabs: { key: TierFilter; label: string; icon: typeof Star }[] = [
  { key: 'all', label: '全部', icon: BookOpen },
  { key: 'minion', label: '小怪', icon: Ghost },
  { key: 'elite', label: '精英', icon: Swords },
  { key: 'boss', label: 'BOSS', icon: Crown },
  { key: 'finalboss', label: '终极', icon: Skull },
]

const tierStyles: Record<MonsterTier, { bg: string; border: string; text: string; gradient: string }> = {
  minion: { bg: 'bg-green/10', border: 'border-green/30', text: 'text-green', gradient: 'from-green to-emerald' },
  elite: { bg: 'bg-blue/10', border: 'border-blue/30', text: 'text-blue', gradient: 'from-blue to-cyan' },
  boss: { bg: 'bg-purple/10', border: 'border-purple/30', text: 'text-purple', gradient: 'from-purple to-pink' },
  finalboss: { bg: 'bg-red/10', border: 'border-red/30', text: 'text-red', gradient: 'from-red to-orange' },
}

/** 怪物的首次出现等级 */
const MONSTER_UNLOCK_LEVEL: Record<string, number> = {
  slime: 1,
  goblin: 2,
  ghost: 3,
  skeleton: 4,
  orc: 5,
  dragon: 15,
  vampire: 25,
  calorie_demon: 10,
  glutton_lord: 20,
  sloth_king: 50,
  desire_lord: 60,
  sakura_spirit: 16,
  icecream_titan: 30,
  pumpkin_knight: 26,
  frost_troll: 40,
}

function getUnlockLevel(monsterId: string): number {
  return MONSTER_UNLOCK_LEVEL[monsterId] ?? 99
}

function isMonsterEncountered(monsterId: string, currentLevel: number): boolean {
  return currentLevel >= getUnlockLevel(monsterId)
}

function getDefeatCount(monsterId: string, currentLevel: number): number {
  let count = 0
  for (let lv = 1; lv < currentLevel; lv++) {
    const def = getMonsterDefByLevel(lv)
    if (def.id === monsterId) count++
  }
  return count
}

function getSeasonIcon(season?: string) {
  switch (season) {
    case 'spring': return <Flower2 size={14} className="text-pink" />
    case 'summer': return <IceCreamCone size={14} className="text-orange" />
    case 'autumn': return <Carrot size={14} className="text-amber" />
    case 'winter': return <Snowflake size={14} className="text-cyan" />
    default: return null
  }
}

function getSeasonLabel(season?: string) {
  switch (season) {
    case 'spring': return '春季限定'
    case 'summer': return '夏季限定'
    case 'autumn': return '秋季限定'
    case 'winter': return '冬季限定'
    default: return ''
  }
}

export default function CodexPage() {
  const { monster } = useGameStore()
  const [activeTier, setActiveTier] = useState<TierFilter>('all')
  const [expandedId, setExpandedId] = useState<string | null>(null)

  const allDefs = useMemo(() => [...MONSTER_DEFS, ...SEASONAL_MONSTERS], [])

  const filtered = useMemo(() => {
    return allDefs.filter((m) => activeTier === 'all' || m.tier === activeTier)
  }, [allDefs, activeTier])

  const encounteredIds = useMemo(() => {
    return new Set(allDefs.filter((m) => isMonsterEncountered(m.id, monster.level)).map((m) => m.id))
  }, [allDefs, monster.level])

  const encounteredCount = encounteredIds.size
  const totalCount = allDefs.length
  const progressPercent = Math.round((encounteredCount / totalCount) * 100)

  const toggleExpand = (id: string) => {
    setExpandedId((prev) => (prev === id ? null : id))
  }

  return (
    <div className="min-h-full flex flex-col px-4 py-4 gap-4 max-w-[480px] mx-auto">
      {/* Header */}
      <MobileHeader title="怪物图鉴" gradient="from-purple to-pink" useHistoryBack />

      {/* 收集进度 */}
      <Card className="bg-gradient-to-r from-purple/10 to-pink/10 border-purple/30">
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-2">
            <div className="w-10 h-10 rounded-full bg-purple/20 flex items-center justify-center">
              <BookOpen size={20} className="text-purple" />
            </div>
            <div>
              <div className="text-sm font-bold text-text">
                已收集 {encounteredCount} / {totalCount}
              </div>
              <div className="text-[10px] text-text3">怪物图鉴完成度</div>
            </div>
          </div>
          <div className="text-right">
            <div className="text-xl font-black text-purple">{progressPercent}%</div>
            <div className="text-[10px] text-text3">完成度</div>
          </div>
        </div>
        <div className="h-2 bg-bg2 rounded-full overflow-hidden">
          <motion.div
            className="h-full bg-gradient-to-r from-purple to-pink rounded-full"
            initial={{ width: 0 }}
            animate={{ width: `${progressPercent}%` }}
            transition={{ duration: 1 }}
          />
        </div>
      </Card>

      {/* 分类筛选 */}
      <div className="flex gap-1.5 overflow-x-auto pb-1 -mx-1 px-1 scrollbar-hide">
        {tierTabs.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTier(tab.key)}
            className={`flex items-center gap-1 px-3 py-1.5 rounded-full text-xs font-bold whitespace-nowrap transition-all ${
              activeTier === tab.key
                ? 'bg-gradient-to-r from-purple to-pink text-white shadow-md'
                : 'bg-card border border-border text-text3 hover:text-text'
            }`}
          >
            <tab.icon size={12} />
            {tab.label}
          </button>
        ))}
      </div>

      {/* 怪物列表 */}
      <div className="flex flex-col gap-2">
        <AnimatePresence mode="popLayout">
          {filtered.map((def, index) => {
            const isEncountered = encounteredIds.has(def.id)
            const story = getMonsterStory(def.id)
            const style = tierStyles[def.tier]
            const isExpanded = expandedId === def.id
            const defeatCount = isEncountered ? getDefeatCount(def.id, monster.level) : 0
            const unlockLevel = getUnlockLevel(def.id)
            const seasonLabel = getSeasonLabel(def.season)

            return (
              <motion.div
                key={def.id}
                layout
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.95 }}
                transition={{ delay: index * 0.04 }}
              >
                <Card
                  hoverable={isEncountered}
                  onClick={() => isEncountered && toggleExpand(def.id)}
                  className={`${isEncountered ? style.border : 'border-border/50'} ${
                    isEncountered ? style.bg : 'bg-card/50'
                  } ${!isEncountered ? 'opacity-70' : ''}`}
                >
                  {/* 卡片头部 */}
                  <div className="flex items-center gap-3">
                    {/* Emoji / 剪影 */}
                    <div
                      className={`w-12 h-12 rounded-xl flex items-center justify-center text-2xl shrink-0 ${
                        isEncountered
                          ? 'bg-white/10'
                          : 'bg-bg2 grayscale'
                      }`}
                    >
                      {isEncountered ? def.emoji : '❓'}
                    </div>

                    {/* 信息 */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-1.5 flex-wrap">
                        <span className={`font-bold text-sm ${isEncountered ? 'text-text' : 'text-text3'}`}>
                          {isEncountered ? def.name : '？？？'}
                        </span>
                        <span
                          className={`text-[9px] px-1.5 py-0.5 rounded-full border ${style.border} ${style.text}`}
                        >
                          {getTierName(def.tier)}
                        </span>
                        {seasonLabel && (
                          <span className="text-[9px] px-1.5 py-0.5 rounded-full bg-pink/10 text-pink border border-pink/20 flex items-center gap-0.5">
                            {getSeasonIcon(def.season)}
                            {seasonLabel}
                          </span>
                        )}
                      </div>
                      <p className="text-[10px] text-text3 mt-0.5 truncate">
                        {isEncountered ? def.description : `完成 Level ${unlockLevel} 解锁`}
                      </p>
                    </div>

                    {/* 右侧状态 */}
                    <div className="shrink-0">
                      {isEncountered ? (
                        <div className="flex items-center gap-1 text-green">
                          <Unlock size={14} />
                          {isExpanded ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
                        </div>
                      ) : (
                        <Lock size={14} className="text-text3" />
                      )}
                    </div>
                  </div>

                  {/* 展开详情 */}
                  <AnimatePresence>
                    {isExpanded && isEncountered && story && (
                      <motion.div
                        initial={{ height: 0, opacity: 0 }}
                        animate={{ height: 'auto', opacity: 1 }}
                        exit={{ height: 0, opacity: 0 }}
                        transition={{ duration: 0.25, ease: 'easeInOut' }}
                        className="overflow-hidden"
                      >
                        <div className="pt-3 mt-3 border-t border-border/50 space-y-3">
                          {/* 属性信息 */}
                          <div className="grid grid-cols-3 gap-2">
                            <div className="bg-bg2/60 rounded-lg p-2 text-center">
                              <div className="text-[10px] text-text3 mb-0.5">弱点</div>
                              <div className="text-xs font-bold text-text flex items-center justify-center gap-1">
                                <span>{getCategoryEmoji(def.weakness)}</span>
                                {getWeaknessLabel(def.weakness)}
                              </div>
                            </div>
                            <div className="bg-bg2/60 rounded-lg p-2 text-center">
                              <div className="text-[10px] text-text3 mb-0.5">属性</div>
                              <div className="text-xs font-bold text-text flex items-center justify-center gap-1">
                                <span>{getCategoryEmoji(def.affinity)}</span>
                                {getCategoryLabel(def.affinity)}
                              </div>
                            </div>
                            <div className="bg-bg2/60 rounded-lg p-2 text-center">
                              <div className="text-[10px] text-text3 mb-0.5">击败次数</div>
                              <div className="text-xs font-bold text-text">{defeatCount}</div>
                            </div>
                          </div>

                          {/* 背景故事 lore */}
                          <div className="bg-bg2/40 rounded-xl p-3">
                            <div className="flex items-center gap-1.5 mb-1.5">
                              <BookOpen size={12} className="text-purple" />
                              <span className="text-xs font-bold text-text">背景故事</span>
                            </div>
                            <p className="text-[11px] text-text2 leading-relaxed">{story.lore}</p>
                          </div>

                          {/* 首次相遇 & 首次击败 */}
                          <div className="space-y-2">
                            <div className="flex gap-2 items-start">
                              <Sparkles size={12} className="text-gold mt-0.5 shrink-0" />
                              <div>
                                <div className="text-[10px] text-text3">首次相遇</div>
                                <div className="text-[11px] text-text italic">"{story.firstEncounter}"</div>
                              </div>
                            </div>
                            <div className="flex gap-2 items-start">
                              <Swords size={12} className="text-red mt-0.5 shrink-0" />
                              <div>
                                <div className="text-[10px] text-text3">首次击败</div>
                                <div className="text-[11px] text-text italic">"{story.firstDefeat}"</div>
                              </div>
                            </div>
                          </div>

                          {/* 趣味小知识 */}
                          <div className="bg-gradient-to-r from-gold/10 to-orange/10 border border-gold/20 rounded-xl p-3">
                            <div className="flex items-center gap-1.5 mb-1">
                              <Star size={12} className="text-gold fill-gold" />
                              <span className="text-xs font-bold text-gold">趣味小知识</span>
                            </div>
                            <p className="text-[11px] text-text2 leading-relaxed">{story.funFact}</p>
                          </div>

                          {/* 台词展示 */}
                          {(story.phaseChange.length > 0 || story.enrage.length > 0) && (
                            <div className="space-y-2">
                              {story.phaseChange.length > 0 && (
                                <div>
                                  <div className="text-[10px] text-text3 mb-1 flex items-center gap-1">
                                    <Zap size={10} />
                                    阶段切换台词
                                  </div>
                                  <div className="flex flex-wrap gap-1.5">
                                    {story.phaseChange.map((line, i) => (
                                      <span
                                        key={i}
                                        className="text-[10px] px-2 py-1 rounded-full bg-purple/10 text-purple border border-purple/20"
                                      >
                                        {line}
                                      </span>
                                    ))}
                                  </div>
                                </div>
                              )}
                              {story.enrage.length > 0 && (
                                <div>
                                  <div className="text-[10px] text-text3 mb-1 flex items-center gap-1">
                                    <Shield size={10} />
                                    狂暴台词
                                  </div>
                                  <div className="flex flex-wrap gap-1.5">
                                    {story.enrage.map((line, i) => (
                                      <span
                                        key={i}
                                        className="text-[10px] px-2 py-1 rounded-full bg-red/10 text-red border border-red/20"
                                      >
                                        {line}
                                      </span>
                                    ))}
                                  </div>
                                </div>
                              )}
                            </div>
                          )}

                          {/* 起源故事 */}
                          <div className="text-[10px] text-text3 leading-relaxed">
                            <span className="font-bold text-text2">起源：</span>
                            {story.origin}
                          </div>
                        </div>
                      </motion.div>
                    )}
                  </AnimatePresence>
                </Card>
              </motion.div>
            )
          })}
        </AnimatePresence>
      </div>

      {/* 空状态 */}
      {filtered.length === 0 && (
        <div className="text-center py-12">
          <Search size={40} className="text-text3 mx-auto mb-3 opacity-50" />
          <div className="text-sm text-text3">暂无该分类的怪物</div>
        </div>
      )}

      {/* 底部提示 */}
      <div className="text-center text-[10px] text-text3 py-2">
        继续战斗来解锁更多怪物吧，主人加油~
      </div>
    </div>
  )
}
