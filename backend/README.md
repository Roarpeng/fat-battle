# 塑身工坊后端

Go + Gin + PostgreSQL + Redis + MinIO，**Docker 一键部署**。无需本机 Go / Postgres。

## 一键启动

```bash
cd backend
cp .env.example .env        # 首次：修改 JWT_SECRET / ADMIN_JWT_SECRET / ADMIN_PASS
docker compose up -d --build
```

首次构建约 1-2 分钟（多阶段构建，无需本机 Go 环境）。

API 容器启动时会按文件名执行 `migrations/*.sql` 全部迁移（`schema_migrations` 跳过已执行文件）。
Postgres 的 `docker-entrypoint-initdb.d` **只挂 0001**，且只对全新数据卷生效；后续表结构一律靠 API 启动补齐。

## 验证

```bash
curl http://localhost:8080/api/v1/healthz
# {"status":"ok","service":"塑身工坊","time":"..."}

curl http://localhost:8080/api/v1/config/public
# {"calorieFloor":1500,"maxDailyDeficit":750,"coachEnabled":true,...}  不含密钥
```

## 服务清单

| 服务 | 地址 | 说明 |
|------|------|------|
| API | http://localhost:8080 | Gin 服务（Docker 内构建） |
| 管理后台 | http://localhost:8080/admin | Web 管理界面（Go embed 单页） |
| PostgreSQL | 容器内 5432（不对外） | 账号 / 档案 / 进度 / 流水 / LLM |
| Redis | 容器内 6379 | 登出 token 黑名单 |
| MinIO | localhost:9000 / 9001(控制台) | 食物照片存储 |
| Caddy | :80 / :443 | 反代（可保留） |

## 管理后台

浏览器打开 `http://localhost:8080/admin`。

种子管理员来自环境变量（**上线务必修改**）：

| 变量 | 默认 | 说明 |
|------|------|------|
| `ADMIN_USER` | `admin` | 首次启动若 `admin_users` 为空则创建 |
| `ADMIN_PASS` | `admin123456` | 写在 `backend/.env` 即可覆盖 |
| `ADMIN_JWT_SECRET` | `admin-secret-change-me` | 与 App JWT 隔离 |
| `JWT_SECRET` | `dev-secret-change-me` | App 用户 JWT |

改密码：改 `.env` 里的 `ADMIN_PASS` **不会**覆盖已存在的管理员，请在库里改哈希或清空 `admin_users` 后重启。

### 点进后台改用户雕塑阶段与热量目标

1. 登录 `/admin`
2. 打开 **用户**，搜索邮箱/昵称，点击进入卷宗（可改档案、禁用、重置密码）
3. 打开 **进度**，填用户 ID →「读取当前值」核对 → 填「雕塑阶段 0–7」和「目标热量」→ **确认修改并审计**
4. 总览页可看到审计记录；`GET /api/admin/audit` 也可查

### 查看某个用户（SQL）

```bash
docker exec -it fatbattle-postgres psql -U fatbattle -d fatbattle -c \
  "SELECT u.id, u.email, p.nickname, p.weight_kg, p.target_cal, s.stage, s.line
   FROM users u
   LEFT JOIN user_profiles p ON p.user_id = u.id
   LEFT JOIN sculpt_progress s ON s.user_id = u.id
   WHERE u.email ILIKE '%你的邮箱%';"
```

## 已实现

### 账号（App 对接）

- `POST /api/v1/auth/register` — 注册（bcrypt + JWT；同时建 `user_profiles`）
- `POST /api/v1/auth/login` — 登录（禁用账号返回 403）
- `POST /api/v1/auth/refresh` / `POST /api/v1/auth/logout`
- `GET /api/v1/user/me` — 用户资料 + profile
- `PUT /api/v1/user/me` — 更新建档字段
- `DELETE /api/v1/user` — 账号注销

### 公开配置

- `GET /api/v1/config/public` — 热量下限 / 日赤字上限 / 教练与识别开关 / 默认主题 / 雕塑阈值。**无密钥**。

### 食物识别 / 教练

与此前相同：密钥只存 `llm_configs`，管理后台 CRUD + ping。

### 进度

- `POST/GET /api/v1/progress/snapshot` — GameState JSON，last-write-wins + revision。写入后拆表刷新 `user_profiles` / `sculpt_progress` / 体测，并尽力提取当日餐食与锻炼。
- `POST /api/v1/progress/events` — 追加 `meal|exercise|battle|weight|sculpt_settle`，拆进规范化表。鉴权必需。
- `GET /api/v1/progress/events?from&to&type`
- `GET /api/v1/progress/summary?range=7d|30d` — 摄入/消耗千卡、课次、streak、体重变化、雕塑阶段

#### 事件 payload（App 后续可按此接线；当前 App 已尽力 POST meal/exercise）

```json
{"type":"meal","at":"2026-08-13T08:00:00Z","id":"可选幂等键","payload":{
  "name":"豆浆","grams":300,"calories":120,"mealSlot":"breakfast","source":"manual"
}}
{"type":"exercise","payload":{
  "lessonName":"深蹲课","mode":"camera","caloriesBurned":180,"damageDealt":40,
  "totalReps":30,"feel":"ok","settled":true,"moves":[{"name":"深蹲","reps":15,"quality":80,"calories":90}]
}}
{"type":"weight","payload":{"weightKg":70.2,"waistCm":80,"recordedOn":"2026-08-13"}}
{"type":"sculpt_settle","payload":{"stage":3,"progress":0.75,"line":"venus","sessionsCount":12,"maintenance":"none"}}
{"type":"battle","payload":{"damage":40,"killed":false}}
```

也可一次提交：`{"events":[ ... ]}`。`mode`：`camera|imu|manual`；`feel`：`too_easy|ok|too_hard`。

## App 对接

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://<服务器IP>:8080
```

不要把 API Key 写进 App。数据库未就绪时 API 降级内存模式（healthz = degraded）。
