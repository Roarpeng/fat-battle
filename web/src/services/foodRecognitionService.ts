export interface FoodRecognitionItem {
  name: string
  cal: number
  confidence: number
  portion?: 'small' | 'medium' | 'large'
  actualCal?: number
}

export interface FoodRecognitionResult {
  items: FoodRecognitionItem[]
  totalCal: number
  suggestions: { type: 'good' | 'warning' | 'info'; text: string }[]
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

export class FoodRecognitionService {
  private status: RecognitionStatus = 'idle'
  private onStatusChange?: (status: RecognitionStatus) => void

  constructor(options: { onStatusChange?: (status: RecognitionStatus) => void } = {}) {
    this.onStatusChange = options.onStatusChange
  }

  private setStatus(status: RecognitionStatus) {
    this.status = status
    this.onStatusChange?.(status)
  }

  async recognizeFromImage(imageFile: File): Promise<FoodRecognitionResult> {
    this.setStatus('loading')

    try {
      await new Promise(resolve => setTimeout(resolve, 1500))

      const numItems = Math.floor(Math.random() * 3) + 1
      const shuffled = [...MOCK_FOODS].sort(() => Math.random() - 0.5)
      const items: FoodRecognitionItem[] = shuffled.slice(0, numItems).map(food => ({
        name: food.name,
        cal: food.cal,
        confidence: Math.random() * 0.3 + 0.7,
        portion: 'medium',
        actualCal: food.cal,
      }))

      const totalCal = items.reduce((sum, item) => sum + item.cal, 0)
      const suggestions = this.generateSuggestions(items, totalCal)

      const result = { items, totalCal, suggestions }
      this.setStatus('success')
      return result
    } catch (error) {
      this.setStatus('error')
      throw error
    }
  }

  async recognizeFromBarcode(barcode: string): Promise<FoodRecognitionItem | null> {
    this.setStatus('loading')

    try {
      await new Promise(resolve => setTimeout(resolve, 800))

      const hash = barcode.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0)
      const index = hash % MOCK_FOODS.length
      const food = MOCK_FOODS[index]

      const result = {
        name: food.name,
        cal: food.cal,
        confidence: 0.95,
        portion: 'medium' as const,
        actualCal: food.cal,
      }

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
