# 塑身工坊后端

Go + Gin + PostgreSQL + Redis + MinIO，**Docker 一键部署**。

## 一键启动

```bash
cd backend
cp .env.example .env        # 首次：修改 JWT_SECRET
docker compose up -d --build
```

首次构建约 1-2 分钟（多阶段构建，无需本机 Go 环境）。

## 验证

```bash
curl http://localhost:8080/api/v1/healthz
# {"status":"ok","service":"塑身工坊","time":"..."}
```

## 服务清单

| 服务 | 地址 | 说明 |
|------|------|------|
| API | http://localhost:8080 | Gin 服务（Docker 内构建） |
| 管理后台 | http://localhost:8080/admin | Web 管理界面（Go embed 单页） |
| PostgreSQL | localhost:5432 | 账号/进度/流水/LLM 配置 |
| Redis | localhost:6379 | 限流/黑名单/热榜（骨架预留） |
| MinIO | localhost:9000 / 9001(控制台) | 食物照片存储（M3 使用） |

## 管理后台

浏览器打开 `http://localhost:8080/admin`，首次启动自动创建种子管理员
（环境变量 `ADMIN_USER` / `ADMIN_PASS`，默认 `admin` / `admin123456`，**上线务必修改**）。

管理后台可：查看统计、用户搜索/禁用/启用/重置密码、LLM 配置增删改查与连通性测试。
管理 API 前缀 `/api/admin`，独立 JWT secret（`ADMIN_JWT_SECRET`，默认 `admin-secret-change-me`，务必修改）。

## 已实现

### 账号（App 对接）

- `POST /api/v1/auth/register` — 注册（bcrypt + JWT）
- `POST /api/v1/auth/login` — 登录（禁用账号返回 403）
- `POST /api/v1/auth/refresh` — refresh token 续期
- `POST /api/v1/auth/logout` — 登出
- `GET /api/v1/user/me` — 用户资料（Bearer token）
- `DELETE /api/v1/user` — 账号注销（软删 30 天）

### 食物识别代理（GLM 转发，密钥只存服务器）

App 不再持有第三方密钥，统一走后端（均在鉴权保护下）：

- `POST /api/v1/food/recognize` — 图片识别：`{"image":"<base64>","topNum":5,"thinking":false}` → `{"success":true,"items":[...]}`
- `POST /api/v1/food/search` — 文本搜索：`{"query":"米饭","topNum":3}` → 同上结构
- `POST /api/v1/food/feedback` — 识别纠错反馈落库
- `POST /api/v1/food/barcode` — 条码查询（待接入）

LLM 配置在管理后台维护（表 `llm_configs`，支持多配置、优先级、启用/停用、一键测连通）。
未配置任何 LLM 时识别/搜索返回 `503 {"success":false,"error":"未配置可用的 LLM 服务，请在管理后台配置"}`。
GLM 调用失败返回 502；响应带 `X-Provider: zhipu` 头。

### 进度快照（M4）

- `POST /api/v1/progress/snapshot` — upsert `GameState` JSON（`updatedAt` last-write-wins，返回 `revision`）
- `GET /api/v1/progress/snapshot` — 拉取最新快照；无存档 404
- `POST/GET /progress/events`、`GET /progress/summary` — 仍为 501

## 待实现（按 docs/backend-plan.md 路线）

- 行为流水 `/progress/events` 与周报 `/progress/summary`
- 条码库接入

## App 对接

```bash
# App 构建时注入后端地址（改 lib/config/api_config.dart 后）
flutter build apk --release --dart-define=API_BASE_URL=http://<服务器IP>:8080
```

数据库未就绪时 API 自动降级为内存模式（服务可起、healthz 返回 degraded），便于前端先行联调。
