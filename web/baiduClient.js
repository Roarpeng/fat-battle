// 百度 API 客户端 - 后端专用，不暴露到前端
// 纯 JS 版本，供 server.js 直接 import（无需编译）。
// 类型定义见 src/server/baiduClient.ts

import sharp from 'sharp';

const DEFAULT_TOKEN_REFRESH_BUFFER = 5 * 60 * 1000 // 5 分钟
const DEFAULT_TOP_NUM = 15
const DEFAULT_FILTER_THRESHOLD = 0.1

const TOKEN_URL = 'https://aip.baidubce.com/oauth/2.0/token'
const DISH_URL = 'https://aip.baidubce.com/rest/2.0/image-classify/v2/dish'
const INGREDIENT_URL = 'https://aip.baidubce.com/rest/2.0/image-classify/v1/classify/ingredient'
const PLANT_URL = 'https://aip.baidubce.com/rest/2.0/image-classify/v1/plant'
const ANIMAL_URL = 'https://aip.baidubce.com/rest/2.0/image-classify/v1/animal'
const COMBO_URL = 'https://aip.baidubce.com/api/v1/solution/direct/imagerecognition/combination'

/**
 * 百度 AI 开放平台客户端
 *
 * 封装 access_token 的获取与缓存，以及菜品识别接口。
 * 该模块仅在后端使用，API Key 不会暴露到前端。
 */
export class BaiduClient {
  /**
   * @param {object} [options]
   * @param {string} [options.apiKey]
   * @param {string} [options.secretKey]
   * @param {number} [options.tokenRefreshBuffer] token 提前刷新时间（毫秒），默认 5 分钟
   */
  constructor(options = {}) {
    this.apiKey = options.apiKey ?? process.env.BAIDU_API_KEY ?? ''
    this.secretKey = options.secretKey ?? process.env.BAIDU_SECRET_KEY ?? ''
    this.tokenRefreshBuffer = options.tokenRefreshBuffer ?? DEFAULT_TOKEN_REFRESH_BUFFER
    /** @type {{ token: string, expiresAt: number } | null} */
    this.tokenCache = null
  }

  /** 健康检查 - 配置是否就绪 */
  isConfigured() {
    return Boolean(this.apiKey && this.secretKey)
  }

  /** 清除 token 缓存（用于测试） */
  clearTokenCache() {
    this.tokenCache = null
  }

  /** 当前是否已持有有效 token（未过期且未到刷新窗口） */
  hasValidToken() {
    if (!this.tokenCache) return false
    return Date.now() < this.tokenCache.expiresAt - this.tokenRefreshBuffer
  }

  /** 获取 access_token（带缓存） */
  async getAccessToken() {
    if (this.hasValidToken()) {
      return this.tokenCache.token
    }

    if (!this.isConfigured()) {
      throw new Error('BaiduClient 未配置：缺少 BAIDU_API_KEY / BAIDU_SECRET_KEY')
    }

    const url =
      `${TOKEN_URL}?grant_type=client_credentials` +
      `&client_id=${encodeURIComponent(this.apiKey)}` +
      `&client_secret=${encodeURIComponent(this.secretKey)}`

    const resp = await fetch(url, { method: 'POST' })
    if (!resp.ok) {
      throw new Error(`获取 access_token 失败：HTTP ${resp.status}`)
    }
    const data = await resp.json()

    if (!data.access_token) {
      throw new Error(
        `获取 access_token 失败：${data.error ?? 'unknown'} - ${data.error_description ?? ''}`,
      )
    }

    const expiresInSec = data.expires_in ?? 2592000 // 默认 30 天
    this.tokenCache = {
      token: data.access_token,
      expiresAt: Date.now() + expiresInSec * 1000,
    }
    return data.access_token
  }

  /**
   * 菜品识别
   * @param {string} imageBase64 图片 base64（可带或不带 data URL 头）
   * @param {object} [options]
   * @param {number} [options.topNum] 默认 5
   * @param {number} [options.filterThreshold] 默认 0.8
   * @param {number} [options.baikeNum]
   * @returns {Promise<object>} 百度菜品识别响应
   */
  async recognizeDish(imageBase64, options = {}) {
    const topNum = options.topNum ?? DEFAULT_TOP_NUM
    const filterThreshold = options.filterThreshold ?? DEFAULT_FILTER_THRESHOLD

    // 去掉可能的 data URL 头
    const pureBase64 = imageBase64.replace(/^data:image\/[a-zA-Z]+;base64,/, '')

    const body = new URLSearchParams({
      image: pureBase64,
      top_num: String(topNum),
      filter_threshold: String(filterThreshold),
    })
    if (options.baikeNum != null) {
      body.set('baike_num', String(options.baikeNum))
    }

    const doRequest = async (token) => {
      return fetch(`${DISH_URL}?access_token=${encodeURIComponent(token)}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: body.toString(),
      })
    }

    let token = await this.getAccessToken()
    let resp = await doRequest(token)

    // 401/403 视为 token 失效，强制刷新一次重试
    if (resp.status === 401 || resp.status === 403) {
      this.clearTokenCache()
      token = await this.getAccessToken()
      resp = await doRequest(token)
    }

    if (!resp.ok) {
      throw new Error(`百度菜品识别失败：HTTP ${resp.status}`)
    }

    const data = await resp.json()
    if (data.error_code != null) {
      throw new Error(`百度菜品识别失败：${data.error_code} - ${data.error_msg ?? ''}`)
    }
    return data
  }

  /**
   * 果蔬识别
   * @param {string} imageBase64
   * @param {object} [options]
   * @param {number} [options.topNum] 默认 5
   * @returns {Promise<object>}
   */
  async recognizeIngredient(imageBase64, options = {}) {
    const topNum = options.topNum ?? DEFAULT_TOP_NUM
    const pureBase64 = imageBase64.replace(/^data:image\/[a-zA-Z]+;base64,/, '')
    const body = new URLSearchParams({
      image: pureBase64,
      top_num: String(topNum),
    })
    const token = await this.getAccessToken()
    const resp = await fetch(`${INGREDIENT_URL}?access_token=${encodeURIComponent(token)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    })
    if (!resp.ok) throw new Error(`百度果蔬识别失败：HTTP ${resp.status}`)
    const data = await resp.json()
    if (data.error_code != null) {
      throw new Error(`百度果蔬识别失败：${data.error_code} - ${data.error_msg ?? ''}`)
    }
    return data
  }

  /**
   * 植物识别
   * @param {string} imageBase64
   * @param {number} [topNum=5]
   * @param {number} [baikeNum=0]
   * @returns {Promise<object>}
   */
  async recognizePlant(imageBase64, topNum = DEFAULT_TOP_NUM, baikeNum = 0) {
    const pureBase64 = imageBase64.replace(/^data:image\/[a-zA-Z]+;base64,/, '')
    const body = new URLSearchParams({
      image: pureBase64,
      top_num: String(topNum),
    })
    if (baikeNum > 0) body.set('baike_num', String(baikeNum))
    const token = await this.getAccessToken()
    const resp = await fetch(`${PLANT_URL}?access_token=${encodeURIComponent(token)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    })
    if (!resp.ok) throw new Error(`百度植物识别失败：HTTP ${resp.status}`)
    const data = await resp.json()
    if (data.error_code != null) {
      throw new Error(`百度植物识别失败：${data.error_code} - ${data.error_msg ?? ''}`)
    }
    return data
  }

  /**
   * 动物识别
   * @param {string} imageBase64
   * @param {number} [topNum=5]
   * @param {number} [baikeNum=0]
   * @returns {Promise<object>}
   */
  async recognizeAnimal(imageBase64, topNum = DEFAULT_TOP_NUM, baikeNum = 0) {
    const pureBase64 = imageBase64.replace(/^data:image\/[a-zA-Z]+;base64,/, '')
    const body = new URLSearchParams({
      image: pureBase64,
      top_num: String(topNum),
    })
    if (baikeNum > 0) body.set('baike_num', String(baikeNum))
    const token = await this.getAccessToken()
    const resp = await fetch(`${ANIMAL_URL}?access_token=${encodeURIComponent(token)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    })
    if (!resp.ok) throw new Error(`百度动物识别失败：HTTP ${resp.status}`)
    const data = await resp.json()
    if (data.error_code != null) {
      throw new Error(`百度动物识别失败：${data.error_code} - ${data.error_msg ?? ''}`)
    }
    return data
  }

  /**
   * 组合识别（并行调用 果蔬+植物+动物，合并结果）
   * @param {string} imageBase64
   * @returns {Promise<object>} 合并后的结果，包含 { ingredient: [], plant: [], animal: [] }
   */
  async recognizeCombination(imageBase64) {
    const pureBase64 = imageBase64.replace(/^data:image\/[a-zA-Z]+;base64,/, '')
    const body = JSON.stringify({
      image: pureBase64,
      scenes: ['ingredient', 'plant', 'animal'],
    })
    const token = await this.getAccessToken()
    const resp = await fetch(`${COMBO_URL}?access_token=${encodeURIComponent(token)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
    })
    if (!resp.ok) throw new Error(`百度组合识别失败：HTTP ${resp.status}`)
    const data = await resp.json()
    if (data.error_code != null) {
      throw new Error(`百度组合识别失败：${data.error_code} - ${data.error_msg ?? ''}`)
    }
    return data
  }

  /**
   * 智能识别：图像增强 + 多尺度识别 + 菜品/组合服务兜底
   *
   * 优化策略：
   * 1. 图像预处理（增强对比度、锐化、亮度调整）
   * 2. 多尺度识别（原图 + ROI中心裁剪 + 增强图）
   * 3. 菜品识别 → 组合服务（果蔬+植物+动物）兜底
   * 4. 合并所有结果，按置信度排序
   *
   * @param {string} imageBase64
   * @param {object} [options]
   * @param {number} [options.topNum]
   * @param {number} [options.filterThreshold]
   * @returns {Promise<{items: Array, source: string, log_id?: string}>}
   */
  async recognizeFood(imageBase64, options = {}) {
    const pureBase64 = imageBase64.replace(/^data:image\/[a-zA-Z]+;base64,/, '')
    const topNum = options.topNum ?? DEFAULT_TOP_NUM
    const filterThreshold = options.filterThreshold ?? DEFAULT_FILTER_THRESHOLD

    // 1. 生成多种预处理版本的图片
    const variants = await this._preprocessVariants(pureBase64)
    console.log(`[BaiduClient] 生成 ${variants.length} 个图片变体`)

    // 2. 并行对所有变体做菜品识别
    const allDishItems = []
    let dishLogId = null

    await Promise.all(
      variants.map(async (variant) => {
        try {
          const result = await this.recognizeDish(variant.base64, {
            topNum,
            filterThreshold: Math.min(filterThreshold, 0.1),
          })
          if (result.log_id) dishLogId = String(result.log_id)
          const dishes = result.result ?? []
          for (const d of dishes) {
            if (d.name && d.name !== '非菜' && d.name !== '非菜品') {
              allDishItems.push({
                name: d.name,
                probability: parseFloat(d.probability) || 0,
                calorie: d.calorie,
                has_calorie: d.has_calorie,
                source: 'dish',
                variant: variant.name,
              })
            }
          }
        } catch (e) {
          console.warn(`[BaiduClient] ${variant.name} 菜品识别失败:`, e.message)
        }
      }),
    )

    // 3. 菜品识别有有效结果 → 去重合并，按置信度排序返回
    if (allDishItems.length > 0) {
      const merged = this._mergeAndSortItems(allDishItems)
      console.log(`[BaiduClient] 菜品识别命中，合并后 ${merged.length} 个结果`)
      return {
        items: merged,
        source: 'baidu-dish-enhanced',
        log_id: dishLogId,
      }
    }

    // 4. 菜品识别全失败 → 调用组合服务（果蔬+植物+动物）
    console.log('[BaiduClient] 菜品识别无结果，尝试组合服务')
    const comboResult = await this.recognizeCombination(variants[0].base64)
    const comboData = comboResult.result ?? {}
    const allItems = []

    // 果蔬
    const ingredient = comboData.ingredient ?? {}
    if (ingredient.result && ingredient.result.length > 0) {
      for (const item of ingredient.result) {
        if (item.name && item.name !== '非果蔬食材') {
          allItems.push({
            name: item.name,
            probability: item.score,
            calorie: item.calorie ?? '0',
            has_calorie: Boolean(item.calorie),
            source: 'ingredient',
          })
        }
      }
    }

    // 植物
    const plant = comboData.plant ?? {}
    if (plant.result && plant.result.length > 0) {
      for (const item of plant.result) {
        if (item.name && item.name !== '非植物') {
          allItems.push({
            name: item.name,
            probability: item.score,
            calorie: '0',
            has_calorie: false,
            source: 'plant',
          })
        }
      }
    }

    // 动物
    const animal = comboData.animal ?? {}
    if (animal.result && animal.result.length > 0) {
      for (const item of animal.result) {
        if (item.name && item.name !== '非动物') {
          allItems.push({
            name: item.name,
            probability: item.score,
            calorie: '0',
            has_calorie: false,
            source: 'animal',
          })
        }
      }
    }

    // 按置信度排序
    allItems.sort((a, b) => {
      const pa = parseFloat(a.probability) || 0
      const pb = parseFloat(b.probability) || 0
      return pb - pa
    })

    return {
      items: allItems,
      source: 'baidu-combo',
      log_id: comboResult.log_id != null ? String(comboResult.log_id) : undefined,
    }
  }

  /**
   * 生成多种预处理变体的图片
   * @param {string} base64Str
   * @returns {Promise<Array<{name: string, base64: string}>>}
   */
  async _preprocessVariants(base64Str) {
    const imageBuf = Buffer.from(base64Str, 'base64')
    const variants = []

    try {
      // 原图（尺寸归一化到 1024px）
      const original = sharp(imageBuf)
      const meta = await original.metadata()
      const maxDim = Math.max(meta.width, meta.height)
      const scale = maxDim > 1024 ? 1024 / maxDim : 1
      const resizedBuf = maxDim > 1024
        ? await original.resize(1024, null, { fit: 'inside' }).jpeg({ quality: 85 }).toBuffer()
        : await original.jpeg({ quality: 85 }).toBuffer()

      variants.push({
        name: 'original',
        base64: resizedBuf.toString('base64'),
      })

      // 变体1：增强对比度 + 锐化
      const enhancedBuf = await sharp(resizedBuf)
        .modulate({ brightness: 1.05, saturation: 1.1 })
        .sharpen({ sigma: 1.2, m1: 1, m2: 0.5 })
        .jpeg({ quality: 85 })
        .toBuffer()
      variants.push({
        name: 'enhanced',
        base64: enhancedBuf.toString('base64'),
      })

      // 变体2：ROI中心裁剪（四周裁15%）
      const w = meta.width > 1024 ? 1024 : meta.width
      const h = meta.height > 1024 ? Math.round(meta.height * scale) : meta.height
      const roiW = Math.round(w * 0.7)
      const roiH = Math.round(h * 0.7)
      const roiLeft = Math.round((w - roiW) / 2)
      const roiTop = Math.round((h - roiH) / 2)
      const roiBuf = await sharp(resizedBuf)
        .extract({ left: roiLeft, top: roiTop, width: roiW, height: roiH })
        .jpeg({ quality: 85 })
        .toBuffer()
      variants.push({
        name: 'roi',
        base64: roiBuf.toString('base64'),
      })

      // 变体3：强对比度增强（针对光照不足的图片）
      const strongBuf = await sharp(resizedBuf)
        .modulate({ brightness: 1.1, saturation: 1.2, lightness: 1.05 })
        .linear(1.3, -10) // 对比度增强
        .sharpen({ sigma: 1.5, m1: 1.5, m2: 0.8 })
        .jpeg({ quality: 85 })
        .toBuffer()
      variants.push({
        name: 'strong-enhance',
        base64: strongBuf.toString('base64'),
      })
    } catch (e) {
      console.warn('[BaiduClient] 图像预处理部分失败:', e.message)
      // 至少保证原图变体存在
      if (variants.length === 0) {
        variants.push({ name: 'original', base64: base64Str })
      }
    }

    return variants
  }

  /**
   * 合并去重并按置信度排序
   * 同一种食物在多个变体中出现，取最高置信度
   * @param {Array} items
   * @returns {Array}
   */
  _mergeAndSortItems(items) {
    const map = new Map()
    for (const item of items) {
      const key = item.name.toLowerCase().trim()
      if (!map.has(key) || item.probability > map.get(key).probability) {
        map.set(key, { ...item })
      }
    }
    const merged = Array.from(map.values())
    merged.sort((a, b) => b.probability - a.probability)
    return merged
  }
}
