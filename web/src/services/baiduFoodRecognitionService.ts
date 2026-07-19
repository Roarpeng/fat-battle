import type { FoodRecognitionItem, FoodRecognitionResult } from './foodRecognitionService'
import { NetworkError } from './retry'

// 百度 API 返回的原始数据结构
export interface BaiduDishItem {
  name: string
  /** 每100g的卡路里（字符串） */
  calorie: string
  /** 0-1（字符串） */
  probability: string
  has_calorie: boolean
  baike_info?: {
    baike_url?: string
    image_url?: string
    description?: string
  }
}

// 后端代理返回结构
interface BaiduProxyResponse {
  success: boolean
  items?: BaiduDishItem[]
  source?: string
  log_id?: string
  error?: string
  code?: string
}

// 配置选项
export interface BaiduFoodRecognitionOptions {
  /** 返回结果数量，默认 5 */
  topNum?: number
  /** 过滤阈值（0-1），默认 0.8（比百度官方默认 0.95 宽松，多返回结果） */
  filterThreshold?: number
  /** 后端代理 URL，默认 '/api/food-recognize' */
  proxyUrl?: string
  /** 自定义 fetch（便于测试注入） */
  fetchFn?: typeof fetch
}

const DEFAULT_TOP_NUM = 5
const DEFAULT_FILTER_THRESHOLD = 0.8
const DEFAULT_PROXY_URL = '/api/food-recognize'
/** 全部无卡路里时的默认卡路里（每100g） */
const DEFAULT_CAL_WHEN_NO_CALORIE = 200
/** 全部无卡路里时的默认置信度 */
const DEFAULT_CONFIDENCE_WHEN_NO_CALORIE = 0.3

/**
 * 将 File 转换为 base64（去掉 data URL 头）
 */
export function fileToBase64(file: File): Promise<string> {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => {
      const result = reader.result
      if (typeof result !== 'string') {
        reject(new Error('fileToBase64: 无法读取文件内容'))
        return
      }
      // 去掉 data URL 头：data:image/png;base64,xxxxx
      const base64 = result.includes(',') ? result.split(',')[1] : result
      resolve(base64)
    }
    reader.onerror = () => {
      reject(new Error('fileToBase64: 文件读取失败'))
    }
    reader.readAsDataURL(file)
  })
}

/**
 * 将百度返回结构归一化为 FoodRecognitionItem[]
 *
 * 关键：calorie 是"每100g卡路里"，直接作为基准值，由现有 portion 系统调整。
 * - 过滤 has_calorie: false 的结果（无卡路里数据）
 * - confidence 由 probability 字符串映射
 * - source 统一标注为 'online'
 * - 按 probability 降序排序
 * - 默认 portion 为 'medium'，actualCal = cal
 * - 若全部无卡路里，返回低置信度默认项
 */
function normalizeBaiduItems(items: BaiduDishItem[]): FoodRecognitionItem[] {
  const withCalorie = items.filter(item => item.has_calorie)

  if (withCalorie.length === 0) {
    // 全部无卡路里：取第一个名字作为低置信度项，使用默认卡路里
    if (items.length === 0) {
      return []
    }
    const first = items[0]
    return [
      {
        name: first.name,
        cal: DEFAULT_CAL_WHEN_NO_CALORIE,
        confidence: DEFAULT_CONFIDENCE_WHEN_NO_CALORIE,
        portion: 'medium',
        actualCal: DEFAULT_CAL_WHEN_NO_CALORIE,
        source: 'online',
      },
    ]
  }

  const normalized: FoodRecognitionItem[] = withCalorie.map(item => {
    const cal = parseFloat(item.calorie)
    const safeCal = Number.isFinite(cal) && cal > 0 ? Math.round(cal) : DEFAULT_CAL_WHEN_NO_CALORIE
    const prob = parseFloat(item.probability)
    const confidence = Number.isFinite(prob) ? Math.min(Math.max(prob, 0), 1) : 0
    return {
      name: item.name,
      cal: safeCal,
      confidence,
      portion: 'medium' as const,
      actualCal: safeCal,
      source: 'online' as const,
    }
  })

  // 按 probability（即 confidence）降序
  normalized.sort((a, b) => b.confidence - a.confidence)
  return normalized
}

/**
 * 基于识别结果生成简单建议（与 foodRecognitionService 的逻辑保持一致）
 */
function generateSuggestions(
  items: FoodRecognitionItem[],
  totalCal: number
): { type: 'good' | 'warning' | 'info'; text: string }[] {
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

/**
 * 调用后端百度 API 代理识别菜品
 *
 * 返回归一化后的 FoodRecognitionResult。
 * - 网络层错误抛出 NetworkError，便于上层重试
 * - 后端返回 success=false 时抛出 Error（携带 error/code）
 * - 空结果或全部无卡路里时返回低置信度默认项（不抛错）
 */
export async function recognizeByBaidu(
  imageBase64: string,
  options: BaiduFoodRecognitionOptions = {}
): Promise<FoodRecognitionResult> {
  const {
    topNum = DEFAULT_TOP_NUM,
    filterThreshold = DEFAULT_FILTER_THRESHOLD,
    proxyUrl = DEFAULT_PROXY_URL,
    fetchFn,
  } = options

  const fetchImpl = fetchFn ?? (typeof fetch !== 'undefined' ? fetch.bind(globalThis) : undefined)
  if (!fetchImpl) {
    throw new NetworkError('recognizeByBaidu: 当前环境无 fetch 实现')
  }

  let response: Response
  try {
    response = await fetchImpl(proxyUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        image: imageBase64,
        topNum,
        filterThreshold,
      }),
    })
  } catch (err) {
    // 网络层错误：抛 NetworkError 以便上层重试
    throw new NetworkError(
      `百度识别请求失败: ${err instanceof Error ? err.message : String(err)}`
    )
  }

  if (!response.ok) {
    throw new NetworkError(`百度识别 HTTP 错误: ${response.status} ${response.statusText}`)
  }

  let payload: BaiduProxyResponse
  try {
    payload = (await response.json()) as BaiduProxyResponse
  } catch (err) {
    throw new NetworkError(
      `百度识别响应解析失败: ${err instanceof Error ? err.message : String(err)}`
    )
  }

  if (!payload.success) {
    const errMsg = payload.error || '百度识别失败（后端返回 success=false）'
    const error = new Error(errMsg)
    if (payload.code) {
      ;(error as Error & { code?: string }).code = payload.code
    }
    throw error
  }

  const rawItems = Array.isArray(payload.items) ? payload.items : []
  const items = normalizeBaiduItems(rawItems)
  const totalCal = items.reduce((sum, item) => sum + item.cal, 0)
  const suggestions = generateSuggestions(items, totalCal)

  return {
    items,
    totalCal,
    suggestions,
    source: 'online',
  }
}
