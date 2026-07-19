import { useEffect, useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { CheckCircle, XCircle, AlertCircle, Info, X } from 'lucide-react'

export type ToastType = 'success' | 'warning' | 'error' | 'info'

export interface ToastItem {
  id: string
  message: string
  type: ToastType
  duration?: number // 自动消失时间，默认 3000ms
}

interface ToastProps {
  // 保持原有 props 向后兼容
  message?: string
  type?: ToastType
  duration?: number
  visible?: boolean
  onClose?: () => void
  // 新增：堆叠模式
  toasts?: ToastItem[]
  onDismiss?: (id: string) => void
}

const iconMap = {
  success: CheckCircle,
  error: XCircle,
  warning: AlertCircle,
  info: Info,
} as const

const colorMap = {
  success: 'text-green border-green/30 bg-green/10',
  error: 'text-red border-red/30 bg-red/10',
  warning: 'text-gold border-gold/30 bg-gold/10',
  info: 'text-blue border-blue/30 bg-blue/10',
} as const

const DEFAULT_DURATION = 3000

interface ToastCardProps {
  message: string
  type: ToastType
  onDismiss?: () => void
}

function ToastCard({ message, type, onDismiss }: ToastCardProps) {
  const Icon = iconMap[type]
  return (
    <div
      role="status"
      className={`flex items-center gap-3 px-4 py-3 rounded-xl border backdrop-blur-sm ${colorMap[type]}`}
    >
      <Icon size={20} className="shrink-0" />
      <p className="flex-1 text-sm font-medium text-text">{message}</p>
      {onDismiss && (
        <button
          type="button"
          onClick={onDismiss}
          aria-label="关闭"
          className="p-1 hover:bg-white/10 rounded-lg transition-colors shrink-0"
        >
          <X size={16} />
        </button>
      )}
    </div>
  )
}

interface ToastItemViewProps {
  item: ToastItem
  onDismiss?: (id: string) => void
}

function ToastItemView({ item, onDismiss }: ToastItemViewProps) {
  // 每个 toast 独立自动消失
  useEffect(() => {
    const dur = item.duration ?? DEFAULT_DURATION
    const timer = setTimeout(() => {
      onDismiss?.(item.id)
    }, dur)
    return () => clearTimeout(timer)
  }, [item.id, item.duration, onDismiss])

  return (
    <motion.div
      initial={{ opacity: 0, y: 40, scale: 0.9 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, y: 40, scale: 0.9 }}
      transition={{ duration: 0.3, ease: 'easeOut' }}
      className="w-full pointer-events-auto"
    >
      <ToastCard
        message={item.message}
        type={item.type}
        onDismiss={() => onDismiss?.(item.id)}
      />
    </motion.div>
  )
}

export default function Toast({
  message,
  type = 'info',
  duration = DEFAULT_DURATION,
  onClose,
  visible: controlledVisible,
  toasts,
  onDismiss,
}: ToastProps) {
  const isStackingMode = toasts !== undefined

  // Hooks 必须无条件调用
  const [internalVisible, setInternalVisible] = useState(false)
  const visible = controlledVisible !== undefined ? controlledVisible : internalVisible

  useEffect(() => {
    if (isStackingMode) return
    if (controlledVisible === undefined && message) {
      setInternalVisible(true)
      const timer = setTimeout(() => {
        setInternalVisible(false)
        onClose?.()
      }, duration)
      return () => clearTimeout(timer)
    }
  }, [message, duration, onClose, controlledVisible, isStackingMode])

  // 堆叠模式：从底部向上堆叠，移动端全宽底部固定
  if (isStackingMode) {
    return (
      <div
        aria-live="polite"
        className="fixed bottom-4 left-1/2 -translate-x-1/2 z-50 flex flex-col-reverse items-center gap-2 w-[calc(100%-2rem)] max-w-[400px] pointer-events-none"
      >
        <AnimatePresence>
          {toasts!.map((t) => (
            <ToastItemView key={t.id} item={t} onDismiss={onDismiss} />
          ))}
        </AnimatePresence>
      </div>
    )
  }

  // 兼容原有单 toast 模式
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
          <ToastCard
            message={message ?? ''}
            type={type}
            onDismiss={() => {
              if (controlledVisible === undefined) {
                setInternalVisible(false)
              }
              onClose?.()
            }}
          />
        </motion.div>
      )}
    </AnimatePresence>
  )
}
