import { motion } from 'framer-motion'

interface DamageNumberProps {
  value: number
  type: 'damage' | 'heal'
}

export default function DamageNumber({ value, type }: DamageNumberProps) {
  const isDamage = type === 'damage'
  const prefix = isDamage ? '-' : '+'
  const colorClass = isDamage ? 'text-red' : 'text-green'

  return (
    <motion.div
      initial={{ opacity: 1, y: 0, scale: 0.5 }}
      animate={{ opacity: 0, y: -60, scale: 1.2 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.8, ease: 'easeOut' }}
      className={`absolute left-1/2 top-0 -translate-x-1/2 font-extrabold text-2xl md:text-3xl ${colorClass} pointer-events-none drop-shadow-lg z-10`}
      style={{ textShadow: isDamage ? '0 0 10px rgba(255,107,107,0.8)' : '0 0 10px rgba(46,204,113,0.8)' }}
    >
      {prefix}{value}
    </motion.div>
  )
}
