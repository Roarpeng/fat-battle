import { useMemo } from 'react'
import { motion } from 'framer-motion'
import {
  BarChart3,
  TrendingDown,
  Trophy,
  Sword,
  Flame,
  Coins,
  Target,
  Calendar,
  Award,
  Star,
  Zap,
  Shield,
} from 'lucide-react'
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from 'recharts'
import { useGameStore } from '../store/useGameStore'
import Card from '../components/Card'

export default function StatsPage() {
  const { user, monster, daily, coins, days, streak, weeklyData, exerciseRecords, dietRecords } =
    useGameStore()

  const weightProgress = useMemo(() => {
    const totalToLose = user.weight - user.targetWeight
    if (totalToLose <= 0) return 100
    const initialWeight = user.weight + (user.bmi > 25 ? 5 : 2)
    const lost = initialWeight - user.weight
    return Math.min(100, Math.max(0, Math.round((lost / (initialWeight - user.targetWeight)) * 100)))
  }, [user.weight, user.targetWeight, user.bmi])

  const monstersDefeated = monster.level - 1

  const totalCaloriesBurned = useMemo(() => {
    return exerciseRecords.reduce((sum, r) => sum + r.calories, 0)
  }, [exerciseRecords])

  const totalDamage = useMemo(() => {
    return daily.damage + (monstersDefeated * 100)
  }, [daily.damage, monstersDefeated])

  const weekData = useMemo(() => {
    const days = []
    const today = new Date()
    const dayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']

    for (let i = 6; i >= 0; i--) {
      const d = new Date(today)
      d.setDate(today.getDate() - i)
      const dateStr = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
      const dayOfWeek = d.getDay() === 0 ? 6 : d.getDay() - 1

      const weeklyDay = weeklyData?.days.find((wd) => wd.date === dateStr)

      days.push({
        date: dayLabels[dayOfWeek],
        intake: weeklyDay?.calories ?? (i === 0 ? daily.intake : Math.floor(Math.random() * 1500 + 1000)),
        burn: weeklyDay?.exercise ?? (i === 0 ? daily.exerciseBurn : Math.floor(Math.random() * 500 + 100)),
        damage: Math.floor(Math.random() * 200 + 50),
        weight: weeklyDay?.weight ?? user.weight - (6 - i) * 0.1,
        victory: Math.random() > 0.4,
      })
    }
    return days
  }, [weeklyData, daily.intake, daily.exerciseBurn, user.weight])

  const achievements = [
    { id: 1, name: '初次战斗', desc: '击败第一只怪物', icon: Sword, unlocked: monstersDefeated >= 1, color: 'text-gold' },
    { id: 2, name: '燃烧脂肪', desc: '累计消耗1000卡', icon: Flame, unlocked: totalCaloriesBurned >= 1000, color: 'text-orange' },
    { id: 3, name: '坚持一周', desc: '连续锻炼7天', icon: Calendar, unlocked: streak >= 7, color: 'text-green' },
    { id: 4, name: '怪物猎人', desc: '击败10只怪物', icon: Trophy, unlocked: monstersDefeated >= 10, color: 'text-purple' },
    { id: 5, name: '健身达人', desc: '累计消耗5000卡', icon: Zap, unlocked: totalCaloriesBurned >= 5000, color: 'text-blue' },
    { id: 6, name: '减肥战士', desc: '减重5公斤', icon: Shield, unlocked: false, color: 'text-red' },
  ]

  const stats = [
    { label: '击败怪物', value: monstersDefeated, icon: Trophy, color: 'text-gold', bg: 'from-gold/20 to-orange/20' },
    { label: '总伤害', value: totalDamage, icon: Sword, color: 'text-red', bg: 'from-red/20 to-pink/20' },
    { label: '总消耗', value: `${totalCaloriesBurned}`, unit: '卡', icon: Flame, color: 'text-orange', bg: 'from-orange/20 to-gold/20' },
    { label: '金币', value: coins, icon: Coins, color: 'text-gold', bg: 'from-gold/20 to-yellow/20' },
  ]

  return (
    <div className="min-h-full p-4 pb-6">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
      >
        <h1 className="text-2xl font-black mb-4 bg-gradient-to-r from-gold to-orange bg-clip-text text-transparent">
          战斗统计
        </h1>

        <Card className="mb-4 bg-gradient-to-br from-green/10 to-blue/10">
          <div className="flex items-center justify-between mb-3">
            <h2 className="font-bold text-lg flex items-center gap-2">
              <TrendingDown className="text-green" size={20} />
              减肥进度
            </h2>
            <span className="text-sm text-text2">第 {days} 天</span>
          </div>

          <div className="flex items-end justify-between mb-4">
            <div className="text-center">
              <div className="text-2xl font-black text-text">{user.weight}</div>
              <div className="text-xs text-text3">当前体重(kg)</div>
            </div>
            <div className="flex-1 mx-4 relative">
              <div className="h-2 bg-bg2 rounded-full overflow-hidden">
                <motion.div
                  initial={{ width: 0 }}
                  animate={{ width: `${weightProgress}%` }}
                  transition={{ duration: 1, delay: 0.3 }}
                  className="h-full bg-gradient-to-r from-green to-blue rounded-full"
                />
              </div>
              <div className="absolute top-0 left-0 w-full h-full flex items-center justify-center">
                <span className="text-xs font-bold text-text2 bg-bg px-2 py-0.5 rounded-full">
                  {weightProgress}%
                </span>
              </div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-black text-green">{user.targetWeight}</div>
              <div className="text-xs text-text3">目标体重(kg)</div>
            </div>
          </div>

          <div className="grid grid-cols-3 gap-2">
            <div className="bg-bg2/60 rounded-xl p-2 text-center">
              <div className="text-lg font-bold text-text">{user.bmi}</div>
              <div className="text-[10px] text-text3">当前BMI</div>
            </div>
            <div className="bg-bg2/60 rounded-xl p-2 text-center">
              <div className="text-lg font-bold text-green">
                {(user.targetWeight / ((user.height / 100) ** 2)).toFixed(1)}
              </div>
              <div className="text-[10px] text-text3">目标BMI</div>
            </div>
            <div className="bg-bg2/60 rounded-xl p-2 text-center">
              <div className="text-lg font-bold text-orange">
                {(user.weight - user.targetWeight).toFixed(1)}
              </div>
              <div className="text-[10px] text-text3">还需减(kg)</div>
            </div>
          </div>
        </Card>

        <div className="grid grid-cols-2 gap-3 mb-4">
          {stats.map((stat, index) => (
            <motion.div
              key={stat.label}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.1 }}
            >
              <Card hoverable className={`bg-gradient-to-br ${stat.bg} h-full`}>
                <div className="flex items-center gap-3">
                  <div className={`${stat.color}`}>
                    <stat.icon size={24} />
                  </div>
                  <div>
                    <div className="text-xl font-black text-text">
                      {stat.value}
                      {stat.unit && <span className="text-sm font-normal ml-0.5">{stat.unit}</span>}
                    </div>
                    <div className="text-xs text-text3">{stat.label}</div>
                  </div>
                </div>
              </Card>
            </motion.div>
          ))}
        </div>

        <Card className="mb-4">
          <h2 className="font-bold text-lg mb-3 flex items-center gap-2">
            <Target className="text-purple" size={20} />
            体重趋势
          </h2>
          <div className="h-48">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={weekData}>
                <defs>
                  <linearGradient id="weightGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#667eea" stopOpacity={0.3} />
                    <stop offset="100%" stopColor="#667eea" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#2a3a5a" vertical={false} />
                <XAxis dataKey="date" tick={{ fill: '#6b7280', fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill: '#6b7280', fontSize: 11 }} axisLine={false} tickLine={false} domain={['dataMin - 1', 'dataMax + 1']} />
                <Tooltip
                  contentStyle={{
                    backgroundColor: '#1e2a4a',
                    border: '1px solid #2a3a5a',
                    borderRadius: '12px',
                    fontSize: '12px',
                  }}
                  labelStyle={{ color: '#e0e0e0', marginBottom: '4px' }}
                />
                <Line
                  type="monotone"
                  dataKey="weight"
                  stroke="#667eea"
                  strokeWidth={2.5}
                  dot={{ fill: '#667eea', strokeWidth: 2, r: 4 }}
                  activeDot={{ r: 6, fill: '#667eea' }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </Card>

        <Card className="mb-4">
          <h2 className="font-bold text-lg mb-3 flex items-center gap-2">
            <BarChart3 className="text-blue" size={20} />
            本周摄入 vs 消耗
          </h2>
          <div className="h-48">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={weekData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2a3a5a" vertical={false} />
                <XAxis dataKey="date" tick={{ fill: '#6b7280', fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill: '#6b7280', fontSize: 11 }} axisLine={false} tickLine={false} />
                <Tooltip
                  contentStyle={{
                    backgroundColor: '#1e2a4a',
                    border: '1px solid #2a3a5a',
                    borderRadius: '12px',
                    fontSize: '12px',
                  }}
                  labelStyle={{ color: '#e0e0e0', marginBottom: '4px' }}
                />
                <Legend wrapperStyle={{ fontSize: '11px', paddingTop: '10px' }} />
                <Bar dataKey="intake" name="摄入" fill="#ff6b6b" radius={[4, 4, 0, 0]} />
                <Bar dataKey="burn" name="消耗" fill="#2ecc71" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Card>

        <Card className="mb-4">
          <h2 className="font-bold text-lg mb-3 flex items-center gap-2">
            <Calendar className="text-gold" size={20} />
            本周概览
          </h2>
          <div className="space-y-2">
            {weekData.map((day, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, x: -10 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: index * 0.08 }}
                className="flex items-center gap-3 p-2.5 bg-bg2 rounded-xl"
              >
                <div className="w-10 text-center">
                  <div className="text-sm font-bold text-text">{day.date}</div>
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 text-xs">
                    <span className="text-red">⬆ {day.intake}</span>
                    <span className="text-green">⬇ {day.burn}</span>
                    <span className="text-purple">⚔ {day.damage}</span>
                  </div>
                </div>
                <div className={`w-7 h-7 rounded-full flex items-center justify-center text-sm ${
                  day.victory ? 'bg-green/20 text-green' : 'bg-red/20 text-red'
                }`}>
                  {day.victory ? '✓' : '✗'}
                </div>
              </motion.div>
            ))}
          </div>
        </Card>

        <Card>
          <h2 className="font-bold text-lg mb-3 flex items-center gap-2">
            <Award className="text-gold" size={20} />
            成就展示
          </h2>
          <div className="grid grid-cols-3 gap-2">
            {achievements.map((achievement, index) => (
              <motion.div
                key={achievement.id}
                initial={{ opacity: 0, scale: 0.8 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: index * 0.1 }}
                className={`p-3 rounded-xl text-center ${
                  achievement.unlocked
                    ? 'bg-gradient-to-br from-gold/10 to-orange/10 border border-gold/30'
                    : 'bg-bg2 border border-border opacity-50'
                }`}
              >
                <div className={`mx-auto w-10 h-10 rounded-full flex items-center justify-center mb-1.5 ${
                  achievement.unlocked ? 'bg-gold/20' : 'bg-bg3'
                }`}>
                  <achievement.icon
                    size={20}
                    className={achievement.unlocked ? achievement.color : 'text-text3'}
                  />
                </div>
                <div className="text-xs font-bold text-text truncate">{achievement.name}</div>
                <div className="text-[10px] text-text3 mt-0.5 leading-tight">{achievement.desc}</div>
              </motion.div>
            ))}
          </div>
        </Card>
      </motion.div>
    </div>
  )
}
