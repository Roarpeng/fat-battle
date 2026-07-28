# 2026-07-28 Flutter 方案 A 全量 UI 重设计

## 方向

**锻造工坊（Forge Workshop）**：暖炭黑底 + 铜金强调 + 炉火赤红。对标 Duolingo 主屏节奏，避开通用蓝紫暗色壳。

## 导航

- 底部 2 Tab：`舞台` | `进度`
- 顶栏：Hub · 天数 · 铜币 · ⚙（设置/伙伴/商店）
- 饮食 / 锤炼：舞台两大拇指按钮 `Navigator.push` 全屏子页

## 舞台页

- 上 ~58%：怪物舞台（光环底座 + emoji 立绘 + 护盾光圈 + HP/护盾条 + 一句状态）
- 下：【饮食】【锤炼】对等大按钮（副文案：今日餐次/运动次数）
- 伤害/护盾变化：飘字 + 短震 haptic + 缩放打击感
- 删除：大号 kcal 标题、饮水条、三钮称重、「进入战斗场景」

## 组件与主题

- `AppColors` 锻造色板；`google_fonts`：Fraunces（标题）+ Figtree（正文）
- 新组件：`MonsterStageAvatar`、`StageActionButton`、`MiniMonsterHeader`、`ForgeBackground`

## 非目标

- 不改 Web；不改结算公式；不重做欢迎/建档文案逻辑
