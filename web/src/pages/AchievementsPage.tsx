import { useState } from 'react'
import { motion } from 'framer-motion'
import { useNavigate } from 'react-router-dom'
import { ArrowLeft, Trophy, Lock, Unlock, Flame, Utensils, Swords, Target, Star } from 'lucide-react'
import { useGameStore, ACHIEVEMENTS_DEF } from '../store/useGameStore'
import Card from '../components/Card'

type Category = 'all' | 'exercise' | 'diet' | 'battle' | 'streak' | 'milestone'

const categoryTabs: { key: Category; label: string; icon: typeof Trophy }[] = [
  { key: 'all', label: '全部', icon: Star },
  { key: 'exercise', label: '运动', icon: Flame },
  { key: 'diet', label: '饮食', icon: Utensils },
  { key: 'battle', label: '战斗', icon: Swords },
  { key: 'streak', label: '连胜', icon: Target },
  { key: 'milestone', label: '里程碑', icon: Trophy },
]

const rarityStyles: Record<string, { bg: string; border: string; text: string }> = {
  common: { bg: 'bg-gray-500/10', border: 'border-gray-500/30', text: 'text-gray-400' },
  rare: { bg: 'bg-blue-500/10', border: 'border-blue-500/30', text: 'text-blue-400' },
  epic: { bg: 'bg-purple-500/10', border: 'border-purple-500/30', text: 'text-purple-400' },
  legendary: { bg: 'bg-gold/10', border: 'border-gold/30', text: 'text-gold' },
}

const rarityNames: Record<string, string> = {
  common: '普通', rare: '稀有', epic: '史诗', legendary: '传说',
}

export default function AchievementsPage() {
  const navigate = useNavigate()
  const { achievements } = useGameStore()
  const [activeCategory, setActiveCategory] = useState<Category>('all')

  const filtered = ACHIEVEMENTS_DEF.map((def) => {
    const progress = achievements.find((a) => a.id === def.id)
    return { ...def, ...progress, progress: progress?.progress ?? 0 }
  }).filter((a) => activeCategory === 'all' || a.category === activeCategory)

  const unlockedCount = achievements.filter((a) => a.unlocked).length
  const totalCount = ACHIEVEMENTS_DEF.length
  const progressPercent = Math.round((unlockedCount / totalCount) * 100)

  return (
    <div className="min-h-full flex flex-col px-4 py-4 gap-4 max-w-[480px] mx-auto">
      {/* Header */}
      <div className="flex items-center gap-3">
        <button
          onClick={() => navigate(-1)}
          className="w-9 h-9 flex items-center justify-center bg-card border border-border rounded-full hover:bg-bg2 transition-colors"
        >
          <ArrowLeft size={18} className="text-text" />
        </button>
        <div className="flex-1">
          <h1 className="text-lg font-bold text-text flex items-center gap-2">
            <Trophy size={20} className="text-gold" />
            成就殿堂
          </h1>
          <p className="text-text3 text-xs">你的荣耀时刻，每一步都值得纪念</p>
        </div>
      </div>

      {/* 总体进度 */}
      <Card className="bg-gradient-to-r from-gold/10 to-orange/10 border-gold/30">
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-2">
            <div className="w-10 h-10 rounded-full bg-gold/20 flex items-center justify-center">
              <Trophy size={20} className="text-gold" />
            </div>
            <div>
              <div className="text-sm font-bold text-text">{unlockedCount} / {totalCount}</div>
              <div className="text-[10px] text-text3">已解锁成就</div>
            </div>
          </div>
          <div className="text-right">
            <div className="text-xl font-black text-gold">{progressPercent}%</div>
            <div className="text-[10px] text-text3">完成度</div>
          </div>
        </div>
        <div className="h-2 bg-bg2 rounded-full overflow-hidden">
          <motion.div
            className="h-full bg-gradient-to-r from-gold to-orange rounded-full"
            initial={{ width: 0 }}
            animate={{ width: `${progressPercent}%` }}
            transition={{ duration: 1 }}
          />
        </div>
      </Card>

      {/* 分类筛选 */}
      <div className="flex gap-1.5 overflow-x-auto pb-1 -mx-1 px-1 scrollbar-hide">
        {categoryTabs.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveCategory(tab.key)}
            className={`flex items-center gap-1 px-3 py-1.5 rounded-full text-xs font-bold whitespace-nowrap transition-all ${
              activeCategory === tab.key
                ? 'bg-gradient-to-r from-purple to-blue text-white shadow-md'
                : 'bg-card border border-border text-text3 hover:text-text'
            }`}
          >
            <tab.icon size={12} />
            {tab.label}
          </button>
        ))}
      </div>

      {/* 成就列表 */}
      <div className="grid grid-cols-1 gap-2">
        {filtered.map((ach, index) => {
          const style = rarityStyles[ach.rarity] || rarityStyles.common
          const isUnlocked = ach.unlocked
          return (
            <motion.div
              key={ach.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.03 }}
            >
              <Card
                className={`flex items-center gap-3 py-3 px-3 ${
                  isUnlocked ? style.border : 'border-border/50'
                } ${isUnlocked ? style.bg : 'bg-card/50'}`}
              >
                {/* 图标 */}
                <div
                  className={`w-11 h-11 rounded-xl flex items-center justify-center text-xl shrink-0 ${
                    isUnlocked
                      ? 'bg-white/10'
                      : 'bg-bg2 grayscale opacity-50'
                  }`}
                >
                  {ach.icon}
                </div>

                {/* 信息 */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-1.5">
                    <span className="font-bold text-sm text-text truncate">{ach.name}</span>
                    <span className={`text-[9px] px-1.5 py-0.5 rounded-full border ${style.border} ${style.text}`}>
                      {rarityNames[ach.rarity]}
                    </span>
                    {isUnlocked ? (
                      <Unlock size={12} className="text-green shrink-0" />
                    ) : (
                      <Lock size={12} className="text-text3 shrink-0" />
                    )}
                  </div>
                  <p className="text-[10px] text-text3 mt-0.5 truncate">{ach.description}</p>

                  {/* 进度条 */}
                  {!isUnlocked && (
                    <div className="mt-1.5">
                      <div className="flex justify-between text-[9px] text-text3 mb-0.5">
                        <span>进度</span>
                        <span>{ach.progress} / {ach.conditionValue}</span>
                      </div>
                      <div className="h-1.5 bg-bg2 rounded-full overflow-hidden">
                        <div
                          className="h-full bg-text3/40 rounded-full"
                          style={{ width: `${Math.min(100, (ach.progress / ach.conditionValue) * 100)}%` }}
                        />
                      </div>
                    </div>
                  )}
                </div>

                {/* 奖励 */}
                <div className={`text-right shrink-0 ${isUnlocked ? '' : 'opacity-40'}`}>
                  <div className="flex items-center gap-0.5 text-gold">
                    <Star size={10} className="fill-gold" />
                    <span className="text-xs font-bold">+{ach.reward}</span>
                  </div>
                  <div className="text-[9px] text-text3">{isUnlocked ? '已领取' : '未解锁'}</div>
                </div>
              </Card>
            </motion.div>
          )
        })}
      </div>
    </div>
  )
}
