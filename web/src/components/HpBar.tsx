import { motion } from 'framer-motion'

interface HpBarProps {
  current: number
  max: number
  showText?: boolean
  size?: 'sm' | 'md' | 'lg'
  color?: 'red' | 'green' | 'gold' | 'purple'
}

export default function HpBar({
  current,
  max,
  showText = true,
  size = 'md',
  color = 'red',
}: HpBarProps) {
  const percentage = Math.max(0, Math.min(100, (current / max) * 100))

  const heightMap = {
    sm: 'h-3',
    md: 'h-5',
    lg: 'h-7',
  }

  const colorMap = {
    red: 'from-red to-red-dark',
    green: 'from-green to-green-dark',
    gold: 'from-gold to-gold-dark',
    purple: 'from-purple to-purple-dark',
  }

  const glowMap = {
    red: 'shadow-[0_0_10px_rgba(255,107,107,0.5)]',
    green: 'shadow-[0_0_10px_rgba(46,204,113,0.5)]',
    gold: 'shadow-[0_0_10px_rgba(255,217,61,0.5)]',
    purple: 'shadow-[0_0_10px_rgba(102,126,234,0.5)]',
  }

  return (
    <div className="w-full">
      <div
        className={`relative w-full ${heightMap[size]} bg-bg2 rounded-full overflow-hidden border border-border`}
      >
        <motion.div
          className={`absolute top-0 left-0 h-full bg-gradient-to-r ${colorMap[color]} ${glowMap[color]} rounded-full`}
          initial={{ width: 0 }}
          animate={{ width: `${percentage}%` }}
          transition={{ duration: 0.5, ease: 'easeOut' }}
        >
          <div className="absolute top-0 left-0 right-0 h-1/2 bg-white/20 rounded-full" />
        </motion.div>

        {showText && (
          <div className="absolute inset-0 flex items-center justify-center">
            <span className="text-xs font-bold text-white drop-shadow-md">
              {Math.round(current)} / {max}
            </span>
          </div>
        )}
      </div>
    </div>
  )
}
