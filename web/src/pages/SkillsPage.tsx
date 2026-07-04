import { motion } from 'framer-motion'
import { useNavigate } from 'react-router-dom'
import { ArrowLeft, Zap, Lock, Unlock, Sparkles, Shield, TrendingUp, Wind, Search, Magnet } from 'lucide-react'
import { useGameStore, SKILLS_DEF } from '../store/useGameStore'
import Card from '../components/Card'

const skillIconMap: Record<string, typeof Zap> = {
  crit_strike: Zap,
  endurance_aura: Shield,
  xp_boost: TrendingUp,
  coin_magnet: Magnet,
  second_wind: Wind,
  boss_weakness: Search,
}

export default function SkillsPage() {
  const navigate = useNavigate()
  const { playerLevel, skills } = useGameStore()

  const mergedSkills = SKILLS_DEF.map((def) => {
    const state = skills.find((s) => s.id === def.id)
    return { ...def, unlocked: state?.unlocked ?? false }
  })

  const unlockedCount = mergedSkills.filter((s) => s.unlocked).length

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
            <Sparkles size={20} className="text-purple" />
            技能系统
          </h1>
          <p className="text-text3 text-xs">解锁强力技能，让战斗更轻松</p>
        </div>
      </div>

      {/* 玩家等级 */}
      <Card className="bg-gradient-to-r from-purple/10 to-blue/10 border-purple/30">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 rounded-full bg-gradient-to-br from-purple to-blue flex items-center justify-center text-white text-lg font-black shadow-lg shadow-purple/20">
            Lv.{playerLevel.level}
          </div>
          <div className="flex-1">
            <div className="text-sm font-bold text-text">当前等级</div>
            <div className="text-[10px] text-text3">已解锁 {unlockedCount} / {mergedSkills.length} 个技能</div>
          </div>
          <div className="text-right">
            <div className="text-xs text-text3">总经验</div>
            <div className="text-sm font-bold text-purple">{playerLevel.totalXp}</div>
          </div>
        </div>
      </Card>

      {/* 技能列表 */}
      <div className="flex flex-col gap-2">
        {mergedSkills.map((skill, index) => {
          const Icon = skillIconMap[skill.id] || Zap
          const isUnlocked = skill.unlocked
          const canUnlock = playerLevel.level >= skill.unlockedAtLevel

          return (
            <motion.div
              key={skill.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.06 }}
            >
              <Card
                className={`${
                  isUnlocked
                    ? 'bg-gradient-to-r from-purple/10 to-blue/10 border-purple/30'
                    : canUnlock
                      ? 'border-gold/30 bg-gold/5'
                      : 'border-border/50 bg-card/50 opacity-70'
                }`}
              >
                <div className="flex items-start gap-3">
                  {/* 图标 */}
                  <div
                    className={`w-11 h-11 rounded-xl flex items-center justify-center shrink-0 ${
                      isUnlocked
                        ? 'bg-gradient-to-br from-purple to-blue shadow-md shadow-purple/20'
                        : canUnlock
                          ? 'bg-gold/20'
                          : 'bg-bg2'
                    }`}
                  >
                    {isUnlocked ? (
                      <Icon size={20} className="text-white" />
                    ) : (
                      <Lock size={18} className="text-text3" />
                    )}
                  </div>

                  {/* 信息 */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <span className={`font-bold text-sm ${isUnlocked ? 'text-text' : 'text-text3'}`}>
                        {skill.name}
                      </span>
                      {isUnlocked ? (
                        <span className="flex items-center gap-0.5 text-[10px] px-1.5 py-0.5 rounded-full bg-green/20 text-green font-bold">
                          <Unlock size={10} /> 已解锁
                        </span>
                      ) : canUnlock ? (
                        <span className="flex items-center gap-0.5 text-[10px] px-1.5 py-0.5 rounded-full bg-gold/20 text-gold font-bold">
                          <Sparkles size={10} /> 可解锁
                        </span>
                      ) : (
                        <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-bg2 text-text3">
                          Lv.{skill.unlockedAtLevel} 解锁
                        </span>
                      )}
                    </div>
                    <p className="text-[10px] text-text3 mt-0.5">{skill.description}</p>

                    {/* 效果 */}
                    <div className="mt-2 flex items-center gap-1.5">
                      <div className={`text-[10px] px-2 py-0.5 rounded-full font-bold ${
                        isUnlocked
                          ? 'bg-purple/20 text-purple'
                          : 'bg-bg2 text-text3'
                      }`}>
                        {skill.effectDesc}
                      </div>
                    </div>
                  </div>
                </div>
              </Card>
            </motion.div>
          )
        })}
      </div>

      {/* 提示 */}
      <div className="text-center text-[10px] text-text3 py-2">
        每升一级都会变得更强大~ 继续加油主人！
      </div>
    </div>
  )
}
