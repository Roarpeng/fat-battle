import { useEffect, useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { CheckCircle, XCircle, AlertCircle, Info, X } from 'lucide-react'

export type ToastType = 'success' | 'error' | 'warning' | 'info'

interface ToastProps {
  message: string
  type?: ToastType
  duration?: number
  onClose?: () => void
  visible?: boolean
}

const iconMap = {
  success: CheckCircle,
  error: XCircle,
  warning: AlertCircle,
  info: Info,
}

const colorMap = {
  success: 'text-green border-green/30 bg-green/10',
  error: 'text-red border-red/30 bg-red/10',
  warning: 'text-gold border-gold/30 bg-gold/10',
  info: 'text-blue border-blue/30 bg-blue/10',
}

export default function Toast({
  message,
  type = 'info',
  duration = 3000,
  onClose,
  visible: controlledVisible,
}: ToastProps) {
  const [internalVisible, setInternalVisible] = useState(false)
  const visible = controlledVisible !== undefined ? controlledVisible : internalVisible

  useEffect(() => {
    if (controlledVisible === undefined && message) {
      setInternalVisible(true)
      const timer = setTimeout(() => {
        setInternalVisible(false)
        onClose?.()
      }, duration)
      return () => clearTimeout(timer)
    }
  }, [message, duration, onClose, controlledVisible])

  const Icon = iconMap[type]

  return (
    <AnimatePresence>
      {visible && (
        <motion.div
          initial={{ opacity: 0, y: -20, scale: 0.9 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: -20, scale: 0.9 }}
          transition={{ duration: 0.3, ease: 'easeOut' }}
          className="fixed top-4 left-1/2 -translate-x-1/2 z-50 max-w-[400px] w-[90%]"
        >
          <div
            className={`flex items-center gap-3 px-4 py-3 rounded-xl border backdrop-blur-sm ${colorMap[type]}`}
          >
            <Icon size={20} />
            <p className="flex-1 text-sm font-medium text-text">{message}</p>
            <button
              onClick={() => {
                if (controlledVisible === undefined) {
                  setInternalVisible(false)
                }
                onClose?.()
              }}
              className="p-1 hover:bg-white/10 rounded-lg transition-colors"
            >
              <X size={16} />
            </button>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
