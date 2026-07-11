import { motion } from 'framer-motion'
import { ClipboardList, CheckCircle2, Zap, Gift, RotateCcw } from 'lucide-react'
import { useGameStore } from '../store/useGameStore'
import Card from '../components/Card'
import Button from '../components/Button'
import MobileHeader from '../components/MobileHeader'

export default function DailyQuestsPage() {
  const { dailyQuests, generateDailyQuests, playerLevel } = useGameStore()

  const completedCount = dailyQuests.filter((q) => q.completed).length
  const totalCount = dailyQuests.length
  const progressPercent = totalCount > 0 ? Math.round((completedCount / totalCount) * 100) : 0

  const handleRefresh = () => {
    // 允许手动刷新（消耗一定金币或只是重新生成）
    generateDailyQuests()
  }

  return (
    <div className="min-h-full flex flex-col px-4 py-4 gap-4 max-w-[480px] mx-auto">
      {/* Header */}
      <MobileHeader
        title="每日任务"
        gradient="from-blue to-purple"
        useHistoryBack
        rightAction={
          <Button variant="secondary" size="sm" icon={<RotateCcw size={12} />} onClick={handleRefresh}>
            刷新
          </Button>
        }
      />

      {/* 总体进度 */}
      <Card className="bg-gradient-to-r from-blue/10 to-purple/10 border-blue/30">
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-2">
            <div className="w-10 h-10 rounded-full bg-blue/20 flex items-center justify-center">
              <ClipboardList size={20} className="text-blue" />
            </div>
            <div>
              <div className="text-sm font-bold text-text">{completedCount} / {totalCount}</div>
              <div className="text-[10px] text-text3">今日完成</div>
            </div>
          </div>
          <div className="text-right">
            <div className="text-xl font-black text-blue">{progressPercent}%</div>
            <div className="text-[10px] text-text3">完成度</div>
          </div>
        </div>
        <div className="h-2 bg-bg2 rounded-full overflow-hidden">
          <motion.div
            className="h-full bg-gradient-to-r from-blue to-purple rounded-full"
            initial={{ width: 0 }}
            animate={{ width: `${progressPercent}%` }}
            transition={{ duration: 1 }}
          />
        </div>
        {progressPercent === 100 && totalCount > 0 && (
          <motion.div
            initial={{ opacity: 0, y: 5 }}
            animate={{ opacity: 1, y: 0 }}
            className="mt-2 text-center text-xs font-bold text-green"
          >
            🎉 今日任务全部完成！太棒了主人~
          </motion.div>
        )}
      </Card>

      {/* 等级信息 */}
      <div className="flex items-center gap-3 px-3 py-2 bg-card border border-border rounded-xl">
        <div className="w-8 h-8 rounded-full bg-gradient-to-br from-purple to-blue flex items-center justify-center text-white text-xs font-bold">
          Lv.{playerLevel.level}
        </div>
        <div className="flex-1">
          <div className="text-xs font-bold text-text">今日任务奖励倍率</div>
          <div className="text-[10px] text-text3">等级越高，任务奖励越丰厚</div>
        </div>
        <div className="text-xs font-bold text-gold">x1.0</div>
      </div>

      {/* 任务列表 */}
      <div className="flex flex-col gap-2">
        {dailyQuests.length === 0 && (
          <Card className="text-center py-8">
            <ClipboardList size={32} className="text-text3 mx-auto mb-2" />
            <p className="text-text3 text-sm">还没有今日任务</p>
            <p className="text-text3 text-xs mt-1">点击刷新按钮生成今日任务</p>
            <Button variant="purple" size="sm" className="mt-3" icon={<RotateCcw size={12} />} onClick={handleRefresh}>
              生成任务
            </Button>
          </Card>
        )}

        {dailyQuests.map((quest, index) => {
          const percent = Math.min(100, (quest.current / quest.target) * 100)
          return (
            <motion.div
              key={quest.id}
              initial={{ opacity: 0, x: -10 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: index * 0.08 }}
            >
              <Card
                className={`${
                  quest.completed
                    ? 'bg-gradient-to-r from-green/10 to-green-dark/10 border-green/40'
                    : ''
                }`}
              >
                <div className="flex items-start gap-3">
                  {/* 状态图标 */}
                  <div
                    className={`w-9 h-9 rounded-full flex items-center justify-center shrink-0 ${
                      quest.completed
                        ? 'bg-green/20'
                        : 'bg-bg2'
                    }`}
                  >
                    {quest.completed ? (
                      <CheckCircle2 size={18} className="text-green" />
                    ) : (
                      <ClipboardList size={16} className="text-text3" />
                    )}
                  </div>

                  {/* 内容 */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between">
                      <span className={`font-bold text-sm ${quest.completed ? 'text-green' : 'text-text'}`}>
                        {quest.title}
                      </span>
                      <div className="flex items-center gap-2 shrink-0">
                        <span className="flex items-center gap-0.5 text-gold text-[10px] font-bold">
                          <Gift size={10} /> {quest.rewardCoins}
                        </span>
                        <span className="flex items-center gap-0.5 text-purple text-[10px] font-bold">
                          <Zap size={10} /> {quest.rewardXp}XP
                        </span>
                      </div>
                    </div>
                    <p className="text-[10px] text-text3 mt-0.5">{quest.description}</p>

                    {/* 进度 */}
                    <div className="mt-2">
                      <div className="flex justify-between text-[9px] text-text3 mb-0.5">
                        <span>{quest.completed ? '已完成' : '进行中'}</span>
                        <span>
                          {quest.current} / {quest.target}
                        </span>
                      </div>
                      <div className="h-2 bg-bg2 rounded-full overflow-hidden">
                        <motion.div
                          className={`h-full rounded-full ${
                            quest.completed
                              ? 'bg-gradient-to-r from-green to-green-dark'
                              : 'bg-gradient-to-r from-blue to-purple'
                          }`}
                          initial={{ width: 0 }}
                          animate={{ width: `${percent}%` }}
                          transition={{ duration: 0.5, delay: index * 0.1 }}
                        />
                      </div>
                    </div>
                  </div>
                </div>
              </Card>
            </motion.div>
          )
        })}
      </div>
    </div>
  )
}
