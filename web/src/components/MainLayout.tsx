import { Outlet, NavLink, useLocation } from 'react-router-dom'
import { motion, AnimatePresence } from 'framer-motion'
import { Cat, BarChart3 } from 'lucide-react'
import { pageTransition } from '../lib/interaction'

const tabs = [
  { path: '/', label: '首页', icon: Cat, end: true },
  { path: '/stats', label: '统计', icon: BarChart3 },
]

// 页面切换方向感知
function getDirection(pathname: string, prevPath: string): number {
  const tabIndex = tabs.findIndex(t => t.path === pathname)
  const prevIndex = tabs.findIndex(t => t.path === prevPath)
  if (tabIndex === -1 || prevIndex === -1) return 0
  return tabIndex > prevIndex ? 1 : -1
}

export default function MainLayout() {
  const location = useLocation()

  return (
    <div className="min-h-screen bg-bg flex flex-col">
      <main className="flex-1 pb-20 max-w-[480px] w-full mx-auto relative overflow-hidden">
        <AnimatePresence mode="wait" custom={location.pathname}>
          <motion.div
            key={location.pathname}
            initial="initial"
            animate="animate"
            exit="exit"
            variants={{
              initial: (dir: number) => ({
                opacity: 0,
                x: dir > 0 ? 30 : dir < 0 ? -30 : 0,
              }),
              animate: {
                opacity: 1,
                x: 0,
                transition: { duration: 0.3, ease: [0.2, 0, 0, 1] },
              },
              exit: {
                opacity: 0,
                x: 0,
                transition: { duration: 0.15, ease: 'easeIn' },
              },
            }}
            custom={location.pathname}
            className="h-full min-h-[calc(100vh-5rem)]"
          >
            <Outlet />
          </motion.div>
        </AnimatePresence>
      </main>

      {/* 底部导航 — Instagram/TikTok 风格 */}
      <nav className="fixed bottom-0 left-1/2 -translate-x-1/2 w-full max-w-[480px] bg-card/95 backdrop-blur-xl border-t border-border z-50">
        <div className="flex items-stretch justify-around px-4">
          {tabs.map((tab) => (
            <NavLink
              key={tab.path}
              to={tab.path}
              end={tab.end}
              className="flex-1"
            >
              {({ isActive }) => (
                <motion.div
                  whileTap={{ scale: 0.88 }}
                  transition={{ type: 'spring', stiffness: 400, damping: 17 }}
                  className={`relative flex flex-col items-center justify-center gap-1 py-2.5 min-h-[56px] transition-colors duration-200 ${
                    isActive ? 'text-red' : 'text-text3'
                  }`}
                >
                  {/* 选中态背景气泡 */}
                  {isActive && (
                    <motion.div
                      layoutId="navActiveBg"
                      className="absolute inset-1 bg-red/10 rounded-2xl"
                      transition={{ type: 'spring', stiffness: 400, damping: 30 }}
                    />
                  )}

                  {/* 图标 — 选中时放大 */}
                  <motion.div
                    animate={{
                      scale: isActive ? 1.15 : 1,
                      y: isActive ? -1 : 0,
                    }}
                    transition={{ type: 'spring', stiffness: 400, damping: 15 }}
                    className="relative z-10"
                  >
                    <tab.icon
                      size={24}
                      strokeWidth={isActive ? 2.5 : 2}
                      className={isActive ? 'drop-shadow-[0_0_8px_rgba(255,107,107,0.4)]' : ''}
                    />
                  </motion.div>

                  {/* 文字 */}
                  <motion.span
                    animate={{
                      fontSize: isActive ? '11px' : '10px',
                      fontWeight: isActive ? 700 : 500,
                    }}
                    className="relative z-10"
                  >
                    {tab.label}
                  </motion.span>

                  {/* 选中指示器小圆点 */}
                  <motion.div
                    className="absolute bottom-1 w-1 h-1 rounded-full bg-red"
                    initial={false}
                    animate={{
                      opacity: isActive ? 1 : 0,
                      scale: isActive ? 1 : 0,
                    }}
                    transition={{ type: 'spring', stiffness: 400, damping: 20 }}
                  />
                </motion.div>
              )}
            </NavLink>
          ))}
        </div>
        {/* iOS safe area 底部留白 */}
        <div className="h-[env(safe-area-inset-bottom,0px)]" />
      </nav>
    </div>
  )
}
