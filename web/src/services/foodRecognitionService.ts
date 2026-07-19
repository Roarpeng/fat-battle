import { withRetry, isNetworkError, NetworkError, type RetryOptions } from './retry'
import { withFallback } from './apiFallback'
import { recognizeByBaidu, fileToBase64 } from './baiduFoodRecognitionService'

export interface FoodRecognitionItem {
  name: string
  cal: number
  confidence: number
  portion?: 'small' | 'medium' | 'large'
  actualCal?: number
  /** 数据来源标注（仅在使用降级链时填充） */
  source?: 'online' | 'cache' | 'fallback'
}

export interface FoodRecognitionResult {
  items: FoodRecognitionItem[]
  totalCal: number
  suggestions: { type: 'good' | 'warning' | 'info'; text: string }[]
  /** 数据来源标注（仅在使用降级链时填充） */
  source?: 'online' | 'cache' | 'fallback'
}

export type RecognitionStatus = 'idle' | 'loading' | 'success' | 'error'

const PORTION_MULTIPLIERS: Record<string, number> = {
  small: 0.7,
  medium: 1.0,
  large: 1.3,
}

const MOCK_FOODS = [
  { name: '米饭', cal: 230, keywords: ['rice', '米饭', '白饭'] },
  { name: '黄焖鸡米饭', cal: 650, keywords: ['黄焖鸡', 'braised', 'chicken rice'] },
  { name: '螺蛳粉', cal: 550, keywords: ['螺蛳', 'snail', 'luosifen'] },
  { name: '煎饼果子', cal: 420, keywords: ['煎饼', 'jianbing', 'crepe'] },
  { name: '红烧肉', cal: 450, keywords: ['红烧', 'braised pork', 'pork belly'] },
  { name: '宫保鸡丁', cal: 320, keywords: ['宫保', 'kung pao', 'chicken'] },
  { name: '麻婆豆腐', cal: 280, keywords: ['麻婆', 'mapo', 'tofu'] },
  { name: '鸡胸肉', cal: 165, keywords: ['鸡胸', 'chicken breast', 'breast'] },
  { name: '鸡蛋', cal: 70, keywords: ['蛋', 'egg'] },
  { name: '牛肉面', cal: 480, keywords: ['牛肉', 'beef noodle', 'noodle'] },
  { name: '汉堡', cal: 550, keywords: ['汉堡', 'burger', 'hamburger'] },
  { name: '薯条', cal: 320, keywords: ['薯条', 'fries', 'chip'] },
  { name: '披萨', cal: 285, keywords: ['披萨', 'pizza'] },
  { name: '苹果', cal: 52, keywords: ['苹果', 'apple'] },
  { name: '香蕉', cal: 89, keywords: ['香蕉', 'banana'] },
  { name: '牛奶', cal: 54, keywords: ['牛奶', 'milk'] },
  { name: '咖啡', cal: 2, keywords: ['咖啡', 'coffee'] },
  { name: '可乐', cal: 140, keywords: ['可乐', 'cola', 'coke'] },
  { name: '沙拉', cal: 150, keywords: ['沙拉', 'salad'] },
  { name: '寿司', cal: 200, keywords: ['寿司', 'sushi'] },
]

export interface FoodRecognitionServiceOptions {
  onStatusChange?: (status: RecognitionStatus) => void
  /** 自定义重试配置，默认 2 次重试 + 指数退避 */
  retryOptions?: RetryOptions
  /** 是否启用重试，默认 true；置 false 可完全关闭重试 */
  enableRetry?: boolean
  /** 是否启用多源降级链，默认 true；置 false 仅使用主源 */
  enableFallback?: boolean
  /** 在线状态检测函数（便于测试注入），默认读取 navigator.onLine */
  isOnline?: () => boolean
  /** 是否启用百度识别（主源），默认 true */
  enableBaidu?: boolean
  /** 百度识别 top_num，默认 5 */
  baiduTopNum?: number
  /** 百度识别 filter_threshold，默认 0.8 */
  baiduFilterThreshold?: number
}

const DEFAULT_RETRY_OPTIONS: RetryOptions = {
  retries: 2,
  delay: 1000,
  backoff: 'exponential',
  factor: 2,
}

export class FoodRecognitionService {
  private status: RecognitionStatus = 'idle'
  private onStatusChange?: (status: RecognitionStatus) => void
  private retryOptions: RetryOptions
  private enableRetry: boolean
  private enableFallback: boolean
  private isOnlineFn: () => boolean
  private enableBaidu: boolean
  private baiduTopNum: number
  private baiduFilterThreshold: number

  constructor(options: FoodRecognitionServiceOptions = {}) {
    this.onStatusChange = options.onStatusChange
    this.retryOptions = options.retryOptions ?? DEFAULT_RETRY_OPTIONS
    this.enableRetry = options.enableRetry ?? true
    this.enableFallback = options.enableFallback ?? true
    this.isOnlineFn = options.isOnline ?? (() =>
      typeof navigator !== 'undefined' ? navigator.onLine : true
    )
    this.enableBaidu = options.enableBaidu ?? true
    this.baiduTopNum = options.baiduTopNum ?? 5
    this.baiduFilterThreshold = options.baiduFilterThreshold ?? 0.8
  }

  private setStatus(status: RecognitionStatus) {
    this.status = status
    this.onStatusChange?.(status)
  }

  /** 检查网络是否可用 */
  private isOnline(): boolean {
    return this.isOnlineFn()
  }

  /** 包装重试逻辑（可被 enableRetry 关闭） */
  private async runWithRetry<T>(fn: () => Promise<T>): Promise<T> {
    if (!this.enableRetry) return fn()
    return withRetry(fn, {
      ...this.retryOptions,
      shouldRetry: (err) => {
        // 仅网络类错误重试
        if (!isNetworkError(err)) return false
        return this.retryOptions.shouldRetry ? this.retryOptions.shouldRetry(err) : true
      },
    })
  }

  // ========== 四级降级链：百度 → 薄荷健康 → FatSecret → 本地 ==========

  /** 主源：百度菜品识别（真实 API，通过后端代理） */
  private async recognizeFromBaidu(imageFile: File): Promise<FoodRecognitionResult> {
    if (!this.enableBaidu) {
      throw new Error('百度识别已禁用')
    }
    if (!this.isOnline()) {
      throw new NetworkError('网络不可用，跳过百度识别')
    }
    const imageBase64 = await fileToBase64(imageFile)
    return recognizeByBaidu(imageBase64, {
      topNum: this.baiduTopNum,
      filterThreshold: this.baiduFilterThreshold,
    })
  }

  /** 次源1：薄荷健康（模拟在线识别） */
  private async recognizeFromBohe(imageFile: File): Promise<FoodRecognitionResult> {
    if (!this.isOnline()) {
      throw new NetworkError('网络不可用，跳过在线识别')
    }
    await new Promise(resolve => setTimeout(resolve, 1500))

    const numItems = Math.floor(Math.random() * 3) + 1
    const shuffled = [...MOCK_FOODS].sort(() => Math.random() - 0.5)
    const items: FoodRecognitionItem[] = shuffled.slice(0, numItems).map(food => ({
      name: food.name,
      cal: food.cal,
      confidence: Math.random() * 0.3 + 0.7,
      portion: 'medium',
      actualCal: food.cal,
      source: 'online' as const,
    }))

    const totalCal = items.reduce((sum, item) => sum + item.cal, 0)
    const suggestions = this.generateSuggestions(items, totalCal)
    return { items, totalCal, suggestions, source: 'online' }
  }

  /** 次源2：FatSecret（模拟缓存命中，延迟较短） */
  private async recognizeFromFatSecret(imageFile: File): Promise<FoodRecognitionResult> {
    if (!this.isOnline()) {
      throw new NetworkError('网络不可用，跳过 FatSecret')
    }
    await new Promise(resolve => setTimeout(resolve, 800))

    // 取一个稳定结果（基于文件大小哈希）模拟缓存命中
    const seed = imageFile.size % MOCK_FOODS.length
    const baseFood = MOCK_FOODS[seed]
    const items: FoodRecognitionItem[] = [{
      name: baseFood.name,
      cal: baseFood.cal,
      confidence: 0.85,
      portion: 'medium',
      actualCal: baseFood.cal,
      source: 'cache' as const,
    }]

    const totalCal = items.reduce((sum, item) => sum + item.cal, 0)
    const suggestions = this.generateSuggestions(items, totalCal)
    return { items, totalCal, suggestions, source: 'cache' }
  }

  /** 兜底：本地（离线仍可用，保证可用性） */
  private async recognizeFromLocal(imageFile: File): Promise<FoodRecognitionResult> {
    await new Promise(resolve => setTimeout(resolve, 300))

    // 使用确定性结果，确保离线也能返回稳定数据
    const seed = (imageFile.size + imageFile.name.length) % MOCK_FOODS.length
    const baseFood = MOCK_FOODS[seed]
    const items: FoodRecognitionItem[] = [{
      name: baseFood.name,
      cal: baseFood.cal,
      confidence: 0.6,
      portion: 'medium',
      actualCal: baseFood.cal,
      source: 'fallback' as const,
    }]

    const totalCal = items.reduce((sum, item) => sum + item.cal, 0)
    const suggestions = this.generateSuggestions(items, totalCal)
    return { items, totalCal, suggestions, source: 'fallback' }
  }

  async recognizeFromImage(imageFile: File): Promise<FoodRecognitionResult> {
    this.setStatus('loading')

    try {
      const providers: Array<() => Promise<FoodRecognitionResult>> = []

      // 主源：百度
      if (this.enableBaidu) {
        providers.push(() => this.runWithRetry(() => this.recognizeFromBaidu(imageFile)))
      }
      // 次源1：薄荷健康
      providers.push(() => this.runWithRetry(() => this.recognizeFromBohe(imageFile)))
      // 次源2：FatSecret
      providers.push(() => this.runWithRetry(() => this.recognizeFromFatSecret(imageFile)))
      // 兜底：本地
      providers.push(() => this.recognizeFromLocal(imageFile))

      const result = this.enableFallback
        ? await withFallback<FoodRecognitionResult>(providers)
        : await providers[0]()

      this.setStatus('success')
      return result
    } catch (error) {
      this.setStatus('error')
      throw error
    }
  }

  // ========== 条形码识别降级链 ==========

  /** 主源：薄荷健康条形码查询（在线） */
  private async recognizeBarcodeFromBohe(barcode: string): Promise<FoodRecognitionItem> {
    if (!this.isOnline()) {
      throw new NetworkError('网络不可用，跳过在线条形码查询')
    }
    await new Promise(resolve => setTimeout(resolve, 800))

    const hash = barcode.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0)
    const index = hash % MOCK_FOODS.length
    const food = MOCK_FOODS[index]
    return {
      name: food.name,
      cal: food.cal,
      confidence: 0.95,
      portion: 'medium',
      actualCal: food.cal,
      source: 'online',
    }
  }

  /** 第二源：FatSecret 条形码查询（缓存） */
  private async recognizeBarcodeFromFatSecret(barcode: string): Promise<FoodRecognitionItem> {
    if (!this.isOnline()) {
      throw new NetworkError('网络不可用，跳过 FatSecret 条形码查询')
    }
    await new Promise(resolve => setTimeout(resolve, 500))

    const hash = barcode.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0)
    const index = (hash + 1) % MOCK_FOODS.length
    const food = MOCK_FOODS[index]
    return {
      name: food.name,
      cal: food.cal,
      confidence: 0.8,
      portion: 'medium',
      actualCal: food.cal,
      source: 'cache',
    }
  }

  /** 第三源：本地条形码兜底 */
  private async recognizeBarcodeFromLocal(barcode: string): Promise<FoodRecognitionItem> {
    await new Promise(resolve => setTimeout(resolve, 200))

    const hash = barcode.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0)
    const index = hash % MOCK_FOODS.length
    const food = MOCK_FOODS[index]
    return {
      name: food.name,
      cal: food.cal,
      confidence: 0.5,
      portion: 'medium',
      actualCal: food.cal,
      source: 'fallback',
    }
  }

  async recognizeFromBarcode(barcode: string): Promise<FoodRecognitionItem | null> {
    this.setStatus('loading')

    try {
      const result = this.enableFallback
        ? await withFallback<FoodRecognitionItem>([
            () => this.runWithRetry(() => this.recognizeBarcodeFromBohe(barcode)),
            () => this.runWithRetry(() => this.recognizeBarcodeFromFatSecret(barcode)),
            () => this.recognizeBarcodeFromLocal(barcode),
          ])
        : await this.runWithRetry(() => this.recognizeBarcodeFromBohe(barcode))

      this.setStatus('success')
      return result
    } catch (error) {
      this.setStatus('error')
      throw error
    }
  }

  searchFoods(query: string): FoodRecognitionItem[] {
    if (!query.trim()) return []

    const lowerQuery = query.toLowerCase()
    return MOCK_FOODS
      .filter(food =>
        food.name.includes(query) ||
        food.keywords.some(kw => kw.toLowerCase().includes(lowerQuery))
      )
      .slice(0, 10)
      .map(food => ({
        name: food.name,
        cal: food.cal,
        confidence: 1,
        portion: 'medium',
        actualCal: food.cal,
      }))
  }

  updatePortion(item: FoodRecognitionItem, portion: 'small' | 'medium' | 'large'): FoodRecognitionItem {
    const multiplier = PORTION_MULTIPLIERS[portion]
    return {
      ...item,
      portion,
      actualCal: Math.round(item.cal * multiplier),
    }
  }

  private generateSuggestions(items: FoodRecognitionItem[], totalCal: number) {
    const suggestions: { type: 'good' | 'warning' | 'info'; text: string }[] = []

    const hasVegetable = items.some(i =>
      i.name.includes('菜') || i.name.includes('沙拉') || i.name.includes('蔬菜')
    )
    const hasProtein = items.some(i =>
      i.name.includes('肉') || i.name.includes('鸡') || i.name.includes('蛋') || i.name.includes('鱼')
    )
    const hasStaple = items.some(i =>
      i.name.includes('饭') || i.name.includes('面') || i.name.includes('米')
    )

    if (hasVegetable) {
      suggestions.push({ type: 'good', text: '蔬菜比例很好，继续保持！' })
    } else {
      suggestions.push({ type: 'warning', text: '建议搭配一些蔬菜，营养更均衡' })
    }

    if (hasProtein) {
      suggestions.push({ type: 'good', text: '蛋白质充足，有助于肌肉合成' })
    }

    if (totalCal > 600) {
      suggestions.push({ type: 'warning', text: '这餐热量偏高，饭后可以适当运动一下' })
    } else if (totalCal < 200) {
      suggestions.push({ type: 'info', text: '热量较低，注意不要饿肚子哦' })
    }

    if (hasStaple && hasProtein && hasVegetable) {
      suggestions.push({ type: 'good', text: '营养搭配很均衡，脂肪怪最怕你这样吃！' })
    }

    return suggestions
  }

  getStatus(): RecognitionStatus {
    return this.status
  }
}

export const foodRecognitionService = new FoodRecognitionService()
