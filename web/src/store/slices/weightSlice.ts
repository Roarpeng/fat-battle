import type { WeightRecord } from '../../core/weight'
import { addWeightRecord as addRecord } from '../../core/weight'
import { getTodayStr } from '../game-types'

export interface WeightSlice {
  weightRecords: WeightRecord[]
  addWeightRecord: (weightKg: number, note?: string) => void
  removeWeightRecord: (date: string) => void
  getLatestWeight: () => number | null
  clearWeightRecords: () => void
}

export const createWeightSlice = (set: any, get: any, _api?: any): WeightSlice => ({
  weightRecords: [],

  addWeightRecord: (weightKg, note) =>
    set((state: any) => {
      const newRecord: WeightRecord = {
        date: getTodayStr(),
        weightKg,
        note,
      }
      const updatedRecords = addRecord(state.weightRecords, newRecord)
      return { weightRecords: updatedRecords }
    }),

  removeWeightRecord: (date) =>
    set((state: any) => ({
      weightRecords: state.weightRecords.filter((r: WeightRecord) => r.date !== date),
    })),

  getLatestWeight: () => {
    const records = get().weightRecords
    if (records.length === 0) return null
    const sorted = [...records].sort(
      (a: WeightRecord, b: WeightRecord) => new Date(b.date).getTime() - new Date(a.date).getTime()
    )
    return sorted[0].weightKg
  },

  clearWeightRecords: () =>
    set(() => ({
      weightRecords: [],
    })),
})
