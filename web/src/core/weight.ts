export interface WeightRecord {
  date: string
  weightKg: number
  note?: string
}

export interface WeightTrend {
  currentWeight: number
  startWeight: number
  targetWeight: number
  totalChange: number
  weeklyChange: number
  daysToTarget: number
  progressPercent: number
  trend: 'increasing' | 'decreasing' | 'stable'
}

function parseDate(dateStr: string): number {
  return new Date(dateStr).getTime()
}

function sortRecordsByDate(records: WeightRecord[]): WeightRecord[] {
  return [...records].sort((a, b) => parseDate(a.date) - parseDate(b.date))
}

function calculateDaysBetween(startDate: string, endDate: string): number {
  const start = parseDate(startDate)
  const end = parseDate(endDate)
  const diffMs = end - start
  return Math.max(1, Math.round(diffMs / (1000 * 60 * 60 * 24)))
}

export function detectTrend(records: WeightRecord[]): 'increasing' | 'decreasing' | 'stable' {
  if (records.length < 2) return 'stable'

  const sorted = sortRecordsByDate(records)
  const recentRecords = sorted.slice(-Math.min(7, sorted.length))

  if (recentRecords.length < 2) return 'stable'

  const firstWeight = recentRecords[0].weightKg
  const lastWeight = recentRecords[recentRecords.length - 1].weightKg
  const diff = lastWeight - firstWeight

  const threshold = 0.5

  if (diff > threshold) return 'increasing'
  if (diff < -threshold) return 'decreasing'
  return 'stable'
}

export function estimateDaysToTarget(
  currentWeight: number,
  targetWeight: number,
  weeklyChangeRate: number
): number {
  const weightDiff = currentWeight - targetWeight

  if (weightDiff <= 0) return 0
  if (weeklyChangeRate <= 0) return Infinity

  const weeksNeeded = weightDiff / weeklyChangeRate
  return Math.ceil(weeksNeeded * 7)
}

export function calculateProgress(
  startWeight: number,
  currentWeight: number,
  targetWeight: number
): number {
  const totalToLose = startWeight - targetWeight
  const alreadyLost = startWeight - currentWeight

  if (totalToLose <= 0) return 100
  if (alreadyLost <= 0) return 0

  const progress = (alreadyLost / totalToLose) * 100
  return Math.min(100, Math.max(0, Math.round(progress * 10) / 10))
}

export function addWeightRecord(
  records: WeightRecord[],
  newRecord: WeightRecord
): WeightRecord[] {
  const existingIndex = records.findIndex((r) => r.date === newRecord.date)

  if (existingIndex >= 0) {
    const updated = [...records]
    updated[existingIndex] = { ...newRecord }
    return sortRecordsByDate(updated)
  }

  return sortRecordsByDate([...records, { ...newRecord }])
}

export function analyzeWeightTrend(
  records: WeightRecord[],
  targetWeight: number
): WeightTrend | null {
  if (records.length === 0) return null

  const sorted = sortRecordsByDate(records)
  const startWeight = sorted[0].weightKg
  const currentWeight = sorted[sorted.length - 1].weightKg
  const totalChange = currentWeight - startWeight

  const daysSpan = calculateDaysBetween(sorted[0].date, sorted[sorted.length - 1].date)
  const weeklyChange = (totalChange / daysSpan) * 7

  const weeklyLossRate = weeklyChange < 0 ? Math.abs(weeklyChange) : 0
  const daysToTarget = estimateDaysToTarget(currentWeight, targetWeight, weeklyLossRate)

  const progressPercent = calculateProgress(startWeight, currentWeight, targetWeight)
  const trend = detectTrend(records)

  return {
    currentWeight,
    startWeight,
    targetWeight,
    totalChange: Math.round(totalChange * 100) / 100,
    weeklyChange: Math.round(weeklyChange * 100) / 100,
    daysToTarget,
    progressPercent,
    trend,
  }
}
