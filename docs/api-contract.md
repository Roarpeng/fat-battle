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

## 3. 进度同步 /progress（M4 预留）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST/GET | /progress/snapshot | 全量快照（GameState.toJson） |
| POST/GET | /progress/events | 增量行为流水 |
| GET | /progress/summary | 统计摘要 |

## 4. 管理后台 /api/admin（独立 JWT，role=admin）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /admin/login | `{username, password}` → `{token}` |
| GET | /admin/users?q=&page=&pageSize= | 用户列表（禁用状态） |
| POST | /admin/users/{id}/disable\|/enable | 禁用/启用 |
| POST | /admin/users/{id}/reset-password | `{password}` |
| GET/POST | /admin/llm | 配置列表 / 新增 |
| PUT/DELETE | /admin/llm/{id} | 更新 / 删除 |
| POST | /admin/llm/{id}/test | 测试连通 → `{ok, latencyMs}` |
| GET | /admin/stats | `{users, llmConfigs, dbOk}` |

llm_configs 字段: `{name, provider(zhipu), base_url, api_key, vision_model, text_model, enabled, priority, remark}`

管理界面: `http://<host>:8080/admin`（Go embed 单页，种子账号 ADMIN_USER/ADMIN_PASS）
