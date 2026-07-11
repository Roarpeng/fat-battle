import type { Item } from '../game-types'
import { ITEMS_DEF } from '../game-types'

export interface InventorySlice {
  coins: number
  items: Item[]
  addCoins: (amount: number) => void
  spendCoins: (amount: number) => boolean
  useItem: (itemId: string) => boolean
}

export const createInventorySlice = (set: any, get: any, _api?: any): InventorySlice => ({
  coins: 0,
  items: ITEMS_DEF.map((i) => ({ ...i, quantity: 0 })),

  addCoins: (amount) => set((state: any) => ({ coins: state.coins + amount })),

  spendCoins: (amount) => {
    const state = get()
    if (state.coins < amount) return false
    set({ coins: state.coins - amount })
    return true
  },

  useItem: (itemId) => {
    const state = get()
    const item = state.items.find((i: Item) => i.id === itemId)
    if (!item || item.quantity <= 0) return false

    const newItems = state.items.map((i: Item) =>
      i.id === itemId ? { ...i, quantity: i.quantity - 1 } : i
    )
    set({ items: newItems })
    return true
  },
})
