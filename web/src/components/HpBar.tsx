import { motion } from 'framer-motion'

interface HpBarProps {
  current: number
  max: number
  showText?: boolean
  size?: 'sm' | 'md' | 'lg'
  color?: 'red' | 'green' | 'gold' | 'purple'
  overeatFactor?: number
}

export default function HpBar({
  current,
  max,
  showText = true,
  size = 'md',
  color = 'red',
  overeatFactor = 0,
}: HpBarProps) {
  const percentage = Math.max(0, Math.min(100, (current / max) * 100))

  const heightMap = {
    sm: 'h-3',
    md: 'h-5',
    lg: 'h-7',
  }

  const clampedFactor = Math.min(1, Math.max(0, overeatFactor))
  
  const red = 255
  const green = Math.round(107 + clampedFactor * (215 - 107))
  const blue = Math.round(107 - clampedFactor * 50)
  
  const glowIntensity = 0.5 + clampedFactor * 0.3

  return (
    <div className="w-full">
      <div
        className={`relative w-full ${heightMap[size]} bg-bg2 rounded-full overflow-hidden border border-border`}
      >
        <motion.div
          className="absolute top-0 left-0 h-full rounded-full"
          style={{
            background: `linear-gradient(to right, rgb(${red}, ${green}, ${blue}), rgb(${red - 30}, ${green - 20}, ${blue}))`,
            boxShadow: `0 0 10px rgba(${red}, ${green}, ${blue}, ${glowIntensity})`,
          }}
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
