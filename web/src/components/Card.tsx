import { motion } from 'framer-motion'
import { ReactNode } from 'react'

interface CardProps {
  children: ReactNode
  className?: string
  hoverable?: boolean
  onClick?: () => void
}

export default function Card({ children, className = '', hoverable = false, onClick }: CardProps) {
  return (
    <motion.div
      whileHover={hoverable ? { y: -2, boxShadow: '0 10px 30px rgba(0,0,0,0.3)' } : undefined}
      whileTap={hoverable ? { scale: 0.98 } : undefined}
      onClick={onClick}
      className={`
        bg-card border border-border rounded-2xl p-4
        ${hoverable ? 'cursor-pointer transition-shadow' : ''}
        ${className}
      `}
    >
      {children}
    </motion.div>
  )
}
