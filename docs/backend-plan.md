# 《塑身工坊》后端建设方案

> 文档版本: v1.0 | 更新日期: 2026-08-02
> 目标: 账号管理 · 食物识别代理 · 进度记录云同步

---

## 1. 现状盘点（App 侧）

| 能力 | 现状 | 问题 |
|------|------|------|
| 账号 | `auth_page.dart` 模拟登录，假 token 存 SharedPreferences | 无真实账号体系，换设备数据全丢 |
| 食物识别 | App 直连智谱 GLM / 百度 API（`api_config.dart` 密钥编译时注入） | 密钥暴露在客户端，无法审计/限流/计费 |
| 进度记录 | `persistence_service.dart` 全量 `GameState` JSON 存本地 | 无云备份，无多端同步，无排行基础 |
| 存档 | `GameState.toJson()` 已是结构化数据 | 可直接做增量同步协议 |

**关键结论**：`GameState` 已经有完整的 JSON 序列化（`toJson`/`fromJson`），后端进度模块可以复用它做同步载体，不需要重新设计数据模型。

---

## 2. 技术选型

### 2.1 后端框架（三选一，推荐 Go）

| 方案 | 优点 | 缺点 | 适用 |
|------|------|------|------|
| **Go + Gin/Echo** ⭐推荐 | 单二进制部署、高并发、内存占用低、REST 生态成熟 | 上手曲线略陡 | 生产首选，成本最低 |
| **Python + FastAPI** | 开发最快，AI/识别生态最强（OpenAI SDK、Pillow） | 部署要配 Uvicorn/Gunicorn，并发弱于 Go | 团队熟 Python / 快速 MVP |
| **Node.js + NestJS** | TS 类型安全、模块化强 | 运行时资源占用高 | 团队熟 TS |

> 本方案按 **Go + Gin** 编写（如需 FastAPI 版仅接口签名相同，协议无关）。

### 2.2 基础设施

| 组件 | 选型 | 用途 |
|------|------|------|
| 数据库 | **PostgreSQL 16** | 账号、用户资料、进度快照、行为流水 |
| 缓存/会话 | **Redis 7** | Token 黑名单、限流计数、排行榜热榜 |
| 对象存储 | **MinIO**（自建）或 阿里云 OSS | 食物识别照片、头像 |
| 网关 | **Caddy / Nginx** | TLS 终止、反向代理到 API |
| 部署 | **Docker Compose**（单机起步）→ K8s（规模后） | 一键编排 |
| CI | GitHub Actions（仓库已有） | 自动构建后端镜像 |

### 2.3 目录结构（Go 版）

```
backend/
├── cmd/server/main.go        # 入口
├── internal/
│   ├── api/                  # HTTP 路由 + handler
│   │   ├── auth/             # 注册/登录/刷新/登出
│   │   ├── food/             # 识别代理（照片+条形码）
│   │   ├── progress/         # 进度同步
│   │   └── user/             # 资料、注销
│   ├── service/              # 业务逻辑
│   ├── repo/                 # PostgreSQL 访问层
│   ├── middleware/           # JWT、限流、CORS、日志
│   └── model/                # 数据模型
├── migrations/               # SQL 迁移（golang-migrate）
└── docker-compose.yml
```

---

## 3. API 设计

统一前缀 `/api/v1`，鉴权用 **JWT（access 2h + refresh 30d）**，移动端存 SecureStorage。

### 3.1 账号管理 `POST /api/v1/auth/*`

| 接口 | 说明 |
|------|------|
| `POST /register` | 昵称+邮箱+密码（bcrypt），返回 token 对 |
| `POST /login` | 账号密码登录 |
| `POST /refresh` | 刷新 token |
| `POST /logout` | 拉黑 access token |
| `DELETE /user` | 账号注销（合规：保留期 30 天后物理删除） |
| `GET /user/me` | 当前用户资料（App 设置页用） |

### 3.2 食物识别代理 `POST /api/v1/food/*`

**App 不再持有第三方密钥**，改为后端转发（密钥只留在服务器）：

```
POST /food/recognize      # multipart 照片 → 后端调 GLM/百度 → 返回结构化结果
POST /food/barcode        # 条形码 → 条码库
GET  /food/search?q=      # 文本检索（复用现有 FoodRecognitionServiceV2 逻辑）
POST /food/feedback       # 用户纠错反馈 → 沉淀识别质量数据
```

返回值对齐 App 现有模型 `RecognizedFood`：
```json
{ "items": [{ "name": "红烧肉", "cal": 350, "confidence": 0.92, "gram": 150 }] }
```

### 3.3 进度记录 `GET/POST /api/v1/progress/*`

复用 `GameState` 结构做**全量快照 + 增量流水**双通道：

| 接口 | 说明 |
|------|------|
| `POST /progress/snapshot` | 整份 `GameState.toJson()` 上云（离线恢复用） |
| `GET /progress/snapshot` | 拉取最新快照（换机/重装恢复） |
| `POST /progress/events` | 批量行为流水（记录餐食/锻炼/战绩），服务端聚合统计 |
| `GET /progress/events?from=ts` | 增量拉取（多端同步） |
| `GET /progress/summary?range=7d` | 周报/趋势（进度页数据源） |

数据库表：
```sql
users          (id, email, nickname, pass_hash, avatar_url, created_at)
user_progress  (user_id, game_state_json, updated_at)        -- 最新快照
progress_events(id, user_id, type, payload_json, created_at) -- 行为流水
food_feedback  (id, user_id, image_url, ocr_result, user_cal, status)
```

---

## 4. App 与后端结合方式

### 4.1 架构分层（改造 4 个文件）

```
┌─────────────────────────────────────────────┐
│  Flutter App                                 │
│  pages/…  (UI 不变)                          │
│  providers/… (Riverpod 状态层不变)            │
├─────────────────────────────────────────────┤
│  services/                                  │
│   ├─ AuthService      (新)  真实登录/刷新     │
│   ├─ FoodRecognitionServiceV2 (改造) 请求转发 │
│   └─ SyncService      (新)  快照+增量同步     │
│  config/api_config.dart (改造) 加后端 baseUrl │
└──────────────┬──────────────────────────────┘
               │ HTTPS + JWT
┌──────────────▼──────────────────────────────┐
│  Go 后端（Docker Compose）                    │
│  Gin 路由 → middleware(JWT/限流) → service    │
│  PostgreSQL + Redis + MinIO                  │
│  第三方: 智谱GLM / 百度 / 薄荷(可选)           │
└─────────────────────────────────────────────┘
```

### 4.2 改造点明细

| 文件 | 改动 | 优先级 |
|------|------|--------|
| `lib/config/api_config.dart` | 新增 `backendBaseUrl`（dart-define `API_BASE_URL`），密钥常量降级为「仅离线兜底」 | P0 |
| `lib/pages/auth_page.dart` | 模拟登录改为调 `AuthService`（`_handleSubmit` 内替换 `prefs` 直写段） | P0 |
| `lib/services/food_recognition_service_v2.dart` | `recognize()` 前加后端代理分支：`hasBackend ? POST /food/recognize : 直连` | P0 |
| `lib/services/persistence_service.dart` | `saveGameState` 时异步触发 `SyncService.pushSnapshot` | P1 |
| 新增 `lib/services/auth_service.dart` | 登录/刷新/登出 + token 存 `flutter_secure_storage` | P0 |
| 新增 `lib/services/sync_service.dart` | 启动拉取快照合并、退出/记录时推送 | P1 |

**关键原则**：
1. **后端不可用时自动降级**——识别回退直连（密钥仍在时）、进度回退本地，用户无感
2. **离线优先**——本地 SharedPreferences 仍是主存储，云端只是镜像；网络恢复后合并
3. **密钥只留服务器**——新装 App 只需 `--dart-define=API_BASE_URL`，不再需要第三方 key

### 4.3 鉴权流程（App 侧）

```
启动 → AuthService.tryRestore()
  ├─ 有 refresh token → POST /refresh → 续期 → 进首页
  ├─ 无 token → AuthPage
登录成功 → 存 access/refresh → 进首页
每次请求 → 带 Bearer token；401 → 刷新重试一次，失败 → 踢回登录页
```

### 4.4 部署拓扑（MVP 单机）

```
VPS (2C4G 起步)
├── Caddy ──:443 (TLS + 反代)
├── api 容器 (Go, 占用 < 50MB)
├── postgres 容器 (20GB 卷)
├── redis 容器
└── minio 容器 (照片)
GitHub Actions: 推送 backend/ → 构建镜像 → docker compose up
```

---

## 5. 实施路线

| 阶段 | 内容 | 周期 |
|------|------|------|
| **M1 骨架** | Go 项目脚手架 + Docker Compose + Caddy + 数据库迁移 + 健康检查 | 1-2 天 |
| **M2 账号** | 注册/登录/刷新/登出 + JWT + bcrypt + `flutter_secure_storage` 接入 | 2-3 天 |
| **M3 识别代理** | `/food/recognize` 转发 GLM + 照片存 MinIO + App 改造 `recognize()` | 2-3 天 |
| **M4 进度同步** | snapshot/events 两接口 + App `SyncService` + 断线合并 | 2-3 天 |
| **M5 合规上线** | 注销账号、隐私政策、日志审计、限流 | 1-2 天 |

> 建议 M2 完成后即可替换现有模拟登录体验，M4 完成后 App 才真正"换机不丢"。

---

## 6. 安全要点

- 密码 **bcrypt**（cost≥10），JWT 密钥环境变量注入不入库不入仓
- 食物照片上传**限 5MB、校验 MIME**，存储路径含 user_id 防越权
- 接口全量**速率限制**（Redis 滑动窗口：识别 10 次/分钟，登录 5 次/分钟）
- App 端 token 用 **flutter_secure_storage**（Keychain/Keystore），不落 SharedPreferences
- 注销走「软删 + 30 天缓冲」合规流程（对应现有 settings 页注销功能）
