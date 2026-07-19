import { describe, it, expect, beforeEach } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import { useGameStore } from '../useGameStore'
import {
  useUser,
  useUserWeight,
  useUserDifficulty,
  useMonster,
  useMonsterHp,
  useMonsterPhase,
  useMonsterShield,
  useDaily,
  useDailyIntake,
  useDailyExerciseBurn,
  useDailyDamage,
  usePendingAttack,
  useDietRecords,
  useExerciseRecords,
  usePlayerLevel,
  useCoins,
  useStreak,
  useDays,
  useCompanion,
  useAchievements,
  useDailyQuests,
  useItems,
  useSkills,
  useBattleState,
  useDailySummary,
  useGameProgress,
} from '../selectors'

describe('selector hooks', () => {
  beforeEach(() => {
    // 重置 store 到初始状态，避免 persist 持久化导致的测试间状态污染
    const { resetGame } = useGameStore.getState()
    act(() => {
      resetGame()
    })
    localStorage.clear()
  })

  describe('用户相关 selectors', () => {
    it('useUser 返回完整的 user 对象', () => {
      const { result } = renderHook(() => useUser())
      const state = useGameStore.getState()
      expect(result.current).toBe(state.user)
      expect(result.current.weight).toBe(state.user.weight)
      expect(result.current.difficulty).toBe(state.user.difficulty)
    })

    it('useUserWeight 返回 user.weight 数值', () => {
      const { result } = renderHook(() => useUserWeight())
      expect(result.current).toBe(useGameStore.getState().user.weight)
    })

    it('useUserDifficulty 返回 user.difficulty', () => {
      const { result } = renderHook(() => useUserDifficulty())
      expect(result.current).toBe(useGameStore.getState().user.difficulty)
    })

    it('useUserWeight 在 difficulty 变更时不触发重渲染（细粒度优化）', () => {
      let renderCount = 0
      renderHook(() => {
        renderCount++
        return useUserWeight()
      })
      const initialWeight = useGameStore.getState().user.weight
      const baseline = renderCount

      // 改 difficulty 不应触发 useUserWeight 重渲染（weight 数值不变）
      act(() => {
        useGameStore.getState().setDifficulty('hard')
      })
      expect(useGameStore.getState().user.difficulty).toBe('hard')
      expect(useGameStore.getState().user.weight).toBe(initialWeight)
      expect(renderCount).toBe(baseline)

      // 改 weight 应触发 useUserWeight 更新
      act(() => {
        useGameStore.getState().updateWeight(75)
      })
      expect(useGameStore.getState().user.weight).toBe(75)
      expect(renderCount).toBeGreaterThan(baseline)
    })
  })

  describe('怪物相关 selectors', () => {
    it('useMonster 返回完整的 monster 对象', () => {
      const { result } = renderHook(() => useMonster())
      const state = useGameStore.getState()
      expect(result.current).toBe(state.monster)
    })

    it('useMonsterHp 返回 monster.hp 数值', () => {
      const { result } = renderHook(() => useMonsterHp())
      expect(result.current).toBe(useGameStore.getState().monster.hp)
    })

    it('useMonsterPhase 返回 monster.phaseIndex', () => {
      const { result } = renderHook(() => useMonsterPhase())
      expect(result.current).toBe(useGameStore.getState().monster.phaseIndex)
    })

    it('useMonsterShield 返回 monster.shield', () => {
      const { result } = renderHook(() => useMonsterShield())
      expect(result.current).toBe(useGameStore.getState().monster.shield)
    })

    it('useMonsterHp 在 attackMonster 后更新', () => {
      const { result } = renderHook(() => useMonsterHp())
      const initialHp = result.current

      act(() => {
        useGameStore.getState().attackMonster(10)
      })

      expect(result.current).toBe(Math.max(0, initialHp - 10))
    })

    it('useMonsterShield 在 addMonsterShield 后更新', () => {
      const { result } = renderHook(() => useMonsterShield())
      const initialShield = result.current

      act(() => {
        // 10:1 比例：500 过量卡路里 → 50 护盾
        useGameStore.getState().addMonsterShield(500)
      })

      expect(result.current).toBe(initialShield + 50)
    })
  })

  describe('每日状态相关 selectors', () => {
    it('useDaily 返回完整的 daily 对象', () => {
      const { result } = renderHook(() => useDaily())
      expect(result.current).toBe(useGameStore.getState().daily)
    })

    it('useDailyIntake 返回 daily.intake', () => {
      const { result } = renderHook(() => useDailyIntake())
      expect(result.current).toBe(useGameStore.getState().daily.intake)
    })

    it('useDailyExerciseBurn 返回 daily.exerciseBurn', () => {
      const { result } = renderHook(() => useDailyExerciseBurn())
      expect(result.current).toBe(useGameStore.getState().daily.exerciseBurn)
    })

    it('useDailyDamage 返回 daily.damage', () => {
      const { result } = renderHook(() => useDailyDamage())
      expect(result.current).toBe(useGameStore.getState().daily.damage)
    })

    it('usePendingAttack 返回 daily.pendingAttack', () => {
      const { result } = renderHook(() => usePendingAttack())
      expect(result.current).toBe(useGameStore.getState().daily.pendingAttack)
      expect(result.current).toBeNull()

      const attack = {
        damage: 30,
        attackType: 'fireball' as const,
        isOvereat: false,
      }
      act(() => {
        useGameStore.getState().setPendingAttack(attack)
      })
      expect(result.current).toEqual(attack)
    })

    it('useDailyIntake 在 addDietRecord 后更新', () => {
      const { result } = renderHook(() => useDailyIntake())
      const initialIntake = result.current

      act(() => {
        useGameStore.getState().addDietRecord({
          name: '苹果',
          calories: 80,
          time: Date.now(),
        })
      })

      expect(result.current).toBe(initialIntake + 80)
    })

    it('useDailyExerciseBurn 在 addExerciseRecord 后更新', () => {
      const { result } = renderHook(() => useDailyExerciseBurn())
      const initialBurn = result.current

      act(() => {
        useGameStore.getState().addExerciseRecord({
          name: '跑步',
          calories: 100,
          time: Date.now(),
        })
      })

      expect(result.current).toBe(initialBurn + 100)
    })
  })

  describe('记录相关 selectors', () => {
    it('useDietRecords 返回 dietRecords 数组', () => {
      const { result } = renderHook(() => useDietRecords())
      expect(result.current).toBe(useGameStore.getState().dietRecords)
      expect(Array.isArray(result.current)).toBe(true)
    })

    it('useExerciseRecords 返回 exerciseRecords 数组', () => {
      const { result } = renderHook(() => useExerciseRecords())
      expect(result.current).toBe(useGameStore.getState().exerciseRecords)
      expect(Array.isArray(result.current)).toBe(true)
    })

    it('useDietRecords 在 addDietRecord 后更新', () => {
      const { result } = renderHook(() => useDietRecords())
      const initialLength = result.current.length

      act(() => {
        useGameStore.getState().addDietRecord({
          name: '香蕉',
          calories: 100,
          time: Date.now(),
        })
      })

      expect(result.current.length).toBe(initialLength + 1)
    })
  })

  describe('进度相关 selectors', () => {
    it('usePlayerLevel 返回 playerLevel 对象', () => {
      const { result } = renderHook(() => usePlayerLevel())
      expect(result.current).toBe(useGameStore.getState().playerLevel)
      expect(result.current).toHaveProperty('level')
      expect(result.current).toHaveProperty('xp')
      expect(result.current).toHaveProperty('totalXp')
    })

    it('useCoins 返回 coins 数值', () => {
      const { result } = renderHook(() => useCoins())
      expect(result.current).toBe(useGameStore.getState().coins)
    })

    it('useStreak 返回 streak 数值', () => {
      const { result } = renderHook(() => useStreak())
      expect(result.current).toBe(useGameStore.getState().streak)
    })

    it('useDays 返回 days 数值', () => {
      const { result } = renderHook(() => useDays())
      expect(result.current).toBe(useGameStore.getState().days)
    })

    it('useCoins 在 addCoins 后更新', () => {
      const { result } = renderHook(() => useCoins())
      const initialCoins = result.current

      act(() => {
        useGameStore.getState().addCoins(50)
      })

      expect(result.current).toBe(initialCoins + 50)
    })

    it('usePlayerLevel 在 addXp 后更新', () => {
      const { result } = renderHook(() => usePlayerLevel())
      const initialXp = result.current.xp

      act(() => {
        useGameStore.getState().addXp(30)
      })

      expect(result.current.xp).toBe(initialXp + 30)
      expect(result.current.totalXp).toBe(useGameStore.getState().playerLevel.totalXp)
    })
  })

  describe('宠物相关 selectors', () => {
    it('useCompanion 返回 companion 对象', () => {
      const { result } = renderHook(() => useCompanion())
      expect(result.current).toBe(useGameStore.getState().companion)
      expect(result.current).toHaveProperty('defId')
      expect(result.current).toHaveProperty('level')
    })

    it('useCompanion 在 petCompanion 后更新', () => {
      const { result } = renderHook(() => useCompanion())

      act(() => {
        useGameStore.getState().petCompanion()
      })

      expect(result.current.mood).toBe('happy')
    })
  })

  describe('成就/任务相关 selectors', () => {
    it('useAchievements 返回 achievements 数组', () => {
      const { result } = renderHook(() => useAchievements())
      expect(result.current).toBe(useGameStore.getState().achievements)
      expect(Array.isArray(result.current)).toBe(true)
    })

    it('useDailyQuests 返回 dailyQuests 数组', () => {
      const { result } = renderHook(() => useDailyQuests())
      expect(result.current).toBe(useGameStore.getState().dailyQuests)
      expect(Array.isArray(result.current)).toBe(true)
    })
  })

  describe('物品/技能相关 selectors', () => {
    it('useItems 返回 items 数组', () => {
      const { result } = renderHook(() => useItems())
      expect(result.current).toBe(useGameStore.getState().items)
      expect(Array.isArray(result.current)).toBe(true)
    })

    it('useSkills 返回 skills 数组', () => {
      const { result } = renderHook(() => useSkills())
      expect(result.current).toBe(useGameStore.getState().skills)
      expect(Array.isArray(result.current)).toBe(true)
    })
  })

  describe('组合 selector - useBattleState', () => {
    it('返回 monster / pendingAttack / damage 三个字段', () => {
      const { result } = renderHook(() => useBattleState())
      const state = useGameStore.getState()

      expect(result.current.monster).toBe(state.monster)
      expect(result.current.pendingAttack).toBe(state.daily.pendingAttack)
      expect(result.current.damage).toBe(state.daily.damage)
    })

    it('不相关状态变更时不触发重渲染（shallow 比较）', () => {
      let renderCount = 0
      renderHook(() => {
        renderCount++
        return useBattleState()
      })
      const baseline = renderCount

      // addCoins 仅修改 coins，与 useBattleState 返回字段无关
      // useShallow 应判定返回对象浅相等，不触发重渲染
      act(() => {
        useGameStore.getState().addCoins(100)
      })
      expect(renderCount).toBe(baseline)

      // setDifficulty 仅修改 user，与 useBattleState 返回字段无关
      act(() => {
        useGameStore.getState().setDifficulty('hard')
      })
      expect(renderCount).toBe(baseline)
    })

    it('相关状态变更时触发重渲染', () => {
      let renderCount = 0
      const { result } = renderHook(() => {
        renderCount++
        return useBattleState()
      })
      const baseline = renderCount
      const initialDamage = result.current.damage

      // attackMonster 会修改 monster 与 daily.damage，触发重渲染
      act(() => {
        useGameStore.getState().attackMonster(5)
      })

      expect(renderCount).toBeGreaterThan(baseline)
      expect(result.current.damage).toBe(initialDamage + 5)
    })
  })

  describe('组合 selector - useDailySummary', () => {
    it('返回 intake / exerciseBurn / damage 三个字段', () => {
      const { result } = renderHook(() => useDailySummary())
      const state = useGameStore.getState()

      expect(result.current.intake).toBe(state.daily.intake)
      expect(result.current.exerciseBurn).toBe(state.daily.exerciseBurn)
      expect(result.current.damage).toBe(state.daily.damage)
    })

    it('不相关状态变更时不触发重渲染（shallow 比较）', () => {
      let renderCount = 0
      renderHook(() => {
        renderCount++
        return useDailySummary()
      })
      const baseline = renderCount

      act(() => {
        useGameStore.getState().addCoins(50)
      })
      expect(renderCount).toBe(baseline)

      act(() => {
        useGameStore.getState().setDifficulty('easy')
      })
      expect(renderCount).toBe(baseline)
    })

    it('intake 变更时触发重渲染', () => {
      let renderCount = 0
      const { result } = renderHook(() => {
        renderCount++
        return useDailySummary()
      })
      const baseline = renderCount
      const initialIntake = result.current.intake

      act(() => {
        useGameStore.getState().addDietRecord({
          name: '面包',
          calories: 120,
          time: Date.now(),
        })
      })

      expect(renderCount).toBeGreaterThan(baseline)
      expect(result.current.intake).toBe(initialIntake + 120)
    })
  })

  describe('组合 selector - useGameProgress', () => {
    it('返回 playerLevel / coins / streak / days 四个字段', () => {
      const { result } = renderHook(() => useGameProgress())
      const state = useGameStore.getState()

      expect(result.current.playerLevel).toBe(state.playerLevel)
      expect(result.current.coins).toBe(state.coins)
      expect(result.current.streak).toBe(state.streak)
      expect(result.current.days).toBe(state.days)
    })

    it('不相关状态变更时不触发重渲染（shallow 比较）', () => {
      let renderCount = 0
      renderHook(() => {
        renderCount++
        return useGameProgress()
      })
      const baseline = renderCount

      // setDifficulty 仅修改 user，与 useGameProgress 无关
      act(() => {
        useGameStore.getState().setDifficulty('hard')
      })
      expect(renderCount).toBe(baseline)

      // attackMonster 修改 monster / daily / 等，不直接影响 progress 字段
      act(() => {
        useGameStore.getState().attackMonster(3)
      })
      expect(renderCount).toBe(baseline)
    })

    it('coins 变更时触发重渲染', () => {
      let renderCount = 0
      const { result } = renderHook(() => {
        renderCount++
        return useGameProgress()
      })
      const baseline = renderCount
      const initialCoins = result.current.coins

      act(() => {
        useGameStore.getState().addCoins(25)
      })

      expect(renderCount).toBeGreaterThan(baseline)
      expect(result.current.coins).toBe(initialCoins + 25)
    })

    it('streak 变更时触发重渲染', () => {
      let renderCount = 0
      const { result } = renderHook(() => {
        renderCount++
        return useGameProgress()
      })
      const baseline = renderCount
      const initialStreak = result.current.streak

      act(() => {
        useGameStore.getState().incrementStreak()
      })

      expect(renderCount).toBeGreaterThan(baseline)
      expect(result.current.streak).toBe(initialStreak + 1)
    })
  })
})
