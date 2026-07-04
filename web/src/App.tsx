import { Routes, Route, Navigate } from 'react-router-dom'
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
import MainLayout from './components/MainLayout'

export default function App() {
  const { user } = useGameStore()

  const hasProfile = user.height > 0 && user.weight > 0

  return (
    <Routes>
      <Route path="/welcome" element={<WelcomePage />} />
      <Route path="/setup" element={hasProfile ? <SetupPage /> : <Navigate to="/welcome" replace />} />
      <Route path="/pose" element={<PoseDetectionPage />} />
      <Route path="/bluetooth" element={<BluetoothPage />} />
      <Route path="/achievements" element={<AchievementsPage />} />
      <Route path="/quests" element={<DailyQuestsPage />} />
      <Route path="/skills" element={<SkillsPage />} />
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
