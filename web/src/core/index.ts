/**
 * 游戏核心逻辑共享层 —— 双端（Web/Flutter）行为一致性基准。
 *
 * 所有导出函数均为纯函数：无副作用、不依赖外部状态、相同输入产生相同输出。
 * 类型定义从 `store/game-types` 与 `store/game-constants` 获取。
 */

export * from './damage'
export * from './progression'
export * from './monster'
export * from './difficulty'
export * from './streak'
export * from './calories'
export * from './weight'
