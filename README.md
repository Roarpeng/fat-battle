# 塑身工坊

> 你的身体是你精心雕琢的作品。Android 端以雕塑隐喻记录塑形进度；战斗里的熔炉怪物只出现在游戏舞台上，不作为产品品牌。

[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Web-green.svg)](https://www.android.com/)
[![Framework](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev/)
[![Web](https://img.shields.io/badge/Web-React%20%2B%20Vite-blue.svg)](https://react.dev/)
[![Language](https://img.shields.io/badge/Dart-3.x-blue.svg)](https://dart.dev/)
[![State Management](https://img.shields.io/badge/Riverpod-StateNotifierProvider-purple.svg)](https://riverpod.dev/)
[![License](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)

**在线体验（Web 演示站，界面仍可能显示「减肥大作战」）：** [https://roarpeng-trae-idera.ms.show](https://roarpeng-trae-idera.ms.show)

**Android APK：** [Releases（Latest）](https://github.com/Roarpeng/fat-battle/releases/latest) — 文件名 `SuxingGongfang-<版本>.apk`（安装后显示「塑身工坊」）

仓库目录名与 pubspec 仍为 `fat-battle`（历史包名）；产品对外名称是 **塑身工坊**。

---

## 📖 目录

- [项目简介](#项目简介)
- [在线体验](#在线体验)
- [核心功能](#核心功能)
- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [快速开始](#快速开始)
- [Web 部署](#web-部署)
- [硬件方案](#硬件方案)
- [BLE 通信协议](#ble-通信协议)
- [游戏算法](#游戏算法)
- [开发指南](#开发指南)
- [路线图](#路线图)
- [常见问题](#常见问题)
- [贡献](#贡献)
- [许可证](#许可证)

---

## 项目简介

**塑身工坊** 把塑形过程做成一件持续雕刻的作品，而不是一场对外宣传的「打怪大战」。

- 🗿 **雕塑进度**：建档后按身体数据选择 **大卫 / 维纳斯** 两条线，启动器与应用内图标走 **0–7** 阶（粘土 → 杰作 → 保养 / 蒙尘 / 回潮）
- 🔥 **三种视觉主题**：熔炉（默认暗色）/ 铅笔手账 / 墨稿，可在设置里切换
- 🎭 **主界面**：登录后进入 `MainPage`，底栏只有 **舞台** 与 **进度**；饮食、锤炼、教练从舞台推入
- 👾 **怪物只在局内**：熔炉怪物立绘出现在舞台战斗构图里，不作为应用名、商店名或启动器品牌

动作识别采用「**摄像头 + 腰部 IMU**」的渐进式融合：ESP32-S3-Touch-AMOLED-1.43（板载 QMI8658）经 BLE 传到手机，与摄像头姿态一起识别锻炼动作。

产品有两条线：**Flutter App（Android，品牌塑身工坊）** 与 **Web 演示（React，对外文案可能仍写「减肥大作战」）**。核心热量安全规则以 App 为准，Web 的 `calories.ts` / `damage.ts` 已对齐同一套下限与预算带。

## 在线体验

Web 版本已部署到 ModelScope 创空间，无需安装即可体验演示循环：

**[打开 Web 演示](https://roarpeng-trae-idera.ms.show)**

> Web 演示包含角色创建、局内怪物战斗、饮食记录、锻炼追踪、成就、每日任务、技能等。摄像头姿态与蓝牙在浏览器里多为演示模式。品牌文案可能仍是「减肥大作战」，与 Android「塑身工坊」不一致。

---

## 核心功能

### 🧭 路由与舞台
- **Auth → Setup → MainPage**：未登录进登录/注册；已登录无存档进建档；有存档进主舞台
- **MainPage 两 Tab**：舞台（`HomePage`）+ 进度（`StatsPage`）
- 饮食 / 锤炼 / 教练 / 设置从舞台 `Navigator.push`，不再使用已删除的 `welcome_page` / 独立 `BattlePage` 入口
- `pubspec` 里仍声明 `go_router`，当前路由是 `MaterialApp.home` 分流，该依赖尚未接线

### 🗿 雕塑与主题
- **大卫 / 维纳斯** 双线人体雕塑图标，阶段 0–7（详见 `lib/theme/sculpt_progress.dart`）
- 三种主题：熔炉 / 铅笔手账 / 墨稿（`lib/theme/app_visual_theme.dart`）
- 启动器图标随雕塑进度变化（Android Adaptive Icon）

### 🎮 局内战斗（仅游戏内）
- 每日生成代表当日热量预算的怪物；HP 随击杀数 / 难度 / 体能递增；Boss 约每 5 天
- 三种难度：简单 / 普通 / 困难
- 锻炼造成伤害；打中热量预算带（目标 ±10%，至少 ±100 kcal）有加成，不再奖励「吃得越少越好」
- 过量摄入转为怪物护盾（约 10:1），不是羞辱文案
- 熔炉怪物立绘只画在舞台上

### 🍽️ 数据追踪
- **饮食记录**：早/中/晚餐，卡路里计算，支持手动录入；成功记餐会尽力 POST `/progress/events`
- **锻炼追踪**：多种运动类型，融合 IMU / 姿态；记锻炼同样尽力上报事件
- **体重与安全**：体重曲线、BMI；目标热量不低于 `max(性别下限, BMR)`，日赤字上限约 750 kcal
- **每周报表**：近 7 天摄入 / 消耗 / 伤害

### 🏆 成就与激励
- 成就殿堂、每日任务、技能、金币商店、连胜

### 📷 摄像头姿态识别（Web/App）
- MediaPipe / ML Kit 关键点、基础动作计数、语音提示、人体离画自动暂停

### 🔌 硬件集成（App）
- BLE 连接 ESP32-S3 腰部 Hub，12 字节 IMU 帧；无硬件时可纯手动录入
- 进度以 SharedPreferences 为主，登录后可与后端快照同步

## 技术栈

### App 端

| 类别 | 技术 |
|------|------|
| **UI 框架** | Flutter 3.x（Android；应用名「塑身工坊」） |
| **语言** | Dart 3.x |
| **状态管理** | Riverpod（StateNotifierProvider） |
| **本地存储** | SharedPreferences + flutter_secure_storage |
| **蓝牙通信** | flutter_blue_plus |
| **摄像头识别** | Google ML Kit Pose / TFLite MoveNet |
| **硬件平台** | ESP32-S3-Touch-AMOLED-1.43 |
| **传感器** | QMI8658 六轴 IMU |
| **后端** | Go + Gin + PostgreSQL（`/admin` 运营后台） |

### Web 端

| 类别 | 技术 |
|------|------|
| **框架** | React 18 + Vite 5 |
| **语言** | TypeScript |
| **样式** | Tailwind CSS 4 |
| **状态管理** | Zustand |
| **路由** | React Router v7 |
| **图表** | Recharts |
| **动画** | Framer Motion |
| **图标** | Lucide React |
| **PWA** | vite-plugin-pwa |
| **部署** | ModelScope 创空间（Docker） |

## 项目结构

```
fat-battle/
├── lib/                              # Flutter App（产品名：塑身工坊）
│   ├── main.dart                     # Auth → Setup → MainPage（舞台 / 进度）
│   ├── pages/
│   │   ├── auth_page.dart
│   │   ├── setup_page.dart
│   │   ├── home_page.dart            # 舞台
│   │   ├── stats_page.dart           # 进度
│   │   ├── food_page.dart
│   │   ├── exercise_page.dart
│   │   ├── coach_page.dart
│   │   ├── pose_coach_page.dart
│   │   ├── settings_page.dart
│   │   └── privacy_page.dart
│   ├── theme/                        # 熔炉 / 铅笔手账 / 墨稿 + 雕塑 0–7
│   ├── widgets/
│   │   ├── sculpt_icon.dart          # 大卫 / 维纳斯启动器与应用内图标
│   │   └── battle/                   # 熔炉怪物立绘（仅局内舞台）
│   ├── core/                         # 热量安全、预算带伤害等纯函数
│   ├── providers/
│   ├── services/                     # 同步 / BLE / 姿态 / 教练
│   └── models/
├── android/                          # 安装显示名「塑身工坊」
├── backend/                          # Go API + Docker + /admin
├── web/                              # Web 演示（文案可能仍为「减肥大作战」）
├── docs/                             # API 契约、账号删除说明等
├── test/
├── pubspec.yaml
└── README.md
```

> 已移除未接线的 `lib/pages/welcome_page.dart` 与 `lib/pages/battle_page.dart`。首页即舞台，不再单独挂战斗页。

## 快速开始

### 环境要求

- Flutter SDK ≥ 3.0
- Dart SDK ≥ 3.0
- Android SDK（API 34+）
- Android 设备或模拟器

### 安装与运行

```bash
# 1. 克隆仓库
git clone https://github.com/Roarpeng/fat-battle.git
cd fat-battle

# 2. 安装依赖
flutter pub get

# 3. 运行（连接 Android 设备或启动模拟器）
flutter run

# 4. 构建 debug APK
flutter build apk --debug

# 5. 构建 release APK
flutter build apk --release
```

构建产物路径：`build/app/outputs/flutter-apk/app-release.apk`

CI 会在每次 `master` 推送后自动构建 APK，并发布到 [GitHub Releases](https://github.com/Roarpeng/fat-battle/releases/latest)（同时保留 14 天的 Actions Artifact）。

### Web 端运行

```bash
cd web

# 1. 安装依赖
npm install

# 2. 开发模式
npm run dev

# 3. 构建生产版本
npm run build

# 4. 预览生产构建
npm run preview
```

### 后端（运营后台）

```bash
cd backend
cp .env.example .env          # 修改 JWT_SECRET、ADMIN_JWT_SECRET、ADMIN_PASS
docker compose up -d --build
curl http://localhost:8080/api/v1/healthz
# 管理后台：http://localhost:8080/admin
```

详见 [backend/README.md](backend/README.md)。

### 依赖清单

```yaml
dependencies:
  flutter_riverpod: ^2.6.1    # 状态管理
  shared_preferences: ^2.5.3  # 本地持久化
  flutter_blue_plus: ^1.35.4  # BLE 蓝牙通信
  go_router: ^15.1.2          # 已列入 pubspec，当前未接线
```

## Web 部署

Web 版本已配置 Docker 部署到 ModelScope 创空间：

```bash
# 1. 确保代码已提交
git add .
git commit -m "update"

# 2. 推送到创空间
git push modelscope master

# 3. 触发部署（通过 ModelScope API 或控制台）
```

部署配置：
- **类型**：Docker（`node:20-slim`）
- **端口**：`0.0.0.0:7860`
- **构建**：`npm install` → `npm run build` → `node server.js`
- **优化**：代码分割 + gzip 压缩

---

## 硬件方案

采用渐进式方案，分两阶段实施：

### 第一阶段（当前实现）
**摄像头 + 一个腰部 IMU**

- 📷 手机摄像头：识别锻炼动作姿态
- 💪 腰部佩戴：ESP32-S3-Touch-AMOLED-1.43（内置 QMI8658 六轴 IMU）
- 📡 通信：BLE 蓝牙直连手机

> 选择腰部作为单一佩戴点的理由：公共场所锻炼时摄像头不便，腰部 IMU 可全天候监测步数、深蹲、卷腹等躯干主导动作。

### 第二阶段（规划中）
**扩展四肢佩戴 ESP32+IMU**

- 🦵 四肢各佩戴一个 ESP32+IMU 模块
- 📶 四肢数据通过蓝牙汇总到腰部 Hub
- 🔄 腰部 Hub 转发到手机
- 🧠 手机融合 5 组数据进行精细动作识别

### 硬件清单

| 设备 | 型号 | 用途 |
|------|------|------|
| 腰部 Hub | Waveshare ESP32-S3-Touch-AMOLED-1.43 | 数据采集与转发 |
| IMU | QMI8658（板载） | 六轴加速度+陀螺仪 |
| 四肢节点（规划） | ESP32-S3 + QMI8658 | 四肢动作采集 |

## BLE 通信协议

### 服务与特征

- **Service UUID**：`4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **Notify 特征**：IMU 数据推送

### 数据格式

每帧 12 字节，按小端序排列：

| 偏移 | 字段 | 字节数 | 说明 |
|------|------|--------|------|
| 0-1  | ax   | 2      | 加速度 X 轴 |
| 2-3  | ay   | 2      | 加速度 Y 轴 |
| 4-5  | az   | 2      | 加速度 Z 轴 |
| 6-7  | gx   | 2      | 陀螺仪 X 轴 |
| 8-9  | gy   | 2      | 陀螺仪 Y 轴 |
| 10-11| gz   | 2      | 陀螺仪 Z 轴 |

采样率：50Hz

## 游戏算法

### 基础计算
- **BMI** = 体重(kg) / (身高(m))²
- **体脂类型**：偏瘦 < 18.5 / 正常 18.5-24 / 偏胖 24-28 / 肥胖 > 28
- **BMR**：Mifflin-St Jeor；**TDEE** = BMR × 活动系数
- **目标热量**：`max(热量下限, TDEE − 日赤字)`
  - 热量下限 = `max(性别下限, BMR)`（女 1200 / 男 1500）
  - 日赤字：温和 250 / 默认 500 / 上限 **750**（困难 / extremeLoss）
  - 双端 `lib/core/calories.dart` 与 `web/src/core/calories.ts` 使用同一套数字

### 战斗机制
- **怪物 HP** = 基础 HP × (1 + 击杀数 × 0.1) × 难度系数 × 体能等级系数
- **饮食**：超出目标 → 过量部分转为护盾（约 10:1）
- **锻炼伤害**：消耗卡路里 × 难度倍率；打中预算带 ×1.15，不再给「吃得少」加成
- **疲劳消耗**：锻炼时长累积消耗体力

### 体能等级
根据俯卧撑数量、跑步时长、每周频率综合评定：低 / 中 / 高 三档，影响怪物 HP 与玩家体力上限。

## 开发指南

### 代码规范

- 状态管理统一使用 Riverpod `StateNotifierProvider`
- 数据模型使用 `copyWith` + `toJson`/`fromJson` 模式
- 枚举定义集中在 [app_constants.dart](lib/constants/app_constants.dart)
- 算法逻辑：共享纯函数在 [lib/core/](lib/core/)，App 封装见 [game_algorithm.dart](lib/services/game_algorithm.dart)

### 运行测试

```bash
flutter test
cd backend && go test ./...
cd web && npm test
```

### 代码分析

```bash
flutter analyze
```

### 关键注意事项

1. **const 构造函数**：集合类与对象默认值必须加 `const`（如 `const []`、`const Monster()`）
2. **DateTime 字段**：非 const 构造函数，使用 `DateTime? createdAt` + 初始化列表
3. **clamp 类型转换**：`clamp()` 返回 `num`，需显式 `.toInt()` 或 `.toDouble()`
4. **枚举 .name 调用**：`_buildOptionGrid` 需显式传入 `labels` 参数避免 NoSuchMethodError
5. **Flutter 版本兼容**：使用 `CardThemeData` 替代 `CardTheme`
6. **不要改雕塑 PNG**：大卫 / 维纳斯关键帧由美术单独处理

## 路线图

### App 端
- [x] 第一阶段：Flutter 项目骨架 + 角色创建
- [x] 第二阶段：舞台战斗 + 饮食/锻炼追踪
- [x] 第三阶段：BLE 蓝牙集成 + IMU 动作识别
- [x] 第四阶段：Android 模拟器测试通过
- [x] 第五阶段：摄像头姿态识别融合
- [x] 第六阶段：语音播报 + 游戏化即时反馈
- [x] 账号 / 进度快照 / 运营后台（`/admin`）
- [x] 雕塑图标 0–7 + 三主题
- [ ] 第七阶段：扩展四肢 ESP32+IMU 节点
- [ ] 第八阶段：食物拍照 AI 识别（后端代理已有雏形）
- [ ] 第九阶段：发布到 Google Play

### Web 端
- [x] Web 版本基础框架（React + Vite + Tailwind）
- [x] 角色创建与局内怪物战斗
- [x] 饮食/锻炼/统计页面
- [x] 成就殿堂 + 每日任务 + 技能系统
- [x] 摄像头姿态检测（MediaPipe Pose）
- [x] 游戏化即时反馈
- [x] 部署到 ModelScope 创空间
- [x] 热量安全数字与 App 对齐（下限 + 750 赤字 + 预算带）
- [ ] 产品文案从「减肥大作战」迁到「塑身工坊」
- [ ] 食物拍照 AI 识别集成
- [ ] 排行榜与社交分享

## 账号删除

Google Play 要求提供应用内删除与可公开访问的说明页：

- **应用内**：工坊设置 → 账号安全与隐私规范 →「注销账号并抹除个人数据」
- **说明页内容**：[docs/account-deletion.html](docs/account-deletion.html)（请将该文件部署到你的 HTTPS 站点，并把 URL 填入 Play Console「账号删除」）
- **处理时限**：账号立即停用；云端数据 **30 天软删除** 后物理清除

## 常见问题

### Q: 为什么选腰部作为 IMU 佩戴点？
A: 腰部靠近人体重心，能稳定反映步数、深蹲、卷腹等躯干主导动作，且佩戴舒适，适合全天候监测。

### Q: 为什么不一开始就用 5 个 IMU？
A: 多设备方案调试复杂、佩戴繁琐。先用"摄像头 + 一个腰部 IMU"验证核心流程，后续再扩展四肢，符合渐进式迭代原则。

### Q: 没有 ESP32 硬件能运行吗？
A: 可以。角色创建、饮食/锻炼记录、舞台战斗不依赖硬件；BLE 失败时降级为手动录入。

### Q: 支持 iOS 吗？
A: 当前仅支持 Android。iOS 适配在路线图中，主要工作是 BLE 权限与签名配置。

### Q: 为什么商店和启动器不叫「减肥大作战」？
A: Android 产品名是塑身工坊，对外用雕塑隐喻。怪物只存在于游戏舞台。Web 演示站可能还写着旧名。

## 贡献

欢迎提交 Issue 和 Pull Request。

1. Fork 本仓库
2. 创建特性分支（`git checkout -b feature/AmazingFeature`）
3. 提交更改（`git commit -m 'Add some AmazingFeature'`）
4. 推送分支（`git push origin feature/AmazingFeature`）
5. 提交 Pull Request

## 许可证

本项目采用 [MIT License](LICENSE) 开源协议。

---

<p align="center">
  塑身工坊 · 把坚持雕成作品
</p>
