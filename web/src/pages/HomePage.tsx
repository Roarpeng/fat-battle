import { useEffect, useMemo } from 'react'
import { motion } from 'framer-motion'
import { Sparkles, CheckCircle } from 'lucide-react'
import { useGameStore } from '../store/useGameStore'
import CoachTip from '../components/CoachTip'

export default function HomePage() {
  const {
    advice,
    lastAdviceDate,
    generateDailyQuests,
    setDifficulty,
    user,
    streak,
    weeklyData,
  } = useGameStore()

  const today = useMemo(() => {
    const d = new Date()
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
  }, [])

  // 如果今日还没有生成建议，自动调用
  useEffect(() => {
    if (lastAdviceDate !== today) {
      generateDailyQuests()
    }
  }, [lastAdviceDate, today, generateDailyQuests])

  const handleAcceptAdvice = () => {
    if (advice?.suggestedDifficulty && advice.suggestedDifficulty !== user.difficulty) {
      setDifficulty(advice.suggestedDifficulty)
    }
  }

  const getMood = () => {
    if (!advice) return 'encouraging' as const
    if (advice.monsterHpMultiplier > 1.0) return 'celebrating' as const
    if (advice.monsterHpMultiplier < 1.0) return 'concerned' as const
    return 'encouraging' as const
  }

  const completionRateText = useMemo(() => {
    if (!weeklyData?.days) return ''
    const sortedDays = [...weeklyData.days]
      .filter((d) => d.date)
      .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())
    const last3 = sortedDays.slice(0, 3)
    if (last3.length === 0) return ''
    const completed = last3.filter((d) => d.exercise && d.exercise > 0).length
    const rate = Math.round((completed / last3.length) * 100)
    return `最近三天完成率 ${rate}%`
  }, [weeklyData])

  const displayMessage = advice
    ? `${advice.message}${completionRateText ? `（${completionRateText}）` : ''}`
    : '主人~ 今天也要加油哦！'

  return (
    <div className="flex flex-col gap-4 px-4 py-3">
      {/* 页面标题 */}
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-black text-text">减肥大作战</h1>
        {streak > 0 && (
          <div className="flex items-center gap-1 px-2 py-1 bg-orange/10 rounded-full">
            <span className="text-sm">🔥</span>
            <span className="text-sm font-bold text-orange">{streak} 天</span>
          </div>
        )}
      </div>

      {/* AI 教练提示 */}
      <CoachTip message={displayMessage} mood={getMood()} />

      {/* 建议卡片 */}
      {advice && advice.suggestedDifficulty !== user.difficulty && (
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          className="flex flex-col gap-3 p-4 bg-card border border-border rounded-2xl"
        >
          <div className="flex items-center gap-2">
            <Sparkles size={18} className="text-gold" />
            <span className="font-bold text-text">AI 教练建议</span>
          </div>
          <p className="text-sm text-text2">
            当前难度：<span className="font-bold text-text">{user.difficulty === 'easy' ? '简单' : user.difficulty === 'hard' ? '困难' : '普通'}</span>
            {' → '}
            建议难度：<span className="font-bold text-gold">{advice.suggestedDifficulty === 'easy' ? '简单' : advice.suggestedDifficulty === 'hard' ? '困难' : '普通'}</span>
          </p>
          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={handleAcceptAdvice}
            className="flex items-center justify-center gap-2 w-full py-2.5 bg-gradient-to-r from-gold/20 to-gold-dark/20 border border-gold/40 rounded-xl text-gold font-bold text-sm hover:bg-gold/30 transition-colors"
          >
            <CheckCircle size={16} />
            接受建议
          </motion.button>
        </motion.div>
      )}
    </div>
  )
}
