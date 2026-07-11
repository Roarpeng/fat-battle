import type { UserInfo, Difficulty } from '../game-types'
import { calculateBmi } from '../game-types'

export interface UserSlice {
  user: UserInfo
  setUser: (user: Partial<UserInfo>) => void
  updateWeight: (weight: number) => void
  setDifficulty: (difficulty: Difficulty) => void
}

export const initialUser: UserInfo = {
  height: 170,
  weight: 70,
  targetWeight: 60,
  bmi: calculateBmi(70, 170),
  difficulty: 'normal',
  role: '战士',
  gender: 'male',
}

export const createUserSlice = (set: any, get: any, _api?: any): UserSlice => ({
  user: initialUser,

  setUser: (user) =>
    set((state: any) => ({
      user: {
        ...state.user,
        ...user,
        bmi: calculateBmi(user.weight ?? state.user.weight, user.height ?? state.user.height),
      },
    })),

  updateWeight: (weight) =>
    set((state: any) => {
      const bmi = calculateBmi(weight, state.user.height)
      return { user: { ...state.user, weight, bmi } }
    }),

  setDifficulty: (difficulty) =>
    set((state: any) => ({ user: { ...state.user, difficulty } })),
})
