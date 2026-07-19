import { useCallback, useRef, useState } from 'react'
import Toast, { ToastItem, ToastType } from './Toast'

export interface UseToastReturn {
  toasts: ToastItem[]
  showToast: (message: string, type?: ToastType, duration?: number) => string
  dismissToast: (id: string) => void
}

/**
 * 管理 Toast 列表的 hook：添加、移除、自动消失。
 * 自动消失由 Toast 组件内部的定时器触发 onDismiss 回调，
 * 再调用 dismissToast 从列表中移除。
 */
export function useToast(): UseToastReturn {
  const [toasts, setToasts] = useState<ToastItem[]>([])
  const counterRef = useRef(0)

  const dismissToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id))
  }, [])

  const showToast = useCallback(
    (message: string, type: ToastType = 'info', duration: number = 3000): string => {
      counterRef.current += 1
      const id = `toast-${Date.now()}-${counterRef.current}`
      setToasts((prev) => [...prev, { id, message, type, duration }])
      return id
    },
    [],
  )

  return { toasts, showToast, dismissToast }
}

interface ToastContainerProps {
  toasts: ToastItem[]
  onDismiss: (id: string) => void
}

/**
 * 独立的 Toast 容器组件，配合 useToast 使用：
 *
 * const { toasts, showToast, dismissToast } = useToast()
 * showToast('保存成功', 'success')
 * showToast('网络错误', 'error', 5000)
 * return <ToastContainer toasts={toasts} onDismiss={dismissToast} />
 */
export default function ToastContainer({ toasts, onDismiss }: ToastContainerProps) {
  return <Toast toasts={toasts} onDismiss={onDismiss} />
}
