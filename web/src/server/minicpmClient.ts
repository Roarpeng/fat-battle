export interface MiniCPMFoodItem {
  name: string
  calorie: number
  confidence: number
  has_calorie: boolean
  description?: string
}

export interface MiniCPMResponse {
  success: boolean
  items: MiniCPMFoodItem[]
  model: string
  usage?: {
    prompt_tokens: number
    completion_tokens: number
    total_tokens: number
  }
}

export interface MiniCPMClientOptions {
  apiKey?: string
  baseUrl?: string
  model?: string
}

const DEFAULT_BASE_URL = 'https://api.modelbest.co/v1'
const DEFAULT_MODEL = 'MiniCPM-V-4.6-Instruct'
const DEFAULT_API_KEY = 'lis_sk_298cf78155f231c7_DkrDcNLHnK8dJRnfFrJCd4JGDbBLMkHrC3T-wLpvC9zy0BPemsyFuQ'

export class MiniCPMClient {
  private apiKey: string
  private baseUrl: string
  private model: string

  constructor(options?: MiniCPMClientOptions) {
    this.apiKey = options?.apiKey ?? process.env.MINICPM_API_KEY ?? DEFAULT_API_KEY
    this.baseUrl = options?.baseUrl ?? process.env.MINICPM_BASE_URL ?? DEFAULT_BASE_URL
    this.model = options?.model ?? process.env.MINICPM_MODEL ?? DEFAULT_MODEL
  }

  isConfigured(): boolean {
    return this.apiKey.length > 0
  }

  private extractJsonFromText(text: string): any | null {
    const jsonMatch = text.match(/```(?:json)?\s*([\s\S]*?)\s*```/)
    if (jsonMatch) {
      try {
        return JSON.parse(jsonMatch[1].trim())
      } catch (_) {}
    }

    const braceMatch = text.match(/\{[\s\S]*\}/)
    if (braceMatch) {
      try {
        return JSON.parse(braceMatch[0])
      } catch (_) {}
    }

    return null
  }

  async recognizeFood(
    imageBase64: string,
    options?: { topNum?: number },
  ): Promise<MiniCPMResponse> {
    const topNum = options?.topNum ?? 5

    const pureBase64 = imageBase64.replace(/^data:image\/[a-zA-Z]+;base64,/, '')
    const imageDataUrl = `data:image/jpeg;base64,${pureBase64}`

    const systemPrompt = `你是一位专业的营养师和食物识别专家。请仔细识别图片中的食物。`

    const userPrompt = `请识别图片中的食物，并以JSON格式返回结果。

要求：
1. 识别图片中所有可见的食物
2. 对每种食物，返回：
   - name: 食物名称（中文）
   - calorie: 每100克的热量（千卡，kcal），如果不确定请估算
   - confidence: 识别置信度（0-1之间的数字）
   - has_calorie: 是否有卡路里数据（布尔值）
   - description: 简短描述（可选）
3. 按置信度从高到低排序
4. 最多返回${topNum}个结果
5. 如果图片中没有食物，返回空数组

请直接返回JSON格式，不要有其他解释文字，格式如下：
\`\`\`json
{
  "items": [
    {
      "name": "食物名称",
      "calorie": 100,
      "confidence": 0.95,
      "has_calorie": true,
      "description": "食物描述"
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
      throw new Error(`MiniCPM-V API 错误：HTTP ${resp.status} - ${errorText}`)
    }

    const data = await resp.json() as {
      choices: Array<{
        message: {
          content: string
        }
        finish_reason: string
      }>
      usage?: {
        prompt_tokens: number
        completion_tokens: number
        total_tokens: number
      }
    }

    if (!data.choices || data.choices.length === 0) {
      throw new Error('MiniCPM-V API 返回空结果')
    }

    const content = data.choices[0].message.content
    const parsed = this.extractJsonFromText(content)

    let items: MiniCPMFoodItem[] = []
    if (parsed && Array.isArray(parsed.items)) {
      items = parsed.items
        .map((item: any) => ({
          name: String(item.name ?? ''),
          calorie: Number(item.calorie ?? 0),
          confidence: Number(item.confidence ?? 0),
          has_calorie: Boolean(item.has_calorie ?? (item.calorie > 0)),
          description: item.description ? String(item.description) : undefined,
        }))
        .filter((item: MiniCPMFoodItem) => item.name.trim().length > 0)
        .sort((a: MiniCPMFoodItem, b: MiniCPMFoodItem) => b.confidence - a.confidence)
        .slice(0, topNum)
    }

    return {
      success: true,
      items,
      model: this.model,
      usage: data.usage,
    }
  }
}
