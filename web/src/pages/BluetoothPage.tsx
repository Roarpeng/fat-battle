import { useState, useRef, useEffect, useCallback } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import {
  Bluetooth,
  Search,
  X,
  Activity,
  Zap,
  AlertTriangle,
  CheckCircle2,
  Wifi,
  WifiOff,
  RefreshCw,
  Flame,
  Swords,
  Target,
  Gauge,
  RotateCcw,
  Settings,
  Info,
  Signal,
} from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import Card from '../components/Card'
import Button from '../components/Button'
import DamageNumber from '../components/DamageNumber'
import MobileHeader from '../components/MobileHeader'
import { useGameStore } from '../store/useGameStore'
import { getExerciseById } from '../data/exercises'
import { BluetoothService, createBluetoothService, type ConnectionStatus, type ImuData } from '../services/bluetoothService'

interface DeviceInfo {
  id: string
  name: string
  rssi?: number
}

const TARGET_REPS = 15

export default function BluetoothPage() {
  const navigate = useNavigate()
  const bluetoothServiceRef = useRef<BluetoothService | null>(null)
  const mockIntervalRef = useRef<number>(0)
  const mockSquatIntervalRef = useRef<number>(0)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const animationRef = useRef<number>(0)
  const dataHistoryRef = useRef<number[]>(Array(100).fill(0))

  const [status, setStatus] = useState<ConnectionStatus>('disconnected')
  const [devices, setDevices] = useState<DeviceInfo[]>([])
  const [isScanning, setIsScanning] = useState(false)
  const [connectedDevice, setConnectedDevice] = useState<DeviceInfo | null>(null)
  const [errorMsg, setErrorMsg] = useState('')
  const [useMock, setUseMock] = useState(false)
  const [imuData, setImuData] = useState<ImuData>({
    ax: 0, ay: 0, az: 0, gx: 0, gy: 0, gz: 0, timestamp: 0
  })
  const [squatCount, setSquatCount] = useState(0)
  const [isSquatting, setIsSquatting] = useState(false)
  const [showDamage, setShowDamage] = useState(false)
  const [damageValue, setDamageValue] = useState(0)
  const [isCompleted, setIsCompleted] = useState(false)
  const [bluetoothSupported, setBluetoothSupported] = useState(true)
  const [dataRate, setDataRate] = useState(0)
  const [elapsedTime, setElapsedTime] = useState(0)
  const timerRef = useRef<number>(0)

  const { attackMonster, addExerciseRecord, user } = useGameStore()

  const exerciseInfo = getExerciseById('squat')

  useEffect(() => {
    const supported = typeof navigator !== 'undefined' && 'bluetooth' in navigator
    setBluetoothSupported(supported)
    if (!supported) {
      setErrorMsg('当前浏览器不支持 Web Bluetooth API，请使用 Chrome 或 Edge 浏览器')
    }
    return () => {
      cleanup()
    }
  }, [])

  useEffect(() => {
    if (status === 'connected' && !timerRef.current) {
      timerRef.current = window.setInterval(() => {
        setElapsedTime((prev) => prev + 1)
      }, 1000)
    } else if (status !== 'connected' && timerRef.current) {
      clearInterval(timerRef.current)
      timerRef.current = 0
    }
    return () => {
      if (timerRef.current) {
        clearInterval(timerRef.current)
        timerRef.current = 0
      }
    }
  }, [status])

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }

  const cleanup = useCallback(() => {
    if (animationRef.current) {
      cancelAnimationFrame(animationRef.current)
    }
    if (mockIntervalRef.current) {
      clearInterval(mockIntervalRef.current)
      mockIntervalRef.current = 0
    }
    if (mockSquatIntervalRef.current) {
      clearInterval(mockSquatIntervalRef.current)
      mockSquatIntervalRef.current = 0
    }
    if (bluetoothServiceRef.current) {
      bluetoothServiceRef.current.destroy()
      bluetoothServiceRef.current = null
    }
    setStatus('disconnected')
    setConnectedDevice(null)
    setUseMock(false)
    setElapsedTime(0)
    dataHistoryRef.current = Array(100).fill(0)
  }, [])

  const startMockMode = useCallback(() => {
    setUseMock(true)
    setIsScanning(true)
    setErrorMsg('')

    setTimeout(() => {
      const mockDevices: DeviceInfo[] = [
        { id: 'mock-1', name: 'FatBattle-Hub-001', rssi: -45 },
        { id: 'mock-2', name: 'ESP32-IMU-002', rssi: -62 },
        { id: 'mock-3', name: 'Unknown Device', rssi: -78 },
      ]
      setDevices(mockDevices)
      setIsScanning(false)
    }, 2000)
  }, [])

  const drawWaveform = useCallback(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const width = canvas.width
    const height = canvas.height
    const data = dataHistoryRef.current

    ctx.clearRect(0, 0, width, height)

    ctx.strokeStyle = 'rgba(102, 126, 234, 0.3)'
    ctx.lineWidth = 1
    for (let i = 0; i <= 4; i++) {
      const y = (height / 4) * i
      ctx.beginPath()
      ctx.moveTo(0, y)
      ctx.lineTo(width, y)
      ctx.stroke()
    }

    const maxVal = 2000
    const minVal = -2000
    const range = maxVal - minVal

    ctx.strokeStyle = '#667eea'
    ctx.lineWidth = 2
    ctx.beginPath()

    for (let i = 0; i < data.length; i++) {
      const x = (i / (data.length - 1)) * width
      const normalizedVal = (data[i] - minVal) / range
      const y = height - normalizedVal * height

      if (i === 0) {
        ctx.moveTo(x, y)
      } else {
        ctx.lineTo(x, y)
      }
    }
    ctx.stroke()

    const gradient = ctx.createLinearGradient(0, 0, 0, height)
    gradient.addColorStop(0, 'rgba(102, 126, 234, 0.3)')
    gradient.addColorStop(1, 'rgba(102, 126, 234, 0)')
    ctx.lineTo(width, height)
    ctx.lineTo(0, height)
    ctx.closePath()
    ctx.fillStyle = gradient
    ctx.fill()
  }, [])

  const updateWaveform = useCallback((value: number) => {
    dataHistoryRef.current.push(value)
    dataHistoryRef.current.shift()
    requestAnimationFrame(drawWaveform)
  }, [drawWaveform])

  const connectMockDevice = useCallback((device: DeviceInfo) => {
    setStatus('connecting')
    setErrorMsg('')

    setTimeout(() => {
      setConnectedDevice(device)
      setStatus('connected')
      setSquatCount(0)
      setIsCompleted(false)
      setIsSquatting(false)
      setElapsedTime(0)

      let baseAx = 0
      let baseAy = -1000
      let baseAz = 0
      let squatting = false
      let count = 0
      let phase = 0

      mockIntervalRef.current = window.setInterval(() => {
        const noise = () => (Math.random() - 0.5) * 80
        const newData: ImuData = {
          ax: Math.round(baseAx + noise()),
          ay: Math.round(baseAy + noise()),
          az: Math.round(baseAz + noise()),
          gx: Math.round(noise() * 2),
          gy: Math.round(noise() * 2),
          gz: Math.round(noise() * 2),
          timestamp: Date.now(),
        }
        setImuData(newData)
        updateWaveform(newData.ay)
        setDataRate(20)
      }, 50)

      mockSquatIntervalRef.current = window.setInterval(() => {
        phase++
        if (phase <= 12) {
          baseAy = -1000 + phase * 120
          baseAz = phase * 40
          if (phase === 12 && !squatting) {
            squatting = true
            setIsSquatting(true)
          }
        } else if (phase <= 24) {
          baseAy = 440 - (phase - 12) * 120
          baseAz = 480 - (phase - 12) * 40
          if (phase === 24 && squatting) {
            squatting = false
            setIsSquatting(false)
            count++
            setSquatCount(count)
            if (count >= TARGET_REPS) {
              handleComplete(count)
            }
          }
        } else {
          phase = 0
          baseAy = -1000
          baseAz = 0
        }
      }, 180)
    }, 1500)
  }, [updateWaveform])

  const handleComplete = useCallback((finalCount: number) => {
    const exercise = getExerciseById('squat')
    const duration = Math.max(1, Math.round(finalCount / 10))
    const calories = exercise
      ? Math.round(((exercise.caloriesPerMinute / 3.5) * 3.5 * user.weight * duration) / 200)
      : 0
    const damage = exercise
      ? Math.round(exercise.damagePerMinute * duration * (1 + (user.difficulty === 'easy' ? 0.8 : user.difficulty === 'hard' ? 1.2 : 1)))
      : 0

    addExerciseRecord({
      name: exercise?.name || '深蹲',
      calories,
      time: Date.now(),
      reps: finalCount,
    })

    attackMonster(damage)

    setDamageValue(damage)
    setShowDamage(true)
    setIsCompleted(true)
    setTimeout(() => setShowDamage(false), 1000)
  }, [user, addExerciseRecord, attackMonster])

  const scanDevices = useCallback(async () => {
    setErrorMsg('')
    setIsScanning(true)
    setDevices([])

    if (!bluetoothSupported) {
      setTimeout(() => {
        startMockMode()
      }, 500)
      return
    }

    try {
      const service = createBluetoothService({
        autoReconnect: true,
        maxReconnectAttempts: 3,
        onData: (data: ImuData) => {
          setImuData(data)
          updateWaveform(data.ay)
        },
        onStatusChange: (newStatus: ConnectionStatus) => {
          setStatus(newStatus)
          if (newStatus === 'connected') {
            setIsScanning(false)
          }
        },
        onError: (err: Error) => {
          console.error('Bluetooth error:', err)
          setErrorMsg(err.message)
        },
        onDisconnect: () => {
          setDataRate(0)
        },
      })

      bluetoothServiceRef.current = service

      const connected = await service.connect()
      if (connected) {
        const deviceName = service.getDeviceName() || 'Unknown Device'
        setConnectedDevice({ id: service.getDeviceId() || 'connected', name: deviceName })
        setStatus('connected')
        setSquatCount(0)
        setIsCompleted(false)
        setElapsedTime(0)

        const checkRate = setInterval(() => {
          if (bluetoothServiceRef.current) {
            setDataRate(bluetoothServiceRef.current.getDataRate())
          } else {
            clearInterval(checkRate)
          }
        }, 1000)
      }
      setIsScanning(false)
    } catch (err: any) {
      console.error('Scan error:', err)
      const msg = err?.message || '蓝牙连接失败'

      if (msg.includes('User cancelled') || msg.includes('取消')) {
        setErrorMsg('用户取消了蓝牙连接')
      } else if (msg.includes('not supported') || msg.includes('不支持')) {
        setErrorMsg('当前浏览器不支持 Web Bluetooth，将使用模拟模式')
        startMockMode()
      } else {
        setErrorMsg(`${msg}，将使用模拟模式`)
        startMockMode()
      }
      setIsScanning(false)
    }
  }, [bluetoothSupported, startMockMode, updateWaveform])

  const connectDevice = useCallback(async (device: DeviceInfo) => {
    if (useMock) {
      connectMockDevice(device)
      return
    }
  }, [useMock, connectMockDevice])

  const disconnect = useCallback(async () => {
    if (useMock) {
      if (mockIntervalRef.current) clearInterval(mockIntervalRef.current)
      if (mockSquatIntervalRef.current) clearInterval(mockSquatIntervalRef.current)
      setStatus('disconnected')
      setConnectedDevice(null)
      setIsSquatting(false)
      setUseMock(false)
      return
    }

    try {
      await bluetoothServiceRef.current?.disconnect()
    } catch (_) {
    }
    setStatus('disconnected')
    setConnectedDevice(null)
    setIsSquatting(false)
  }, [useMock])

  const resetCount = useCallback(() => {
    setSquatCount(0)
    setIsCompleted(false)
    setIsSquatting(false)
  }, [])

  const statusConfig = {
    disconnected: { label: '未连接', color: 'text-text3', bg: 'bg-text3/20', icon: WifiOff },
    connecting: { label: '连接中...', color: 'text-blue', bg: 'bg-blue/20', icon: RefreshCw },
    reconnecting: { label: '重连中...', color: 'text-orange', bg: 'bg-orange/20', icon: RotateCcw },
    connected: { label: '已连接', color: 'text-green', bg: 'bg-green/20', icon: Wifi },
    error: { label: '连接错误', color: 'text-red', bg: 'bg-red/20', icon: AlertTriangle },
  }

  const currentStatus = statusConfig[status]
  const StatusIcon = currentStatus.icon
  const progress = (squatCount / TARGET_REPS) * 100

  const getRssiLevel = (rssi?: number) => {
    if (!rssi) return 0
    if (rssi > -50) return 4
    if (rssi > -60) return 3
    if (rssi > -70) return 2
    return 1
  }

  const getRssiLabel = (rssi?: number) => {
    if (!rssi) return ''
    if (rssi > -50) return '极佳'
    if (rssi > -60) return '良好'
    if (rssi > -70) return '一般'
    return '较弱'
  }

  return (
    <div className="min-h-full flex flex-col px-4 py-4 gap-4">
      <AnimatePresence>
        {showDamage && (
          <DamageNumber value={damageValue} type="damage" />
        )}
      </AnimatePresence>

      <MobileHeader
        title="蓝牙设备"
        gradient="from-blue to-cyan"
        useHistoryBack
        rightAction={
          <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full ${currentStatus.bg}`}>
            <StatusIcon size={14} className={currentStatus.color} />
          </div>
        }
      />
      <Card>
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
              <Bluetooth className="text-blue" size={18} />
              <h2 className="font-bold">设备状态</h2>
            </div>
            {status === 'connected' && (
              <span className="text-xs text-text3">
                {formatTime(elapsedTime)}
              </span>
            )}
          </div>

          <div className={`${currentStatus.bg} rounded-xl p-4 flex items-center gap-3`}>
            <div className={`w-12 h-12 rounded-full ${currentStatus.bg} flex items-center justify-center ring-2 ${currentStatus.color.replace('text-', 'ring-')}/30`}>
              <StatusIcon size={24} className={currentStatus.color} />
            </div>
            <div className="flex-1">
              <div className={`font-bold ${currentStatus.color}`}>
                {currentStatus.label}
              </div>
              <div className="text-xs text-text3 mt-0.5">
                {connectedDevice ? connectedDevice.name : '请连接蓝牙设备'}
              </div>
            </div>
            {status === 'connected' && (
              <div className="text-right">
                <div className="w-3 h-3 bg-green rounded-full animate-pulse mx-auto mb-1" />
                <span className="text-xs text-text3">{dataRate} Hz</span>
              </div>
            )}
            {(status === 'connecting' || status === 'reconnecting') && (
              <RefreshCw size={18} className={`${currentStatus.color} animate-spin`} />
            )}
          </div>

          {errorMsg && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              className="mt-3 bg-orange/20 border border-orange/30 rounded-xl p-3 flex items-start gap-2"
            >
              <AlertTriangle size={16} className="text-orange shrink-0 mt-0.5" />
              <p className="text-orange text-xs">{errorMsg}</p>
            </motion.div>
          )}
        </Card>

        {status !== 'connected' && (
        <Card>
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <Search className="text-purple" size={18} />
                <h2 className="font-bold">扫描设备</h2>
              </div>
              {useMock && (
                <span className="text-xs text-blue bg-blue/20 px-2 py-0.5 rounded-full">
                  模拟模式
                </span>
              )}
            </div>

            <Button
              variant="green"
              fullWidth
              icon={isScanning ? undefined : <Bluetooth size={18} />}
              loading={isScanning}
              onClick={scanDevices}
              disabled={isScanning}
            >
              {isScanning ? '扫描中...' : '搜索蓝牙设备'}
            </Button>

            <div className="mt-2 flex items-center gap-1.5 text-xs text-text3">
              <Info size={12} />
              <span>支持 ESP32、FatBattle Hub 等 BLE 设备</span>
            </div>

            {devices.length > 0 && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                className="mt-4 space-y-2"
              >
                <p className="text-xs text-text3 font-medium flex items-center gap-1.5">
                  <Signal size={12} />
                  发现 {devices.length} 个设备
                </p>
                {devices.map((device, index) => {
                  const rssiLevel = getRssiLevel(device.rssi)
                  return (
                    <motion.div
                      key={device.id}
                      initial={{ opacity: 0, x: -10 }}
                      animate={{ opacity: 1, x: 0 }}
                      transition={{ delay: index * 0.1 }}
                      className="bg-bg2 rounded-xl p-3 flex items-center gap-3 hover:bg-bg2/80 transition-colors"
                    >
                      <div className="w-10 h-10 rounded-full bg-blue/20 flex items-center justify-center">
                        <Bluetooth size={20} className="text-blue" />
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="font-bold text-sm text-text truncate">
                          {device.name}
                        </div>
                        <div className="flex items-center gap-2 mt-0.5">
                          <div className="flex items-end gap-0.5 h-3">
                            {[1, 2, 3, 4].map((level) => (
                              <div
                                key={level}
                                className={`w-1 rounded-full transition-all ${
                                  level <= rssiLevel
                                    ? 'bg-green'
                                    : 'bg-text3/30'
                                }`}
                                style={{ height: `${level * 2 + 4}px` }}
                              />
                            ))}
                          </div>
                          <span className="text-xs text-text3">
                            {device.rssi ? `${getRssiLabel(device.rssi)} · ${device.rssi} dBm` : '信号未知'}
                          </span>
                        </div>
                      </div>
                      <Button
                        variant="secondary"
                        size="sm"
                        onClick={() => connectDevice(device)}
                      >
                        连接
                      </Button>
                    </motion.div>
                  )
                })}
              </motion.div>
            )}
          </Card>
        )}

        <AnimatePresence mode="wait">
          {status === 'connected' && (
            <motion.div
              key="connected"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -20 }}
              transition={{ duration: 0.3 }}
            >
              <Card className="mb-4 p-0 overflow-hidden">
                <div className="flex items-center justify-between px-4 py-3 border-b border-border">
                  <h2 className="font-bold flex items-center gap-2">
                    <Activity className="text-purple" size={18} />
                    实时波形
                  </h2>
                  <span className="text-xs text-text3">AY 加速度</span>
                </div>
                <div className="bg-bg2 p-2">
                  <canvas
                    ref={canvasRef}
                    width={400}
                    height={120}
                    className="w-full h-[120px]"
                  />
                </div>
              </Card>

            <Card>
                <div className="flex items-center justify-between mb-3">
                  <h2 className="font-bold flex items-center gap-2">
                    <Gauge className="text-blue" size={18} />
                    IMU 六轴数据
                  </h2>
                  <span className="text-xs text-text3">
                    {dataRate} Hz
                  </span>
                </div>

                <div className="mb-2">
                  <div className="text-xs text-text3 mb-1.5 flex items-center gap-1">
                    <Zap size={12} className="text-red" />
                    加速度 (mg)
                  </div>
                  <div className="grid grid-cols-3 gap-2">
                    <div className="bg-bg2 rounded-xl p-3 text-center">
                      <div className="text-xs text-text3 mb-1">AX</div>
                      <div className="text-lg font-black text-red tabular-nums">{imuData.ax}</div>
                    </div>
                    <div className="bg-bg2 rounded-xl p-3 text-center">
                      <div className="text-xs text-text3 mb-1">AY</div>
                      <div className="text-lg font-black text-green tabular-nums">{imuData.ay}</div>
                    </div>
                    <div className="bg-bg2 rounded-xl p-3 text-center">
                      <div className="text-xs text-text3 mb-1">AZ</div>
                      <div className="text-lg font-black text-blue tabular-nums">{imuData.az}</div>
                    </div>
                  </div>
                </div>

                <div>
                  <div className="text-xs text-text3 mb-1.5 flex items-center gap-1">
                    <RotateCcw size={12} className="text-purple" />
                    陀螺仪 (°/s)
                  </div>
                  <div className="grid grid-cols-3 gap-2">
                    <div className="bg-bg2 rounded-xl p-3 text-center">
                      <div className="text-xs text-text3 mb-1">GX</div>
                      <div className="text-sm font-bold text-purple tabular-nums">{imuData.gx}</div>
                    </div>
                    <div className="bg-bg2 rounded-xl p-3 text-center">
                      <div className="text-xs text-text3 mb-1">GY</div>
                      <div className="text-sm font-bold text-gold tabular-nums">{imuData.gy}</div>
                    </div>
                    <div className="bg-bg2 rounded-xl p-3 text-center">
                      <div className="text-xs text-text3 mb-1">GZ</div>
                      <div className="text-sm font-bold text-orange tabular-nums">{imuData.gz}</div>
                    </div>
                  </div>
                </div>
              </Card>

            <Card>
                <div className="flex items-center justify-between mb-3">
                  <h2 className="font-bold flex items-center gap-2">
                    <Zap className="text-gold" size={18} />
                    深蹲检测
                  </h2>
                  <div className="flex items-center gap-2">
                    <span className="text-xs text-text3">目标: {TARGET_REPS}次</span>
                    <span className="text-xs text-purple bg-purple/20 px-2 py-0.5 rounded-full">
                      {formatTime(elapsedTime)}
                    </span>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3 mb-3">
                  <div className="bg-bg2 rounded-xl p-4 text-center">
                    <div className="text-4xl font-black text-purple tabular-nums">{squatCount}</div>
                    <div className="text-xs text-text3 mt-1">已完成</div>
                  </div>
                  <div className="bg-bg2 rounded-xl p-4 flex flex-col items-center justify-center">
                    <div className={`text-xl font-bold px-4 py-1.5 rounded-full ${isSquatting ? 'bg-orange/20 text-orange' : 'bg-green/20 text-green'}`}>
                      {isSquatting ? '下蹲中' : '站立'}
                    </div>
                    <div className="text-xs text-text3 mt-2">当前状态</div>
                  </div>
                </div>

                <div className="mb-1">
                  <div className="flex justify-between text-xs text-text3 mb-1.5">
                    <span>进度</span>
                    <span>{squatCount} / {TARGET_REPS}</span>
                  </div>
                  <div className="h-3 bg-bg2 rounded-full overflow-hidden">
                    <motion.div
                      className="h-full bg-gradient-to-r from-blue to-green rounded-full"
                      initial={{ width: 0 }}
                      animate={{ width: `${Math.min(100, progress)}%` }}
                      transition={{ duration: 0.3 }}
                    />
                  </div>
                </div>
              </Card>

              {exerciseInfo && (
                <Card className="mb-4 bg-gradient-to-br from-blue/10 to-green/10">
                  <div className="flex items-center gap-3">
                    <div className="text-3xl">{exerciseInfo.emoji}</div>
                    <div className="flex-1 min-w-0">
                      <div className="font-bold text-text">{exerciseInfo.name}</div>
                      <div className="text-xs text-text3 mt-0.5 flex items-center gap-2">
                        <span className="flex items-center gap-1">
                          <Flame size={10} className="text-orange" />
                          {exerciseInfo.caloriesPerMinute}卡/分钟
                        </span>
                        <span className="flex items-center gap-1">
                          <Swords size={10} className="text-red" />
                          {exerciseInfo.damagePerMinute}伤害/分钟
                        </span>
                      </div>
                    </div>
                  </div>
                </Card>
              )}

              {isCompleted && (
                <motion.div
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  className="mb-4"
                >
                  <Card className="bg-gradient-to-br from-green/20 to-blue/20 border-green/30">
                    <div className="flex items-center gap-3">
                      <div className="w-12 h-12 rounded-full bg-gradient-to-br from-green to-green-dark flex items-center justify-center">
                        <CheckCircle2 size={28} className="text-white" />
                      </div>
                      <div className="flex-1">
                        <div className="font-bold text-text">完成目标！</div>
                        <div className="text-xs text-text3 mt-0.5">
                          你完成了 {TARGET_REPS} 次深蹲，用时 {formatTime(elapsedTime)}
                        </div>
                      </div>
                      <div className="text-right">
                        <div className="text-lg font-black text-orange">-{damageValue}</div>
                        <div className="text-xs text-text3">伤害</div>
                      </div>
                    </div>
                  </Card>
                </motion.div>
              )}

            <Card>
                <div className="flex items-center gap-2 mb-3">
                  <Settings className="text-gold" size={18} />
                  <h2 className="font-bold">设备信息</h2>
                </div>
                <div className="bg-bg2 rounded-xl p-3 flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-green/20 flex items-center justify-center">
                    <Bluetooth size={20} className="text-green" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="font-bold text-sm text-text truncate">
                      {connectedDevice?.name || '未知设备'}
                    </div>
                    <div className="text-xs text-text3">
                      IMU 数据正常传输 · {dataRate} Hz
                    </div>
                  </div>
                  <div className="w-2.5 h-2.5 bg-green rounded-full animate-pulse" />
                </div>
              </Card>

              <div className="space-y-2">
                <Button
                  variant="primary"
                  fullWidth
                  icon={<X size={18} />}
                  onClick={disconnect}
                >
                  断开连接
                </Button>
                <div className="grid grid-cols-2 gap-2">
                  <Button
                    variant="secondary"
                    icon={<RefreshCw size={18} />}
                    onClick={resetCount}
                  >
                    重置计数
                  </Button>
                  <Button
                    variant="secondary"
                    icon={<Target size={18} />}
                    onClick={() => navigate('/exercise')}
                  >
                    更多运动
                  </Button>
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
    </div>
  )
}
