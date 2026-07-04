import { motion } from 'framer-motion'
import { useNavigate } from 'react-router-dom'
import { Utensils, Dumbbell, Trophy, Swords } from 'lucide-react'

const features = [
  {
    icon: Utensils,
    title: '饮食记录 = 怪物回血',
    desc: '每吃一口，怪物就恢复生命值',
    color: 'from-red to-red-dark',
    iconColor: 'text-red',
  },
  {
    icon: Dumbbell,
    title: '锻炼 = 攻击怪物',
    desc: '运动消耗卡路里，对怪物造成伤害',
    color: 'from-blue to-purple',
    iconColor: 'text-blue',
  },
  {
    icon: Trophy,
    title: '击败怪物 = 获得奖励',
    desc: '打败脂肪怪，赢取金币和成就',
    color: 'from-gold to-orange',
    iconColor: 'text-gold',
  },
]

export default function WelcomePage() {
  const navigate = useNavigate()

  const handleStart = () => {
    navigate('/setup')
  }

  return (
    <div className="min-h-screen w-full flex flex-col items-center justify-center px-6 py-12 bg-gradient-to-b from-bg via-bg2 to-bg">
      <div className="w-full max-w-[480px] flex flex-col items-center">
        <motion.div
          className="text-8xl mb-6 animate-float"
          initial={{ opacity: 0, scale: 0.5 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ type: 'spring', stiffness: 100, damping: 12, delay: 0.1 }}
        >
          👊
        </motion.div>

        <motion.h1
          className="text-4xl font-black text-center mb-2 bg-gradient-to-r from-red via-orange to-gold bg-clip-text text-transparent"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ type: 'spring', stiffness: 100, damping: 12, delay: 0.2 }}
        >
          减肥大作战
        </motion.h1>

        <motion.p
          className="text-text2 text-center mb-10 text-lg"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ type: 'spring', stiffness: 100, damping: 12, delay: 0.3 }}
        >
          用游戏的方式打赢脂肪战争
        </motion.p>

        <motion.div
          className="w-full space-y-4 mb-10"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ type: 'spring', stiffness: 100, damping: 12, delay: 0.4 }}
        >
          {features.map((feature, index) => (
            <motion.div
              key={index}
              className="bg-card/60 backdrop-blur-sm border border-border rounded-2xl p-4 flex items-center gap-4 hover:border-border/80 transition-colors"
              whileHover={{ scale: 1.02, x: 5 }}
              transition={{ type: 'spring', stiffness: 400, damping: 20 }}
            >
              <div
                className={`w-12 h-12 rounded-xl bg-gradient-to-br ${feature.color} flex items-center justify-center flex-shrink-0 shadow-lg`}
              >
                <feature.icon className="w-6 h-6 text-white" />
              </div>
              <div className="flex-1">
                <h3 className="font-bold text-text text-base">{feature.title}</h3>
                <p className="text-text2 text-sm mt-0.5">{feature.desc}</p>
              </div>
            </motion.div>
          ))}
        </motion.div>

        <motion.button
          className="w-full py-4 px-8 bg-gradient-to-r from-red via-orange to-gold text-white font-bold text-lg rounded-2xl shadow-lg shadow-orange-500/30 hover:shadow-orange-500/50 transition-all duration-300 flex items-center justify-center gap-3"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ type: 'spring', stiffness: 100, damping: 12, delay: 0.5 }}
          whileHover={{ scale: 1.03 }}
          whileTap={{ scale: 0.97 }}
          onClick={handleStart}
        >
          <Swords className="w-5 h-5" />
          开始冒险
        </motion.button>

        <motion.p
          className="mt-6 text-text3 text-xs text-center"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ type: 'spring', stiffness: 100, damping: 12, delay: 0.6 }}
        >
          准备好迎接挑战了吗？
        </motion.p>
      </div>
    </div>
  )
}
