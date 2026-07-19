# Store

游戏状态管理基于 [Zustand 5.x](https://github.com/pmndrs/zustand)，采用 slice 模式组合多个领域状态。

## 目录结构

```
store/
├── useGameStore.ts        # 统一 store（组合所有 slice，含 persist 中间件）
├── game-types.ts          # 类型定义
├── game-constants.ts      # 游戏常量（成就/技能/道具/任务模板等）
├── game-utils.ts          # 工具函数（怪物生成/BMI/经验值等）
├── selectors.ts           # 细粒度 selector hooks
├── slices/                # 各领域 slice
│   ├── userSlice.ts
│   ├── monsterSlice.ts
│   ├── dailySlice.ts
│   ├── progressSlice.ts
│   ├── achievementSlice.ts
│   ├── inventorySlice.ts
│   └── companionSlice.ts
└── __tests__/
    └── selectors.test.ts
```

## Selector Hooks

`selectors.ts` 提供按功能域分组的细粒度 selector hooks，避免组件因不必要的状态变更而重渲染。

### 使用方式

```tsx
import { useMonsterHp, useBattleState, useGameProgress } from '../store/selectors'

function MonsterBar() {
  // 仅订阅 monster.hp，其他状态变更不会触发该组件重渲染
  const hp = useMonsterHp()
  return <div>HP: {hp}</div>
}

function BattleHUD() {
  // 组合 selector，useShallow 进行浅比较
  const { monster, pendingAttack, damage } = useBattleState()
  return <div>...</div>
}

function ProgressBar() {
  const { playerLevel, coins, streak, days } = useGameProgress()
  return <div>...</div>
}
```

### 性能优势

1. **细粒度订阅**：单一字段 selector（如 `useMonsterHp`、`useCoins`）只在该字段变化时重渲染，避免父级对象引用变化导致的连带更新。
2. **浅比较组合**：组合 selector（`useBattleState` / `useDailySummary` / `useGameProgress`）通过 `zustand/react/shallow` 的 `useShallow` 对返回对象做浅比较，只有当任一返回字段变化时才触发更新。
3. **避免整 store 订阅**：相比于 `const { hp, coins } = useGameStore()` 这种解构写法（订阅整个 state，任何变更都会触发重渲染），selector hooks 只订阅真正使用的字段。

### 分类一览

| 类别         | Hooks                                                                 |
| ------------ | --------------------------------------------------------------------- |
| 用户         | `useUser`, `useUserWeight`, `useUserDifficulty`                       |
| 怪物         | `useMonster`, `useMonsterHp`, `useMonsterPhase`, `useMonsterShield`   |
| 每日状态     | `useDaily`, `useDailyIntake`, `useDailyExerciseBurn`, `useDailyDamage`, `usePendingAttack` |
| 记录         | `useDietRecords`, `useExerciseRecords`                                |
| 进度         | `usePlayerLevel`, `useCoins`, `useStreak`, `useDays`                  |
| 宠物         | `useCompanion`                                                        |
| 成就/任务    | `useAchievements`, `useDailyQuests`                                   |
| 物品/技能    | `useItems`, `useSkills`                                               |
| 组合 selector | `useBattleState`, `useDailySummary`, `useGameProgress`                |

> 备注：`MonsterState` 中没有 `phase` 字段，`useMonsterPhase` 实际返回 `monster.phaseIndex`。
