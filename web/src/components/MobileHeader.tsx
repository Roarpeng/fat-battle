import { motion } from 'framer-motion'
import { ArrowLeft } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { type ReactNode } from 'react'

interface MobileHeaderProps {
  /** 标题文字 */
  title: string
  /** 标题颜色渐变 (Tailwind class) */
  gradient?: string
  /** 返回路径，默认为 '/' */
  backTo?: string
  /** 右侧操作按钮 */
  rightAction?: ReactNode
  /** 是否使用 navigate(-1) 返回上一页 (默认 false，使用 backTo) */
  useHistoryBack?: boolean
}

/**
 * 移动端统一顶部导航栏
 *
 * 设计参考:
 * - iOS NavigationBar: 左侧返回按钮 + 居中标题 + 右侧操作
 * - Instagram/WeChat: sticky定位 + 半透明毛玻璃背景
 * - Material Design 3: 顶部App Bar规范
 *
 * 触摸目标: 返回按钮 44x44px (WCAG 2.1 AA)
 */
export default function MobileHeader({
  title,
  gradient = 'from-text to-text2',
  backTo = '/',
  rightAction,
  useHistoryBack = false,
}: MobileHeaderProps) {
  const navigate = useNavigate()

  const handleBack = () => {
    if (useHistoryBack) {
      navigate(-1)
    } else {
      navigate(backTo)
    }
  }

  return (
    <motion.header
      initial={{ opacity: 0, y: -10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.25, ease: 'easeOut' }}
      className="sticky top-0 z-40 flex items-center justify-between px-4 py-3 bg-bg/80 backdrop-blur-xl border-b border-border/50"
    >
      {/* 左侧返回按钮 — 44x44px 触摸目标 */}
      <motion.button
        whileTap={{ scale: 0.88 }}
        transition={{ type: 'spring', stiffness: 400, damping: 17 }}
        onClick={handleBack}
        className="flex items-center justify-center w-11 h-11 -ml-2 rounded-full hover:bg-white/[0.08] active:bg-white/[0.12] transition-colors"
        aria-label="返回"
      >
        <ArrowLeft size={22} className="text-text" />
      </motion.button>

      {/* 居中标题 */}
      <h1 className={`text-lg font-black bg-gradient-to-r ${gradient} bg-clip-text text-transparent`}>
        {title}
      </h1>

      {/* 右侧操作区域 */}
      <div className="w-11 flex items-center justify-end -mr-2">
        {rightAction}
      </div>
    </motion.header>
  )
}
