import { Outlet, NavLink } from 'react-router-dom'
import { motion } from 'framer-motion'
import { Cat, BarChart3 } from 'lucide-react'

const tabs = [
  { path: '/', label: '首页', icon: Cat, end: true },
  { path: '/stats', label: '统计', icon: BarChart3 },
]

export default function MainLayout() {
  return (
    <div className="min-h-screen bg-bg flex flex-col">
      <main className="flex-1 pb-16 max-w-[480px] w-full mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3 }}
          className="h-full min-h-[calc(100vh-4rem)]"
        >
          <Outlet />
        </motion.div>
      </main>

      <nav className="fixed bottom-0 left-1/2 -translate-x-1/2 w-full max-w-[480px] bg-card border-t border-border z-50">
        <div className="flex items-center justify-around py-1.5 px-8">
          {tabs.map((tab) => (
            <NavLink
              key={tab.path}
              to={tab.path}
              end={tab.end}
              className={({ isActive }) =>
                `flex flex-col items-center justify-center gap-0.5 py-2 px-6 rounded-xl transition-all duration-200 ${
                  isActive
                    ? 'text-red bg-bg2'
                    : 'text-text3 hover:text-text2'
                }`
              }
            >
              {({ isActive }) => (
                <motion.div
                  whileTap={{ scale: 0.9 }}
                  className="flex flex-col items-center gap-0.5"
                >
                  <tab.icon
                    size={24}
                    strokeWidth={isActive ? 2.5 : 2}
                  />
                  <span className="text-xs font-medium">{tab.label}</span>
                </motion.div>
              )}
            </NavLink>
          ))}
        </div>
      </nav>
    </div>
  )
}
