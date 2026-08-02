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
| PostgreSQL | localhost:5432 | 账号/进度/流水（init 自动建表） |
| Redis | localhost:6379 | 限流/黑名单/热榜（骨架预留） |
| MinIO | localhost:9000 / 9001(控制台) | 食物照片存储（M3 使用） |

## 已实现（M1 + M2 账号）

- `POST /api/v1/auth/register` — 注册（bcrypt + JWT）
- `POST /api/v1/auth/login` — 登录
- `POST /api/v1/auth/refresh` — refresh token 续期
- `POST /api/v1/auth/logout` — 登出
- `GET /api/v1/user/me` — 用户资料（Bearer token）
- `DELETE /api/v1/user` — 账号注销（软删 30 天）

## 待实现（按 docs/backend-plan.md 路线）

- M3：`/food/*` 识别代理（GLM/百度转发，密钥只留服务器）
- M4：`/progress/*` 快照 + 增量流水 + 统计

## App 对接

```bash
# App 构建时注入后端地址（改 lib/config/api_config.dart 后）
flutter build apk --release --dart-define=API_BASE_URL=http://<服务器IP>:8080
```

数据库未就绪时 API 自动降级为内存模式（服务可起、healthz 返回 degraded），便于前端先行联调。
