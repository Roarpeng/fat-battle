// GLM-4.6V-Flash API 客户端 - 后端专用，不暴露到前端
// 纯 JS 版本，供 server.js 直接 import（无需编译）。
// 文档：https://docs.bigmodel.cn/cn/guide/models/free/glm-4.6v-flash

const DEFAULT_BASE_URL = 'https://open.bigmodel.cn/api/paas/v4'
const DEFAULT_MODEL = 'glm-4.6v-flash'

/**
 * GLM-4.6V-Flash 多模态大模型客户端
 *
 * 封装食物识别接口，支持通过后端代理调用，API Key 不暴露到前端。
 * GLM-4.6V-Flash 为免费模型，原生支持 Function Call 与 thinking 深度思考模式。
 */
export class GlmClient {
  /**
   * @param {object} [options]
   * @param {string} [options.apiKey]      智谱开放平台 API Key（必填）
   * @param {string} [options.baseUrl]     API 端点
   * @param {string} [options.model]       模型名
   * @param {boolean} [options.thinking]   是否开启深度思考模式（默认 false，食物识别追求低延迟）
   */
  constructor(options = {}) {
    this.apiKey = options.apiKey ?? process.env.ZHIPU_API_KEY ?? ''
    this.baseUrl = options.baseUrl ?? process.env.GLM_BASE_URL ?? DEFAULT_BASE_URL
    this.model = options.model ?? process.env.GLM_MODEL ?? DEFAULT_MODEL
    this.thinking = options.thinking ?? false
  }

  /** 健康检查 - 配置是否就绪 */
  isConfigured() {
    return Boolean(this.apiKey) && this.apiKey.length > 0
  }

  /**
   * 从文本中提取 JSON
   * @param {string} text
   * @returns {any | null}
   */
  _extractJsonFromText(text) {
    if (!text) return null

    // 优先匹配 ```json ... ``` 代码块
    const jsonMatch = text.match(/```(?:json)?\s*([\s\S]*?)\s*```/)
    if (jsonMatch) {
      try {
        return JSON.parse(jsonMatch[1].trim())
      } catch (_) {}
    }

    // 退而求其次：匹配首个 {...} 块
    const braceMatch = text.match(/\{[\s\S]*\}/)
    if (braceMatch) {
      try {
        return JSON.parse(braceMatch[0])
      } catch (_) {}
    }

    return null
  }

  /**
   * 食物识别
   * @param {string} imageBase64 图片 base64（可带或不带 data URL 头）
   * @param {object} [options]
   * @param {number}  [options.topNum]    返回候选数量，默认 5
   * @param {boolean} [options.thinking]  覆盖实例级 thinking 配置
   * @returns {Promise<{success: boolean, items: Array<{name: string, calorie: number, confidence: number, has_calorie: boolean, description?: string}>, model: string, usage?: object}>}
   */
  async recognizeFood(imageBase64, options = {}) {
    if (!this.isConfigured()) {
      throw new Error('GLM API Key 未配置（ZHIPU_API_KEY）')
    }

    const topNum = options.topNum ?? 5
    const useThinking = options.thinking ?? this.thinking

    // 规范化 base64 → data URL（GLM 接受 data:image/jpeg;base64,... 内联格式）
    const pureBase64 = imageBase64.replace(/^data:image\/[a-zA-Z]+;base64,/, '')
    const imageDataUrl = `data:image/jpeg;base64,${pureBase64}`

    const systemPrompt = `你是一位专业的营养师和食物识别专家，拥有丰富的食物营养数据库知识。
你的任务是：
1. 准确识别图片中的所有食物
2. 给出每种食物每100克的热量（千卡）
3. 评估识别的置信度

卡路里数据参考标准（每100克）：
- 主食类：米饭116、馒头223、面条109、面包312、饺子253
- 蔬菜类：番茄20、黄瓜16、白菜17、菠菜28、西兰花36
- 肉类：猪肉395、牛肉125、鸡肉167、鱼肉113、鸡蛋144
- 水果类：苹果52、香蕉93、橙子47、葡萄44、西瓜25
- 零食类：薯片547、巧克力586、饼干435、蛋糕347
- 饮品类：牛奶54、豆浆31、可乐43、果汁45
- 快餐类：汉堡292、薯条312、披萨266、炸鸡290

置信度判定标准：
- 0.9-1.0：非常清晰，完全确定
- 0.7-0.89：比较清晰，基本确定
- 0.5-0.69：部分遮挡或距离较远，有一定不确定
- 0.3-0.49：模糊或很小，不确定
- <0.3：猜测`

    const userPrompt = `请仔细识别图片中的所有食物，并以JSON格式返回结果。

识别要求：
1. 识别图片中所有可见的食物（菜品、水果、零食、饮料、主食、肉类、蔬菜等）
2. 即使食物只露出一部分也要识别
3. 同一种食物出现多次只返回一次
4. 优先识别体积最大、最清晰的食物
5. 如果不是食物（如餐具、手、桌面等），不要识别为食物

对每种食物，返回：
- name: 食物名称（中文，简洁准确，如"白米饭"而不是"饭"）
- calorie: 每100克的热量（千卡，kcal），参考上面的标准值，不要太离谱
- confidence: 识别置信度（0-1之间的数字，精确到小数点后两位）
- has_calorie: 是否有卡路里数据（布尔值）
- category: 食物类别（主食/蔬菜/水果/肉类/蛋奶/零食/饮品/快餐/其他）
- description: 简短描述（20字以内，如"清蒸，分量适中"）

其他要求：
- 按置信度从高到低排序
- 最多返回${topNum}个结果
- 只返回食物，不要返回非食物物品
- 如果图片中完全没有食物，返回空数组

请直接返回JSON格式，不要有其他解释文字，格式如下：
\`\`\`json
{
  "items": [
    {
      "name": "白米饭",
      "calorie": 116,
      "confidence": 0.95,
      "has_calorie": true,
      "category": "主食",
      "description": "一碗白米饭，分量适中"
    }
  ]
}
\`\`\``

    const payload = {
      model: this.model,
      messages: [
        {
          role: 'system',
          content: systemPrompt,
        },
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: userPrompt,
            },
            {
              type: 'image_url',
              image_url: {
                url: imageDataUrl,
              },
            },
          ],
        },
      ],
      temperature: 0.3,
      max_tokens: 2048,
    }

    // 可选开启 thinking 深度思考模式（默认关闭以降低延迟）
    if (useThinking) {
      payload.thinking = { type: 'enabled' }
    }

    const resp = await fetch(`${this.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify(payload),
    })

    if (!resp.ok) {
      const errorText = await resp.text()
      throw new Error(`GLM API 错误：HTTP ${resp.status} - ${errorText}`)
    }

    const data = await resp.json()

    if (!data.choices || data.choices.length === 0) {
      throw new Error('GLM API 返回空结果')
    }

    const content = data.choices[0].message?.content ?? ''
    const parsed = this._extractJsonFromText(content)

    let items = []
    if (parsed && Array.isArray(parsed.items)) {
      items = parsed.items
        .map((item) => ({
          name: String(item.name ?? ''),
          calorie: Number(item.calorie ?? 0),
          confidence: Number(item.confidence ?? 0),
          has_calorie: Boolean(item.has_calorie ?? (item.calorie > 0)),
          category: item.category ? String(item.category) : undefined,
          description: item.description ? String(item.description) : undefined,
        }))
        .filter((item) => item.name.trim().length > 0 && item.confidence >= 0.3)
        .sort((a, b) => b.confidence - a.confidence)
        .slice(0, topNum)
    }

    return {
      success: true,
      items,
      model: this.model,
      usage: data.usage,
    }
  }

  /**
   * 文本搜索食物（纯文本模型）
   * @param {string} query
   * @param {object} [options]
   * @param {number} [options.topNum]
   */
  async searchFoodByText(query, options = {}) {
    if (!this.isConfigured()) {
      throw new Error('GLM API Key 未配置（ZHIPU_API_KEY）')
    }
    const q = String(query ?? '').trim()
    if (!q) {
      return { success: true, items: [], model: process.env.GLM_TEXT_MODEL || 'glm-4-flash' }
    }

    const topNum = options.topNum ?? 5
    const textModel = process.env.GLM_TEXT_MODEL || 'glm-4-flash'

    const systemPrompt = `你是一个食物搜索引擎。用户输入关键词，你必须搜索并返回最匹配的食物。
规则：
1. 只输出JSON，禁止输出任何其他文字、解释、markdown标记
2. 将用户输入视为食物搜索关键词
3. 错别字自动纠正
4. 无法匹配时返回 {"items": []}
JSON格式：
{"items":[{"name":"食物中文名","calorie":每100克卡路里数值,"confidence":0到1,"category":"主食/蔬菜/水果/肉类/蛋奶/零食/饮品/快餐/其他","description":"简短描述"}]}
最多返回${topNum}个结果。`

    const payload = {
      model: textModel,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: `搜索：${q}` },
      ],
      temperature: 0.1,
      max_tokens: 1024,
    }

    const resp = await fetch(`${this.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify(payload),
    })

    if (!resp.ok) {
      const errorText = await resp.text()
      throw new Error(`GLM 搜索 API 错误：HTTP ${resp.status} - ${errorText}`)
    }

    const data = await resp.json()
    const content = data.choices?.[0]?.message?.content ?? ''
    const parsed = this._extractJsonFromText(content)

    let items = []
    if (parsed && Array.isArray(parsed.items)) {
      items = parsed.items
        .map((item) => ({
          name: String(item.name ?? ''),
          calorie: Number(item.calorie ?? 0),
          confidence: Number(item.confidence ?? 0.7),
          has_calorie: Boolean(item.has_calorie ?? (item.calorie > 0)),
          category: item.category ? String(item.category) : undefined,
          description: item.description ? String(item.description) : undefined,
        }))
        .filter((item) => item.name.trim().length > 0 && item.confidence >= 0.3)
        .slice(0, topNum)
    }

    return {
      success: true,
      items,
      model: textModel,
      usage: data.usage,
    }
  }
}
