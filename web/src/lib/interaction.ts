// ==========================================
// 交互常量标准 (Microsoft Fluent 2 + Material Design 3 + Meta App)
// ==========================================

// --- Scale 常量 ---
export const TAP_SCALE = 0.95
export const HOVER_SCALE = 1.02
export const NAV_TAP_SCALE = 0.92
export const LIST_TAP_SCALE = 0.97

// --- 时长常量 (ms) ---
export const DURATION_TAP = 0.1        // 100ms
export const DURATION_NAV_TAP = 0.15   // 150ms
export const DURATION_PAGE_ENTER = 0.3  // 300ms
export const DURATION_PAGE_EXIT = 0.2   // 200ms
export const DURATION_DIALOG = 0.35     // 350ms
export const DURATION_MICRO = 0.15      // 150ms (checkbox等微反馈)
export const DURATION_LARGE = 0.5       // 500ms (大型过渡)
export const DURATION_STAGGER = 0.05    // 50ms per item
export const DURATION_STAGGER_ITEM = 0.25 // stagger item 入场

// --- Spring 常量 ---
export const SPRING_TAP = { type: 'spring' as const, stiffness: 400, damping: 20 }
export const SPRING_NAV_TAP = { type: 'spring' as const, stiffness: 300, damping: 15 }
export const SPRING_DIALOG = { type: 'spring' as const, stiffness: 300, damping: 25 }

// --- 页面转场 ---
export const pageTransition = {
  initial: { opacity: 0, y: 8 },
  animate: { opacity: 1, y: 0 },
  exit: { opacity: 0, y: -8 },
  transition: { duration: DURATION_PAGE_ENTER, ease: 'easeOut' as const },
}

// --- 弹窗转场 ---
export const dialogTransition = {
  initial: { opacity: 0, scale: 0.9 },
  animate: { opacity: 1, scale: 1 },
  exit: { opacity: 0, scale: 0.9 },
  transition: SPRING_DIALOG,
}

// --- Stagger 容器 ---
export const staggerContainer = {
  animate: {
    transition: { staggerChildren: DURATION_STAGGER },
  },
}

// --- Stagger 子项 ---
export const staggerItem = {
  initial: { opacity: 0, y: 12 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: DURATION_STAGGER_ITEM, ease: 'easeOut' as const },
}

// --- 删除动画 (slide out + fade) ---
export const deleteItem = {
  initial: { opacity: 1, x: 0 },
  exit: { opacity: 0, x: -60, transition: { duration: 0.2, ease: 'easeIn' as const } },
}

// --- 底部导航指示器过渡 ---
export const navIndicatorTransition = {
  type: 'spring' as const,
  stiffness: 400,
  damping: 30,
}

// --- State Layer overlay (Material 3) ---
// hover时叠加 bg-white/[0.08], press叠加 bg-white/[0.12]
// 这些通过 Tailwind class 实现: hover:bg-white/[0.08] active:bg-white/[0.12]

// --- 阴影层级 (Fluent 2) ---
// Control: shadow-sm
// Card resting: shadow-md
// Card hover: shadow-lg
// FAB/弹窗: shadow-xl
// Dialog: shadow-2xl
