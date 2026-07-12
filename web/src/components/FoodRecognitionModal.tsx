import { useState, useRef, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Camera, ScanLine, Search, X, Plus, Minus, Check, Loader2 } from 'lucide-react'
import { FoodRecognitionService, FoodRecognitionItem } from '../services/foodRecognitionService'
import { BarcodeScannerService } from '../services/barcodeService'
import Button from './Button'
import Card from './Card'

interface FoodRecognitionModalProps {
  open: boolean
  onClose: () => void
  onConfirm: (items: FoodRecognitionItem[]) => void
  mealType: string
}

type TabType = 'photo' | 'barcode' | 'search'

export default function FoodRecognitionModal({ open, onClose, onConfirm, mealType }: FoodRecognitionModalProps) {
  const [activeTab, setActiveTab] = useState<TabType>('photo')
  const [recognizedItems, setRecognizedItems] = useState<FoodRecognitionItem[]>([])
  const [status, setStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle')
  const [errorMsg, setErrorMsg] = useState('')
  const [searchQuery, setSearchQuery] = useState('')
  const [searchResults, setSearchResults] = useState<FoodRecognitionItem[]>([])
  const [cameraActive, setCameraActive] = useState(false)

  const videoRef = useRef<HTMLVideoElement>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)    // 相册选择
  const cameraInputRef = useRef<HTMLInputElement>(null)   // 拍照
  const barcodeFileRef = useRef<HTMLInputElement>(null)
  const scannerRef = useRef<BarcodeScannerService | null>(null)
  const recognitionRef = useRef<FoodRecognitionService | null>(null)

  useEffect(() => {
    if (!recognitionRef.current) {
      recognitionRef.current = new FoodRecognitionService()
    }
    return () => {
      stopCamera()
    }
  }, [])

  useEffect(() => {
    if (!open) {
      setRecognizedItems([])
      setStatus('idle')
      setErrorMsg('')
      setSearchQuery('')
      setSearchResults([])
      setActiveTab('photo')
    }
  }, [open])

  const stopCamera = () => {
    if (scannerRef.current) {
      scannerRef.current.stop()
      scannerRef.current = null
    }
    setCameraActive(false)
  }

  const handlePhotoUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    setStatus('loading')
    setErrorMsg('')

    try {
      const service = recognitionRef.current!
      const result = await service.recognizeFromImage(file)
      setRecognizedItems(result.items)
      setStatus('success')
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : '识别失败')
      setStatus('error')
    }
  }

  const startBarcodeScanner = async () => {
    if (!videoRef.current || !canvasRef.current) return

    setStatus('loading')
    setErrorMsg('')

    try {
      scannerRef.current = new BarcodeScannerService({
        videoElement: videoRef.current,
        canvasElement: canvasRef.current,
        onResult: async (result) => {
          stopCamera()
          setStatus('loading')
          try {
            const service = recognitionRef.current!
            const item = await service.recognizeFromBarcode(result.rawValue)
            if (item) {
              setRecognizedItems([item])
              setStatus('success')
            } else {
              setErrorMsg('未找到该条码对应的食物')
              setStatus('error')
            }
          } catch (err) {
            setErrorMsg(err instanceof Error ? err.message : '识别失败')
            setStatus('error')
          }
        },
        onStatusChange: (s) => {
          if (s === 'scanning') {
            setCameraActive(true)
            setStatus('idle')
          }
        },
        onError: (err) => {
          setErrorMsg(err.message)
          setStatus('error')
          stopCamera()
        },
      })

      await scannerRef.current.start()
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : '无法启动摄像头')
      setStatus('error')
    }
  }

  const handleBarcodeFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    setStatus('loading')
    setErrorMsg('')

    try {
      const scanner = new BarcodeScannerService()
      const results = await scanner.scanFromImage(file)
      if (results.length > 0) {
        const service = recognitionRef.current!
        const item = await service.recognizeFromBarcode(results[0].rawValue)
        if (item) {
          setRecognizedItems([item])
          setStatus('success')
        } else {
          setErrorMsg('未找到该条码对应的食物')
          setStatus('error')
        }
      } else {
        setErrorMsg('未识别到条码')
        setStatus('error')
      }
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : '识别失败')
      setStatus('error')
    }
  }

  const handleSearch = (query: string) => {
    setSearchQuery(query)
    if (!query.trim()) {
      setSearchResults([])
      return
    }
    const service = recognitionRef.current!
    setSearchResults(service.searchFoods(query))
  }

  const addItemToResults = (item: FoodRecognitionItem) => {
    setRecognizedItems(prev => {
      const exists = prev.find(i => i.name === item.name)
      if (exists) return prev
      return [...prev, item]
    })
    if (recognizedItems.length === 0) {
      setStatus('success')
    }
  }

  const adjustPortion = (index: number, portion: 'small' | 'medium' | 'large') => {
    const service = recognitionRef.current!
    setRecognizedItems(prev => prev.map((item, i) =>
      i === index ? service.updatePortion(item, portion) : item
    ))
  }

  const removeItem = (index: number) => {
    setRecognizedItems(prev => prev.filter((_, i) => i !== index))
    if (recognizedItems.length <= 1) {
      setStatus('idle')
    }
  }

  const totalCal = recognizedItems.reduce((sum, item) => sum + (item.actualCal || item.cal), 0)

  const handleConfirm = () => {
    if (recognizedItems.length === 0) return
    onConfirm(recognizedItems)
    onClose()
  }

  const renderPhotoTab = () => (
    <div className="space-y-4">
      <div className="relative w-full aspect-video bg-bg2 rounded-xl overflow-hidden flex items-center justify-center border border-border">
        {status === 'loading' ? (
          <div className="flex flex-col items-center gap-3">
            <Loader2 className="w-10 h-10 text-red animate-spin" />
            <span className="text-text2 text-sm">AI 识别中...</span>
          </div>
        ) : status === 'success' && recognizedItems.length > 0 ? (
          <div className="p-4 w-full">
            <div className="text-center mb-3">
              <span className="text-2xl">🍽️</span>
              <p className="text-text mt-2 font-medium">识别到 {recognizedItems.length} 种食物</p>
              <p className="text-gold text-lg font-bold mt-1">{totalCal} 大卡</p>
            </div>
            <button
              onClick={() => cameraInputRef.current?.click()}
              className="w-full py-2 text-sm text-blue hover:underline"
            >
              重新拍照
            </button>
          </div>
        ) : (
          <div className="flex flex-col items-center gap-2 text-text2">
            <Camera className="w-12 h-12" />
            <span className="text-sm">拍照或上传图片识别热量</span>
            <span className="text-xs text-text3">AI 自动识别食物热量</span>
          </div>
        )}
        {/* 拍照专用 input：capture="environment" 直接打开后置摄像头 */}
        <input
          ref={cameraInputRef}
          type="file"
          accept="image/*"
          capture="environment"
          className="hidden"
          onChange={handlePhotoUpload}
        />
        {/* 相册选择专用 input：不带 capture，弹出文件/相册选择器 */}
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={handlePhotoUpload}
        />
      </div>

      {status !== 'loading' && (
        <div className="flex gap-3">
          <Button fullWidth variant="primary" onClick={() => cameraInputRef.current?.click()}>
            <Camera className="w-4 h-4" />
            拍照识别
          </Button>
          <Button fullWidth variant="secondary" onClick={() => fileInputRef.current?.click()}>
            <ScanLine className="w-4 h-4" />
            从相册选择
          </Button>
        </div>
      )}

      {errorMsg && (
        <p className="text-red text-sm text-center">{errorMsg}</p>
      )}
    </div>
  )

  const renderBarcodeTab = () => (
    <div className="space-y-4">
      <div className="relative w-full aspect-video bg-bg2 rounded-xl overflow-hidden border border-border">
        <video
          ref={videoRef}
          className="w-full h-full object-cover"
          playsInline
          muted
        />
        <canvas ref={canvasRef} className="hidden" />
        {!cameraActive && status !== 'loading' && (
          <div className="absolute inset-0 flex flex-col items-center justify-center text-text2">
            <ScanLine className="w-12 h-12 mb-2" />
            <span className="text-sm">点击启动摄像头扫描条码</span>
            <span className="text-xs text-text3 mt-1">或从相册选择条码图片</span>
          </div>
        )}
        {status === 'loading' && (
          <div className="absolute inset-0 flex items-center justify-center bg-bg/80">
            <div className="flex flex-col items-center gap-2">
              <Loader2 className="w-8 h-8 text-red animate-spin" />
              <span className="text-sm text-text2">扫描中...</span>
            </div>
          </div>
        )}
        {cameraActive && (
          <>
            <div className="absolute inset-0 pointer-events-none">
              <div className="absolute inset-8 border-2 border-gold/50 rounded-lg" />
              <div className="absolute top-1/2 left-8 right-8 h-px bg-gold animate-pulse" />
            </div>
            <button
              onClick={stopCamera}
              className="absolute top-3 right-3 p-2 bg-black/50 rounded-full text-white"
            >
              <X className="w-4 h-4" />
            </button>
          </>
        )}
      </div>

      <div className="flex gap-3">
        {!cameraActive && (
          <Button fullWidth variant="primary" onClick={startBarcodeScanner}>
            <ScanLine className="w-4 h-4" />
            启动摄像头扫描
          </Button>
        )}
        <Button
          fullWidth
          variant="secondary"
          onClick={() => barcodeFileRef.current?.click()}
        >
          <Camera className="w-4 h-4" />
          从相册选择
        </Button>
        <input
          ref={barcodeFileRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={handleBarcodeFileUpload}
        />
      </div>
      {errorMsg && (
        <p className="text-red text-sm text-center">{errorMsg}</p>
      )}
    </div>
  )

  const renderSearchTab = () => (
    <div className="space-y-3">
      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-text3" />
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => handleSearch(e.target.value)}
          placeholder="搜索食物名称..."
          className="w-full pl-10 pr-4 py-3 bg-bg2 border border-border rounded-xl text-text placeholder:text-text3 focus:outline-none focus:border-red transition-colors"
        />
      </div>

      <div className="max-h-64 overflow-y-auto space-y-2">
        {searchResults.length > 0 ? (
          searchResults.map((item, idx) => (
            <motion.div
              key={idx}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: idx * 0.03 }}
              className="flex items-center justify-between p-3 bg-bg2 rounded-lg border border-border"
            >
              <div>
                <p className="text-text font-medium">{item.name}</p>
                <p className="text-text2 text-sm">{item.cal} 大卡 / 份</p>
              </div>
              <button
                onClick={() => addItemToResults(item)}
                className="p-2 bg-green/20 text-green rounded-lg hover:bg-green/30 transition-colors"
              >
                <Plus className="w-4 h-4" />
              </button>
            </motion.div>
          ))
        ) : searchQuery ? (
          <p className="text-center text-text3 py-8">未找到相关食物</p>
        ) : (
          <p className="text-center text-text3 py-8">输入食物名称搜索</p>
        )}
      </div>
    </div>
  )

  return (
    <AnimatePresence>
      {open && (
        <div className="fixed inset-0 z-50 flex items-end justify-center">
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="absolute inset-0 bg-black/60 backdrop-blur-sm"
            onClick={onClose}
          />
          <motion.div
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', damping: 30, stiffness: 300 }}
            className="relative w-full max-w-[480px] bg-bg2 rounded-t-3xl border-t border-x border-border max-h-[90vh] overflow-hidden flex flex-col"
          >
            <div className="flex items-center justify-between p-4 border-b border-border">
              <h3 className="text-lg font-bold">
                {mealType === 'breakfast' && '添加早餐'}
                {mealType === 'lunch' && '添加午餐'}
                {mealType === 'dinner' && '添加晚餐'}
                {mealType === 'snack' && '添加零食'}
              </h3>
              <button
                onClick={onClose}
                className="p-2 text-text2 hover:text-text transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="flex border-b border-border">
              {[
                { key: 'photo' as TabType, label: '拍照识别', icon: Camera },
                { key: 'barcode' as TabType, label: '扫码', icon: ScanLine },
                { key: 'search' as TabType, label: '搜索', icon: Search },
              ].map(tab => (
                <button
                  key={tab.key}
                  onClick={() => setActiveTab(tab.key)}
                  className={`flex-1 py-3 flex items-center justify-center gap-2 text-sm font-medium transition-colors border-b-2 ${
                    activeTab === tab.key
                      ? 'text-red border-red'
                      : 'text-text2 border-transparent hover:text-text'
                  }`}
                >
                  <tab.icon className="w-4 h-4" />
                  {tab.label}
                </button>
              ))}
            </div>

            <div className="flex-1 overflow-y-auto p-4">
              {activeTab === 'photo' && renderPhotoTab()}
              {activeTab === 'barcode' && renderBarcodeTab()}
              {activeTab === 'search' && renderSearchTab()}

              {recognizedItems.length > 0 && (
                <motion.div
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="mt-6"
                >
                  <h4 className="font-bold mb-3 flex items-center gap-2">
                    <Check className="w-4 h-4 text-green" />
                    已选食物 ({recognizedItems.length})
                  </h4>
                  <div className="space-y-2">
                    {recognizedItems.map((item, idx) => (
                      <Card key={idx} className="p-3">
                        <div className="flex items-center justify-between">
                          <div>
                            <p className="font-medium">{item.name}</p>
                            <p className="text-gold text-sm font-bold">
                              {item.actualCal || item.cal} 大卡
                            </p>
                          </div>
                          <button
                            onClick={() => removeItem(idx)}
                            className="p-1.5 text-text3 hover:text-red transition-colors"
                          >
                            <X className="w-4 h-4" />
                          </button>
                        </div>
                        <div className="flex gap-1 mt-2">
                          {(['small', 'medium', 'large'] as const).map(p => (
                            <button
                              key={p}
                              onClick={() => adjustPortion(idx, p)}
                              className={`flex-1 py-1 text-xs rounded-md transition-colors ${
                                (item.portion || 'medium') === p
                                  ? 'bg-red text-white'
                                  : 'bg-bg text-text2 hover:bg-bg3'
                              }`}
                            >
                              {p === 'small' && '小份'}
                              {p === 'medium' && '中份'}
                              {p === 'large' && '大份'}
                            </button>
                          ))}
                        </div>
                      </Card>
                    ))}
                  </div>
                </motion.div>
              )}
            </div>

            {recognizedItems.length > 0 && (
              <div className="p-4 border-t border-border bg-bg2">
                <div className="flex items-center justify-between mb-3">
                  <span className="text-text2">预计摄入</span>
                  <span className="text-gold text-xl font-bold">{totalCal} 大卡</span>
                </div>
                <Button fullWidth variant="primary" onClick={handleConfirm}>
                  确认添加
                </Button>
              </div>
            )}
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  )
}
