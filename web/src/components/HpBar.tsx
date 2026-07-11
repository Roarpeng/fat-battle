import { useEffect, useRef, useState } from 'react'
import { motion, useAnimation } from 'framer-motion'

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
  const isLowHp = percentage < 30 && percentage > 0
  const prevCurrent = useRef(current)
  const [isShaking, setIsShaking] = useState(false)
  const barControls = useAnimation()

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

  // HP 变化时触发水平抖动
  useEffect(() => {
    if (prevCurrent.current !== current) {
      setIsShaking(true)
      barControls.start({
        x: [-2, 2, -2, 2, 0],
        transition: { duration: 0.2, ease: 'easeInOut' },
      })
      const timer = setTimeout(() => setIsShaking(false), 200)
      prevCurrent.current = current
      return () => clearTimeout(timer)
    }
  }, [current, barControls])

  return (
    <div className="w-full">
      <motion.div
        className={`relative w-full ${heightMap[size]} bg-bg2 rounded-full overflow-hidden border border-border`}
        animate={barControls}
      >
        <motion.div
          className="absolute top-0 left-0 h-full rounded-full"
          style={{
            background: `linear-gradient(to right, rgb(${red}, ${green}, ${blue}), rgb(${red - 30}, ${green - 20}, ${blue}))`,
            boxShadow: isLowHp
              ? `0 0 10px rgba(${red}, ${green}, ${blue}, ${glowIntensity}), 0 0 20px rgba(255, 107, 107, 0.4)`
              : `0 0 10px rgba(${red}, ${green}, ${blue}, ${glowIntensity})`,
          }}
          initial={{ width: 0 }}
          animate={{
            width: `${percentage}%`,
            filter: isLowHp ? ['brightness(1)', 'brightness(1.4)', 'brightness(1)'] : 'brightness(1)',
          }}
          transition={{
            width: { duration: 0.5, ease: 'easeOut' },
            filter: isLowHp ? { duration: 1, repeat: Infinity, ease: 'easeInOut' } : { duration: 0 },
          }}
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
      </motion.div>
    </div>
  )
}
