import { Routes, Route, Navigate } from 'react-router-dom'
import { useEffect } from 'react'
import { useGameStore } from './store/useGameStore'
import WelcomePage from './pages/WelcomePage'
import SetupPage from './pages/SetupPage'
import BattlePage from './pages/BattlePage'
import FoodPage from './pages/FoodPage'
import ExercisePage from './pages/ExercisePage'
import StatsPage from './pages/StatsPage'
import SettingsPage from './pages/SettingsPage'
import PoseDetectionPage from './pages/PoseDetectionPage'
import BluetoothPage from './pages/BluetoothPage'
import AchievementsPage from './pages/AchievementsPage'
import DailyQuestsPage from './pages/DailyQuestsPage'
import SkillsPage from './pages/SkillsPage'
import CodexPage from './pages/CodexPage'
import CompanionPage from './pages/CompanionPage'
import MainLayout from './components/MainLayout'

export default function App() {
  const { user, daily, monster, resetDailyIfNeeded, spawnDailyMonster, spawnPhantomMonster, solidifyMonster } = useGameStore()

  const hasProfile = user.height > 0 && user.weight > 0

  // 每日重置：检查日期变化，重置日常数据并生成新的每日怪物
  useEffect(() => {
    if (!daily.date) {
      // 首次使用：直接生成第1天的怪物
      spawnDailyMonster()
    } else {
      const prevMonsterDefeated = daily.monsterDefeated
      const didReset = resetDailyIfNeeded()
      if (didReset) {
        // 日期变化了：如果昨天击败了怪物，今天怪物以虚影形态出现
        if (prevMonsterDefeated) {
          spawnPhantomMonster()
        } else {
          spawnDailyMonster()
        }
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // 虚影怪物自动凝实：如果怪物是虚影状态，几秒后自动凝实
  useEffect(() => {
    if (monster.isPhantom) {
      const timer = setTimeout(() => {
        solidifyMonster()
      }, 3000)
      return () => clearTimeout(timer)
    }
  }, [monster.isPhantom, solidifyMonster])

  return (
    <Routes>
      <Route path="/welcome" element={<WelcomePage />} />
      <Route path="/setup" element={hasProfile ? <SetupPage /> : <Navigate to="/welcome" replace />} />
      <Route path="/pose" element={<PoseDetectionPage />} />
      <Route path="/bluetooth" element={<BluetoothPage />} />
      <Route path="/achievements" element={<AchievementsPage />} />
      <Route path="/quests" element={<DailyQuestsPage />} />
      <Route path="/skills" element={<SkillsPage />} />
      <Route path="/codex" element={<CodexPage />} />
      <Route path="/companion" element={<CompanionPage />} />
      {/* 独立页面（不在 MainLayout 导航下） */}
      <Route path="/food" element={<FoodPage />} />
      <Route path="/exercise" element={<ExercisePage />} />
      <Route path="/settings" element={<SettingsPage />} />
      {/* MainLayout 只包含首页 + 统计 */}
      <Route path="/" element={hasProfile ? <MainLayout /> : <Navigate to="/welcome" replace />}>
        <Route index element={<BattlePage />} />
        <Route path="stats" element={<StatsPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
