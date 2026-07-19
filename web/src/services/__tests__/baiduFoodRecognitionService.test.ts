import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import {
  recognizeByBaidu,
  fileToBase64,
  type BaiduDishItem,
} from '../baiduFoodRecognitionService'
import { NetworkError } from '../retry'

/** 构造一个 mock Response，支持 .ok/.status/.statusText/.json() */
function makeResponse(body: unknown, init: { ok?: boolean; status?: number; statusText?: string } = {}) {
  const ok = init.ok ?? true
  const status = init.status ?? (ok ? 200 : 500)
  const statusText = init.statusText ?? (ok ? 'OK' : 'Internal Server Error')
  return {
    ok,
    status,
    statusText,
    json: async () => body,
  } as Response
}

describe('baiduFoodRecognitionService', () => {
  let mockFetch: ReturnType<typeof vi.fn>

  beforeEach(() => {
    mockFetch = vi.fn()
    vi.stubGlobal('fetch', mockFetch)
  })

  afterEach(() => {
    vi.unstubAllGlobals()
    vi.restoreAllMocks()
  })

  describe('recognizeByBaidu - 正常响应', () => {
    it('应正确归一化 3 个菜品（2 个有卡路里，1 个无）', async () => {
      const items: BaiduDishItem[] = [
        { name: '宫保鸡丁', calorie: '320', probability: '0.95', has_calorie: true },
        { name: '麻婆豆腐', calorie: '280', probability: '0.85', has_calorie: true },
        { name: '未知菜品', calorie: '0', probability: '0.5', has_calorie: false },
      ]
      mockFetch.mockResolvedValueOnce(
        makeResponse({ success: true, items, source: 'baidu', log_id: 'test-log-1' })
      )

      const result = await recognizeByBaidu('base64data')

      expect(mockFetch).toHaveBeenCalledTimes(1)
      expect(result.source).toBe('online')
      // has_calorie=false 被过滤
      expect(result.items).toHaveLength(2)
      expect(result.items[0].name).toBe('宫保鸡丁')
      expect(result.items[1].name).toBe('麻婆豆腐')
      // confidence 映射
      expect(result.items[0].confidence).toBeCloseTo(0.95, 5)
      expect(result.items[1].confidence).toBeCloseTo(0.85, 5)
      // cal 为每100g卡路里数值
      expect(result.items[0].cal).toBe(320)
      expect(result.items[1].cal).toBe(280)
      // 默认 portion=medium, actualCal=cal
      expect(result.items[0].portion).toBe('medium')
      expect(result.items[0].actualCal).toBe(320)
      // source 标注
      expect(result.items[0].source).toBe('online')
      expect(result.items[1].source).toBe('online')
      // totalCal 求和
      expect(result.totalCal).toBe(600)
      // 请求体
      const callArgs = mockFetch.mock.calls[0]
      expect(callArgs[0]).toBe('/api/food-recognize')
      const fetchOpts = callArgs[1] as RequestInit
      expect(fetchOpts.method).toBe('POST')
      const bodyObj = JSON.parse(fetchOpts.body as string)
      expect(bodyObj.image).toBe('base64data')
      expect(bodyObj.topNum).toBe(5)
      expect(bodyObj.filterThreshold).toBe(0.8)
    })

    it('应按 probability 降序排序', async () => {
      // 后端返回顺序与 probability 高低不一致
      const items: BaiduDishItem[] = [
        { name: '低概率菜', calorie: '100', probability: '0.6', has_calorie: true },
        { name: '高概率菜', calorie: '200', probability: '0.95', has_calorie: true },
        { name: '中概率菜', calorie: '150', probability: '0.8', has_calorie: true },
      ]
      mockFetch.mockResolvedValueOnce(makeResponse({ success: true, items, source: 'baidu' }))

      const result = await recognizeByBaidu('base64')

      expect(result.items.map(i => i.name)).toEqual(['高概率菜', '中概率菜', '低概率菜'])
      // 验证严格降序
      expect(result.items[0].confidence).toBeGreaterThanOrEqual(result.items[1].confidence)
      expect(result.items[1].confidence).toBeGreaterThanOrEqual(result.items[2].confidence)
    })

    it('应正确生成 suggestions', async () => {
      const items: BaiduDishItem[] = [
        { name: '宫保鸡丁', calorie: '320', probability: '0.95', has_calorie: true },
        { name: '米饭', calorie: '230', probability: '0.85', has_calorie: true },
        { name: '蔬菜沙拉', calorie: '150', probability: '0.7', has_calorie: true },
      ]
      mockFetch.mockResolvedValueOnce(makeResponse({ success: true, items, source: 'baidu' }))

      const result = await recognizeByBaidu('base64')

      // 总热量 700 > 600，应包含热量偏高提示
      const warning = result.suggestions.find(s => s.type === 'warning' && s.text.includes('热量偏高'))
      expect(warning).toBeDefined()
      // 包含蛋白质提示
      const protein = result.suggestions.find(s => s.text.includes('蛋白质'))
      expect(protein).toBeDefined()
      // 包含蔬菜提示
      const vegetable = result.suggestions.find(s => s.text.includes('蔬菜'))
      expect(vegetable).toBeDefined()
      // 营养均衡提示（同时有主食+蛋白质+蔬菜）
      const balanced = result.suggestions.find(s => s.text.includes('营养搭配很均衡'))
      expect(balanced).toBeDefined()
    })
  })

  describe('recognizeByBaidu - has_calorie 过滤', () => {
    it('应过滤所有 has_calorie=false 的项', async () => {
      const items: BaiduDishItem[] = [
        { name: '宫保鸡丁', calorie: '320', probability: '0.95', has_calorie: true },
        { name: '未知1', calorie: '0', probability: '0.8', has_calorie: false },
        { name: '未知2', calorie: '0', probability: '0.7', has_calorie: false },
      ]
      mockFetch.mockResolvedValueOnce(makeResponse({ success: true, items, source: 'baidu' }))

      const result = await recognizeByBaidu('base64')

      expect(result.items).toHaveLength(1)
      expect(result.items[0].name).toBe('宫保鸡丁')
    })

    it('全部无卡路里时返回低置信度默认项', async () => {
      const items: BaiduDishItem[] = [
        { name: '神秘菜1', calorie: '0', probability: '0.8', has_calorie: false },
        { name: '神秘菜2', calorie: '0', probability: '0.7', has_calorie: false },
      ]
      mockFetch.mockResolvedValueOnce(makeResponse({ success: true, items, source: 'baidu' }))

      const result = await recognizeByBaidu('base64')

      // 返回 1 个低置信度默认项
      expect(result.items).toHaveLength(1)
      expect(result.items[0].name).toBe('神秘菜1')
      expect(result.items[0].cal).toBe(200)
      expect(result.items[0].confidence).toBeLessThan(0.5)
      expect(result.items[0].confidence).toBeGreaterThan(0)
      expect(result.items[0].portion).toBe('medium')
      expect(result.items[0].actualCal).toBe(200)
      expect(result.items[0].source).toBe('online')
    })
  })

  describe('recognizeByBaidu - 空结果', () => {
    it('items 为空数组时返回空结果', async () => {
      mockFetch.mockResolvedValueOnce(makeResponse({ success: true, items: [], source: 'baidu' }))

      const result = await recognizeByBaidu('base64')

      expect(result.items).toEqual([])
      expect(result.totalCal).toBe(0)
      expect(result.source).toBe('online')
    })

    it('items 为 undefined 时返回空结果', async () => {
      mockFetch.mockResolvedValueOnce(makeResponse({ success: true, source: 'baidu' }))

      const result = await recognizeByBaidu('base64')

      expect(result.items).toEqual([])
      expect(result.totalCal).toBe(0)
    })
  })

  describe('recognizeByBaidu - confidence 映射', () => {
    it('probability 字符串正确转换为数字', async () => {
      const items: BaiduDishItem[] = [
        { name: 'A', calorie: '100', probability: '0.123', has_calorie: true },
        { name: 'B', calorie: '200', probability: '0.987', has_calorie: true },
      ]
      mockFetch.mockResolvedValueOnce(makeResponse({ success: true, items, source: 'baidu' }))

      const result = await recognizeByBaidu('base64')

      const a = result.items.find(i => i.name === 'A')!
      const b = result.items.find(i => i.name === 'B')!
      expect(a.confidence).toBeCloseTo(0.123, 5)
      expect(b.confidence).toBeCloseTo(0.987, 5)
    })

    it('probability 非法时 confidence 为 0', async () => {
      const items: BaiduDishItem[] = [
        { name: 'A', calorie: '100', probability: 'abc', has_calorie: true },
      ]
      mockFetch.mockResolvedValueOnce(makeResponse({ success: true, items, source: 'baidu' }))

      const result = await recognizeByBaidu('base64')

      expect(result.items[0].confidence).toBe(0)
    })
  })

  describe('recognizeByBaidu - calorie 处理', () => {
    it('calorie 为浮点数时四舍五入为整数', async () => {
      const items: BaiduDishItem[] = [
        { name: 'A', calorie: '123.4', probability: '0.9', has_calorie: true },
        { name: 'B', calorie: '567.8', probability: '0.8', has_calorie: true },
      ]
      mockFetch.mockResolvedValueOnce(makeResponse({ success: true, items, source: 'baidu' }))

      const result = await recognizeByBaidu('base64')

      expect(result.items[0].cal).toBe(123)
      expect(result.items[1].cal).toBe(568)
    })

    it('calorie 非法或非正时回退默认值', async () => {
      const items: BaiduDishItem[] = [
        { name: 'A', calorie: 'abc', probability: '0.9', has_calorie: true },
        { name: 'B', calorie: '0', probability: '0.8', has_calorie: true },
        { name: 'C', calorie: '-50', probability: '0.7', has_calorie: true },
      ]
      mockFetch.mockResolvedValueOnce(makeResponse({ success: true, items, source: 'baidu' }))

      const result = await recognizeByBaidu('base64')

      // 全部回退到 200
      expect(result.items.every(i => i.cal === 200)).toBe(true)
    })
  })

  describe('recognizeByBaidu - 错误处理', () => {
    it('后端返回 success=false 时抛出 Error（携带 error/code）', async () => {
      mockFetch.mockResolvedValueOnce(
        makeResponse({
          success: false,
          error: 'API key 无效',
          code: 'INVALID_API_KEY',
        })
      )

      await expect(recognizeByBaidu('base64')).rejects.toThrow('API key 无效')
    })

    it('后端返回 success=false 且无 error 时使用默认消息', async () => {
      mockFetch.mockResolvedValueOnce(makeResponse({ success: false, code: 'UNKNOWN' }))

      await expect(recognizeByBaidu('base64')).rejects.toThrow(/success=false/)
    })

    it('fetch 抛出网络错误时包装为 NetworkError', async () => {
      mockFetch.mockRejectedValue(new TypeError('Failed to fetch'))

      const promise = recognizeByBaidu('base64')
      await expect(promise).rejects.toThrow(NetworkError)
      await expect(promise).rejects.toThrow(/百度识别请求失败/)
    })

    it('HTTP 非 2xx 时抛出 NetworkError', async () => {
      mockFetch.mockResolvedValue(
        makeResponse(
          { success: false, error: 'server error' },
          { ok: false, status: 500, statusText: 'Internal Server Error' }
        )
      )

      const promise = recognizeByBaidu('base64')
      await expect(promise).rejects.toThrow(NetworkError)
      await expect(promise).rejects.toThrow(/500/)
    })

    it('响应 body 非法 JSON 时抛出 NetworkError', async () => {
      const badResponse = {
        ok: true,
        status: 200,
        statusText: 'OK',
        json: async () => {
          throw new SyntaxError('Unexpected token in JSON')
        },
      } as unknown as Response
      mockFetch.mockResolvedValue(badResponse)

      const promise = recognizeByBaidu('base64')
      await expect(promise).rejects.toThrow(NetworkError)
      await expect(promise).rejects.toThrow(/响应解析失败/)
    })
  })

  describe('recognizeByBaidu - 配置透传', () => {
    it('自定义 topNum 和 filterThreshold 应透传到请求体', async () => {
      mockFetch.mockResolvedValueOnce(
        makeResponse({ success: true, items: [], source: 'baidu' })
      )

      await recognizeByBaidu('base64', { topNum: 10, filterThreshold: 0.5 })

      const callArgs = mockFetch.mock.calls[0]
      const fetchOpts = callArgs[1] as RequestInit
      const bodyObj = JSON.parse(fetchOpts.body as string)
      expect(bodyObj.topNum).toBe(10)
      expect(bodyObj.filterThreshold).toBe(0.5)
    })

    it('自定义 proxyUrl 应作为 fetch 的第一个参数', async () => {
      mockFetch.mockResolvedValueOnce(
        makeResponse({ success: true, items: [], source: 'baidu' })
      )

      await recognizeByBaidu('base64', { proxyUrl: '/custom/api/recognize' })

      const callArgs = mockFetch.mock.calls[0]
      expect(callArgs[0]).toBe('/custom/api/recognize')
    })

    it('fetchFn 优先于全局 fetch', async () => {
      const customFetch = vi.fn().mockResolvedValueOnce(
        makeResponse({ success: true, items: [], source: 'baidu' })
      )

      await recognizeByBaidu('base64', { fetchFn: customFetch })

      expect(customFetch).toHaveBeenCalledTimes(1)
      // 不应调用 stub 后的全局 fetch
      expect(mockFetch).not.toHaveBeenCalled()
    })

    it('未提供选项时使用默认值', async () => {
      mockFetch.mockResolvedValueOnce(
        makeResponse({ success: true, items: [], source: 'baidu' })
      )

      await recognizeByBaidu('base64')

      const callArgs = mockFetch.mock.calls[0]
      expect(callArgs[0]).toBe('/api/food-recognize')
      const fetchOpts = callArgs[1] as RequestInit
      const bodyObj = JSON.parse(fetchOpts.body as string)
      expect(bodyObj.topNum).toBe(5)
      expect(bodyObj.filterThreshold).toBe(0.8)
    })
  })
})

describe('fileToBase64', () => {
  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('应将 File 转换为去掉 data URL 头的 base64 字符串', async () => {
    // mock FileReader：result 必须挂在实例上（实现里读取 reader.result）
    const mockFileReader = {
      result: null as string | ArrayBuffer | null,
      onload: null as ((ev: ProgressEvent<FileReader>) => void) | null,
      onerror: null as ((ev: ProgressEvent<FileReader>) => void) | null,
      readAsDataURL: vi.fn(function (this: any, _file: File) {
        // 模拟异步读取完成：先把 result 写到实例上，再触发 onload
        this.result = 'data:image/png;base64,SGVsbG8gV29ybGQ='
        setTimeout(() => {
          if (this.onload) {
            this.onload(new ProgressEvent('load'))
          }
        }, 0)
      }),
    }
    vi.stubGlobal('FileReader', function () {
      return mockFileReader
    })

    const file = new File(['hello'], 'test.png', { type: 'image/png' })
    const base64 = await fileToBase64(file)

    expect(base64).toBe('SGVsbG8gV29ybGQ=')
    expect(base64).not.toContain('data:')
    expect(base64).not.toContain(',')

    vi.unstubAllGlobals()
  })

  it('文件读取失败时应抛错', async () => {
    const mockFileReader = {
      result: null as string | ArrayBuffer | null,
      onload: null as ((ev: ProgressEvent<FileReader>) => void) | null,
      onerror: null as ((ev: ProgressEvent<FileReader>) => void) | null,
      readAsDataURL: vi.fn(function (this: any, _file: File) {
        setTimeout(() => {
          if (this.onerror) {
            this.onerror(new ProgressEvent('error'))
          }
        }, 0)
      }),
    }
    vi.stubGlobal('FileReader', function () {
      return mockFileReader
    })

    const file = new File(['hello'], 'test.png', { type: 'image/png' })
    await expect(fileToBase64(file)).rejects.toThrow(/文件读取失败/)

    vi.unstubAllGlobals()
  })
})
