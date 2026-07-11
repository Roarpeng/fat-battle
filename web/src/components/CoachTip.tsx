import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { X } from 'lucide-react'

export interface CoachTipProps {
  message: string
  mood: 'encouraging' | 'concerned' | 'celebrating'
}

const moodConfig = {
  encouraging: {
    border: 'border-blue/30',
    bg: 'bg-blue/10',
    text: 'text-blue',
    iconBg: 'bg-blue/20',
  },
  concerned: {
    border: 'border-orange/30',
    bg: 'bg-orange/10',
    text: 'text-orange',
    iconBg: 'bg-orange/20',
  },
  celebrating: {
    border: 'border-purple/30',
    bg: 'bg-purple/10',
    text: 'text-purple',
    iconBg: 'bg-purple/20',
  },
}

const STORAGE_KEY = 'coach-tip-closed-date'

export default function CoachTip({ message, mood }: CoachTipProps) {
  const [visible, setVisible] = useState(true)

  useEffect(() => {
    const closedDate = localStorage.getItem(STORAGE_KEY)
    const today = new Date().toISOString().slice(0, 10)
    if (closedDate === today) {
      setVisible(false)
    }
  }, [])

  const handleClose = () => {
    const today = new Date().toISOString().slice(0, 10)
    localStorage.setItem(STORAGE_KEY, today)
    setVisible(false)
  }

  const config = moodConfig[mood]

  return (
    <AnimatePresence>
      {visible && (
        <motion.div
          initial={{ opacity: 0, y: -30, scale: 0.95 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: -20, scale: 0.95 }}
          transition={{ type: 'spring', stiffness: 300, damping: 25 }}
          className={`relative flex items-start gap-3 px-4 py-3 rounded-2xl border ${config.border} ${config.bg} backdrop-blur-sm`}
        >
          {/* AI 教练头像 */}
          <div className={`shrink-0 w-9 h-9 flex items-center justify-center rounded-full text-lg ${config.iconBg}`}>
            🤖
          </div>

          {/* 文案 */}
          <div className="flex-1 min-w-0">
            <p className={`text-sm font-medium leading-relaxed ${config.text}`}>
              {message}
            </p>
          </div>

          {/* 关闭按钮 */}
          <button
            onClick={handleClose}
            className="shrink-0 mt-0.5 w-6 h-6 flex items-center justify-center rounded-full hover:bg-white/10 transition-colors"
            aria-label="关闭提示"
          >
            <X size={14} className="text-text3" />
          </button>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
