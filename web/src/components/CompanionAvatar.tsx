import { useState } from 'react'
import { motion } from 'framer-motion'
import { useGameStore } from '../store/useGameStore'
import { getCompanionStage, getMoodLabel } from '../data/companion'

interface CompanionAvatarProps {
  size?: number
}

const moodBorderMap = {
  happy: 'border-green',
  normal: 'border-blue',
  tired: 'border-orange',
  sad: 'border-red',
}

const moodIconMap = {
  happy: '😸',
  normal: '😐',
  tired: '😿',
  sad: '💔',
}

const moodTextColorMap = {
  happy: 'text-green',
  normal: 'text-blue',
  tired: 'text-orange',
  sad: 'text-red',
}

export default function CompanionAvatar({ size = 48 }: CompanionAvatarProps) {
  const { companion } = useGameStore()
  const [showTooltip, setShowTooltip] = useState(false)
  const stage = getCompanionStage(companion.defId, companion.level)

  const animations = {
    happy: {
      y: [0, -6, 0],
      transition: { duration: 0.6, repeat: Infinity, repeatDelay: 0.3 },
    },
    normal: {},
    tired: {
      rotate: [-2, 2, -2, 2, 0],
      transition: { duration: 0.5, repeat: Infinity, repeatDelay: 1.5 },
    },
    sad: {
      x: [-3, 3, -3, 3, 0],
      transition: { duration: 0.4, repeat: Infinity, repeatDelay: 0.5 },
    },
  }

  return (
    <div
      className="relative inline-flex flex-col items-center"
      onMouseEnter={() => setShowTooltip(true)}
      onMouseLeave={() => setShowTooltip(false)}
    >
      <motion.div
        animate={animations[companion.mood]}
        className={`relative flex items-center justify-center rounded-full border-2 ${moodBorderMap[companion.mood]} bg-card cursor-pointer`}
        style={{ width: size, height: size }}
      >
        <span style={{ fontSize: size * 0.55 }}>{companion.emoji}</span>
        <span
          className="absolute -bottom-1 -right-1 text-xs bg-bg border border-border rounded-full px-1"
        >
          {moodIconMap[companion.mood]}
        </span>
      </motion.div>

      <span className="text-[10px] font-bold text-text3 mt-0.5">Lv.{companion.level}</span>

      {showTooltip && (
        <motion.div
          initial={{ opacity: 0, y: 4 }}
          animate={{ opacity: 1, y: 0 }}
          className="absolute bottom-full mb-2 z-30 w-44 bg-card border border-border rounded-xl p-3 shadow-xl"
        >
          <div className="flex items-center gap-2 mb-2">
            <span className="text-xl">{companion.emoji}</span>
            <div>
              <div className="text-sm font-bold text-text">{companion.name}</div>
              <div className="text-[10px] text-text3">{stage.name} · {getMoodLabel(companion.mood)}</div>
            </div>
          </div>

          <div className="space-y-2">
            <div>
              <div className="flex justify-between text-[10px] text-text3 mb-0.5">
                <span>饱食度</span>
                <span>{100 - companion.hunger}%</span>
              </div>
              <div className="h-1.5 bg-bg2 rounded-full overflow-hidden">
                <div
                  className="h-full bg-green rounded-full transition-all"
                  style={{ width: `${Math.max(0, 100 - companion.hunger)}%` }}
                />
              </div>
            </div>
            <div>
              <div className="flex justify-between text-[10px] text-text3 mb-0.5">
                <span>活力</span>
                <span>{companion.energy}%</span>
              </div>
              <div className="h-1.5 bg-bg2 rounded-full overflow-hidden">
                <div
                  className="h-full bg-blue rounded-full transition-all"
                  style={{ width: `${companion.energy}%` }}
                />
              </div>
            </div>
          </div>

          {companion.mood === 'sad' && (
            <div className={`mt-2 text-[10px] ${moodTextColorMap[companion.mood]} text-center`}>
              主人... 咪咪好饿...
            </div>
          )}
          {companion.mood === 'tired' && (
            <div className={`mt-2 text-[10px] ${moodTextColorMap[companion.mood]} text-center`}>
              主人... 咪咪累了...
            </div>
          )}
        </motion.div>
      )}
    </div>
  )
}
