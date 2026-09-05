# 塑身工坊 · API 契约

> 版本 v1.0 | 2026-08-02
> App 与后端之间的完整接口约定。后端实现见 [backend-plan.md](backend-plan.md)。

## 0. 通用约定

- Base URL: `http://<host>:8080/api/v1`（App 通过 `--dart-define=API_BASE_URL=` 注入）
- 认证: `Authorization: Bearer <accessToken>`（除 auth 前缀外全部必需）
- 错误格式: `{"error": "..."}`；识别类接口 `{"success": false, "error": "..."}`
- token 过期: access 2h / refresh 30d；401 时 App 自动 refresh 重试一次

## 1. 账号管理 /auth /user

| 方法 | 路径 | 请求 | 响应 |
|------|------|------|------|
| POST | /auth/register | `{email, password, nickname}` | `{user, token}`；409 邮箱已注册 |
| POST | /auth/login | `{email, password}` | `{user, token}`；403 账号被禁用 |
| POST | /auth/refresh | `{refreshToken}` | `{token}` |
| POST | /auth/logout | `{refreshToken?}` + 可选 `Authorization` | `{ok:true}`；将 access/refresh 的 jti 写入 Redis 黑名单直至过期 |
| GET | /user/me | - | `{user}` |
| DELETE | /user | - | `{ok:true, message}`（软删 30 天；当前 access 同步拉黑） |

token 结构: `{accessToken, refreshToken, expiresIn}`

## 2. 食物 LLM 代理 /food（密钥只存服务器）

| 方法 | 路径 | 请求 | 响应 |
|------|------|------|------|
| POST | /food/recognize | `{image: base64, topNum?, thinking?}` | `{success, items}` |
| POST | /food/search | `{query, topNum?}` | `{success, items}` |
| POST | /food/feedback | `{imageUrl?, ocrResult?, userCal?}` | `{ok:true}` |
| POST | /food/barcode | `{barcode}` | `{success, items}`（Open Food Facts 代理，无客户端密钥） |

items 项: `{name, calorie(每100g), confidence, has_calorie, category, description}`

服务端按 `llm_configs` 表 enabled + priority 选择 provider（当前 zhipu），
请求带 `X-Provider` 响应头。无可用配置 → 503。

## 2.1 营养教练 /coach（密钥只存服务器）

| 方法 | 路径 | 请求 | 响应 |
|------|------|------|------|
| POST | /coach/turn | `{message, history?, context}` | `{success, reply, filtered, proposedLogs}` |

`context` 由 App 从本地 GameState 组装（饮食账、剩余预算、怪物 HP/护盾、今日锤炼、5 步档案）。
教练**不能**改卡路里目标/下限，**不能**静默写饮食账；`proposedLogs` 需用户改克数后确认才记入。
限流与 `/food` 相同（30 次/分钟）。系统提示 + 输出过滤器禁止低于安全下限、催吐、惩罚性禁食、「跳过正餐打怪」。

## 3. 进度同步 /progress

鉴权：`Authorization: Bearer <accessToken>`。只同步 `GameState.toJson()` 文本快照，**不**上传姿态视频、训练日记或 IMU 流。

| 方法 | 路径 | 请求 | 响应 |
|------|------|------|------|
| POST | /progress/snapshot | `{state: GameState, updatedAt?: RFC3339}`（`gameState` 为 state 别名） | `{state, updatedAt, revision}`；云端更新则 **409** 并带回当前云端快照 |
| GET | /progress/snapshot | - | `{state, updatedAt, revision}`；无存档 **404** `{"error":"暂无云端存档"}` |
| POST | /progress/events | `{type, at?, id?, payload}` 或 `{events:[...]}`；type=`meal\|exercise\|battle\|weight\|sculpt_settle` | `{ok, accepted}` |
| GET | /progress/events | `?from&to&type` | `{items}` |
| GET | /progress/summary | `?range=7d\|30d` | `{kcalIn,kcalOut,sessions,meals,streak,weightDeltaKg,sculptStage}` |
| GET | /config/public | 无鉴权 | 运营开关与热量下限，**不含密钥** |
| PUT | /user/me | 建档字段 | `{ok, profile}` |

冲突策略：按 `updatedAt` **last-write-wins**（客户端时间 ≥ 云端才覆盖；相等允许重试覆盖）。每次成功写入 `revision` +1。快照成功后会刷新 `user_profiles` / `sculpt_progress` 等规范化表。

App 登录后合并：云端空则推本地；本地空则拉云端；双边都有则比较 `updatedAt`。首次登录有本地档时不覆盖本机进度。

## 4. 管理后台 /api/admin（独立 JWT，role=admin）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /admin/login | `{username, password}` → `{token}` |
| GET | /admin/users?q=&page=&pageSize= | 用户列表（禁用状态） |
| GET | /admin/users/{id} | 卷宗：账号 + profile + sculpt + 快照元数据 |
| PATCH | /admin/users/{id} | 改档案字段（审计） |
| GET | /admin/users/{id}/sessions\|meals\|metrics\|events | 该用户规范化数据 |
| PATCH | /admin/users/{id}/progress | 体重/目标热量/streak/雕塑阶段与线/主题（确认后写快照 + 审计） |
| POST | /admin/users/{id}/disable\|/enable | 禁用/启用（审计） |
| POST | /admin/users/{id}/reset-password | `{password}`（审计） |
| GET | /admin/sessions?userId=&from=&to= | 锻炼课筛选 |
| GET | /admin/meals?userId=&from=&to= | 饮食筛选 |
| GET/POST | /admin/llm | 配置列表 / 新增 |
| PUT/DELETE | /admin/llm/{id} | 更新 / 删除 |
| POST | /admin/llm/{id}/test | 测试连通 → `{ok, latencyMs}` |
| GET/PUT | /admin/settings | 运营配置（无密钥） |
| GET | /admin/audit?userId=&limit= | 审计日志 |
| GET | /admin/stats | `{users, dau, sessionsToday, mealsToday, llmConfigs, dbOk}` |

llm_configs 字段: `{name, provider(zhipu), base_url, api_key, vision_model, text_model, enabled, priority, remark}`

管理界面: `http://<host>:8080/admin`（Go embed 单页，种子账号 ADMIN_USER/ADMIN_PASS）
