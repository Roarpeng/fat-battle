// 百度 API 客户端 - 后端专用，不暴露到前端

export interface BaiduDishItem {
  name: string
  calorie: string // 每100g的卡路里
  probability: string // 0-1
  has_calorie: boolean
  baike_info?: {
    baike_url?: string
    image_url?: string
    description?: string
  }
}

export interface BaiduDishResponse {
  log_id: number
  result_num: number
  result: BaiduDishItem[]
}

export interface BaiduClientOptions {
  apiKey?: string
  secretKey?: string
  /** token 提前刷新时间（毫秒），默认 5 分钟 */
  tokenRefreshBuffer?: number
}

export interface RecognizeDishOptions {
  topNum?: number // 默认 5
  filterThreshold?: number // 默认 0.8
  baikeNum?: number
}

const DEFAULT_TOKEN_REFRESH_BUFFER = 5 * 60 * 1000 // 5 分钟
const DEFAULT_TOP_NUM = 5
const DEFAULT_FILTER_THRESHOLD = 0.8

const TOKEN_URL = 'https://aip.baidubce.com/oauth/2.0/token'
const DISH_URL = 'https://aip.baidubce.com/rest/2.0/image-classify/v2/dish'

/**
 * 百度 AI 开放平台客户端
 *
 * 封装 access_token 的获取与缓存，以及菜品识别接口。
 * 该模块仅在后端使用，API Key 不会暴露到前端。
 */
export class BaiduClient {
  private apiKey: string
  private secretKey: string
  private tokenRefreshBuffer: number
  private tokenCache: { token: string; expiresAt: number } | null = null

  constructor(options?: BaiduClientOptions) {
    this.apiKey = options?.apiKey ?? process.env.BAIDU_API_KEY ?? ''
    this.secretKey = options?.secretKey ?? process.env.BAIDU_SECRET_KEY ?? ''
    this.tokenRefreshBuffer = options?.tokenRefreshBuffer ?? DEFAULT_TOKEN_REFRESH_BUFFER
  }

  /** 健康检查 - 配置是否就绪 */
  isConfigured(): boolean {
    return Boolean(this.apiKey && this.secretKey)
  }

  /** 清除 token 缓存（用于测试） */
  clearTokenCache(): void {
    this.tokenCache = null
  }

  /** 当前是否已持有有效 token（未过期且未到刷新窗口） */
  hasValidToken(): boolean {
    if (!this.tokenCache) return false
    return Date.now() < this.tokenCache.expiresAt - this.tokenRefreshBuffer
  }

  /** 获取 access_token（带缓存） */
  async getAccessToken(): Promise<string> {
    if (this.hasValidToken()) {
      return this.tokenCache!.token
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
    const data = (await resp.json()) as {
      access_token?: string
      expires_in?: number
      error?: string
      error_description?: string
    }

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

  /** 菜品识别 */
  async recognizeDish(
    imageBase64: string,
    options?: RecognizeDishOptions,
  ): Promise<BaiduDishResponse> {
    const topNum = options?.topNum ?? DEFAULT_TOP_NUM
    const filterThreshold = options?.filterThreshold ?? DEFAULT_FILTER_THRESHOLD

    // 去掉可能的 data URL 头
    const pureBase64 = imageBase64.replace(/^data:image\/[a-zA-Z]+;base64,/, '')

    const body = new URLSearchParams({
      image: pureBase64,
      top_num: String(topNum),
      filter_threshold: String(filterThreshold),
    })
    if (options?.baikeNum != null) {
      body.set('baike_num', String(options.baikeNum))
    }

    const doRequest = async (token: string): Promise<Response> => {
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

    const data = (await resp.json()) as BaiduDishResponse & {
      error_code?: number
      error_msg?: string
    }
    if (data.error_code != null) {
      throw new Error(`百度菜品识别失败：${data.error_code} - ${data.error_msg ?? ''}`)
    }
    return data
  }
}
