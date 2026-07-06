# 🥊 减肥大作战 (Fat Battle)

> 一款将减肥过程游戏化的跨平台应用 —— 每日与"贪吃怪物"战斗，用饮食控制和锻炼削减怪物 HP，让坚持健康生活方式变成一场冒险。

[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Web-green.svg)](https://www.android.com/)
[![Framework](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev/)
[![Web](https://img.shields.io/badge/Web-React%20%2B%20Vite-blue.svg)](https://react.dev/)
[![Language](https://img.shields.io/badge/Dart-3.x-blue.svg)](https://dart.dev/)
[![State Management](https://img.shields.io/badge/Riverpod-StateNotifierProvider-purple.svg)](https://riverpod.dev/)
[![License](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)

**在线体验：** [https://roarpeng-trae-idera.ms.show](https://roarpeng-trae-idera.ms.show)

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

**减肥大作战** 把枯燥的减肥过程变成一场 RPG 风格的冒险。玩家创建角色后，每天会生成一只代表"今日卡路里预算"的怪物：

- 🍔 **饮食过量** → 怪物回血
- 🏃 **锻炼消耗** → 对怪物造成伤害
- ⚔️ **击败怪物** → 获得金币、连胜加成
- 📉 **体重下降** → 解锁成就、进入维持模式

动作识别采用「**摄像头 + 腰部 IMU**」的渐进式融合方案：通过 ESP32-S3-Touch-AMOLED-1.43 开发板（内置 QMI8658 六轴 IMU）采集腰部运动数据，经 BLE 蓝牙传输到手机，结合摄像头画面识别锻炼动作。

项目包含 **Flutter App（Android）** 和 **Web 版本** 两条线，核心游戏算法共享，Web 版支持在线体验。

## 在线体验

Web 版本已部署到 ModelScope 创空间，无需安装即可体验核心功能：

**[点击体验减肥大作战 Web 版](https://roarpeng-trae-idera.ms.show)**

> Web 版包含角色创建、怪物战斗、饮食记录、锻炼追踪、成就系统、每日任务、技能系统等完整游戏循环。摄像头姿态检测和蓝牙硬件功能因浏览器权限限制，在 Web 端为演示模式。

---

## 核心功能

### 🎮 游戏系统
- **5 步角色创建**：基础数据 → 生活习惯 → 体能评估 → 难度选择 → 角色确认
- **怪物战斗**：每日生成怪物，HP 随击杀数/难度/体能等级递增；Boss 战每 5 天一次
- **三种难度**：简单 / 普通 / 困难，影响怪物强度与每日卡路里目标
- **疲劳系统**：锻炼时长累积消耗玩家体力，体力归零则战斗失败
- **护盾与休息日**：商店购买，紧急恢复体力
- **即时反馈**：锻炼时浮动 XP 数字、连击奖励、升级弹窗，让运动产生快乐

### 🍽️ 数据追踪
- **饮食记录**：早/中/晚餐分类，卡路里自动计算，支持手动录入
- **锻炼追踪**：8 种运动类型，记录时长与消耗，融合 IMU 动作识别
- **体重管理**：体重曲线、BMI 实时计算、达成目标自动切换至维持模式
- **每周报表**：最近 7 天卡路里摄入/消耗/伤害统计

### 🏆 成就与激励
- **成就殿堂**：首杀、5 杀、10 杀、3/7/30 天连胜、千卡运动、千金币、Boss 击杀、减重 5kg、7/30 天坚持等
- **每日任务**：每日刷新挑战任务，完成后获得额外奖励
- **技能系统**：通过持续锻炼解锁技能，提升战斗效率
- **金币商店**：购买护盾、休息日、签到加成
- **连胜机制**：完成每日目标累积连胜，失败清零

### 📷 摄像头姿态识别（Web/App）
- **MediaPipe Pose**：实时全身关键点检测
- **动作识别**：俯卧撑、深蹲、开合跳等基础动作计数
- **即时语音指导**：可爱宠物风格语音播报，纠正姿势
- **自动暂停**：人体离开画面 15 帧后自动暂停，回归后自动恢复

### 🔌 硬件集成（App）
- **BLE 蓝牙通信**：连接 ESP32-S3 腰部 Hub 接收 IMU 数据
- **动作识别**：基于 12 字节 IMU 数据（ax/ay/az/gx/gy/gz）识别运动类型
- **数据持久化**：基于 SharedPreferences / localStorage 本地保存游戏进度

## 技术栈

### App 端

| 类别 | 技术 |
|------|------|
| **UI 框架** | Flutter 3.x（Android 平台） |
| **语言** | Dart 3.x |
| **状态管理** | Riverpod（StateNotifierProvider） |
| **本地存储** | SharedPreferences |
| **蓝牙通信** | flutter_blue_plus |
| **摄像头识别** | MediaPipe Pose |
| **硬件平台** | ESP32-S3-Touch-AMOLED-1.43 |
| **传感器** | QMI8658 六轴 IMU |

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
├── lib/                              # Flutter App 源码
│   ├── main.dart
│   ├── constants/
│   │   └── app_constants.dart
│   ├── models/
│   │   └── game_models.dart
│   ├── providers/
│   │   └── game_provider.dart
│   ├── services/
│   │   ├── game_algorithm.dart
│   │   ├── ble_service.dart
│   │   ├── motion_recognition.dart
│   │   ├── pose_detection_service.dart
│   │   ├── voice_service.dart
│   │   └── food_recognition_service.dart
│   ├── pages/
│   │   ├── welcome_page.dart
│   │   ├── setup_page.dart
│   │   ├── home_page.dart
│   │   ├── food_page.dart
│   │   ├── exercise_page.dart
│   │   ├── stats_page.dart
│   │   └── settings_page.dart
│   └── widgets/
│       ├── hp_bar.dart
│       └── hub_status_dot.dart
├── android/                          # Android 平台配置
├── web/                              # Web 版本源码
│   ├── src/
│   │   ├── App.tsx
│   │   ├── main.tsx
│   │   ├── pages/                    # Web 页面
│   │   ├── components/               # 通用组件
│   │   ├── store/                    # Zustand 状态管理
│   │   └── services/                 # 摄像头/姿态检测服务
│   ├── public/
│   │   └── icon.svg                  # 应用图标
│   ├── Dockerfile                    # 创空间部署配置
│   ├── server.js                     # 静态文件服务器
│   ├── package.json
│   └── vite.config.ts
├── test/
│   └── widget_test.dart
├── pubspec.yaml
├── Dockerfile                        # 根目录创空间构建入口
└── README.md
```

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

构建产物路径：`build/app/outputs/flutter-apk/app-debug.apk`

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

### 依赖清单

```yaml
dependencies:
  flutter_riverpod: ^2.4.0    # 状态管理
  shared_preferences: ^2.2.0  # 本地持久化
  flutter_blue_plus: ^1.15.0  # BLE 蓝牙通信
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
- **每日目标卡路里**：基础代谢 × 活动系数 - 难度调整值

### 战斗机制
- **怪物 HP** = 基础 HP × (1 + 击杀数 × 0.1) × 难度系数 × 体能等级系数
- **饮食影响**：超出目标卡路里 → 怪物回血（超出越多回血越多）
- **锻炼伤害**：消耗卡路里 × 模式系数（高强度加成）
- **疲劳消耗**：锻炼时长 × 疲劳率，累积消耗玩家体力

### 体能等级
根据俯卧撑数量、跑步时长、每周频率综合评定：低 / 中 / 高 三档，影响怪物 HP 与玩家体力上限。

## 开发指南

### 代码规范

- 状态管理统一使用 Riverpod `StateNotifierProvider`
- 数据模型使用 `copyWith` + `toJson`/`fromJson` 模式
- 枚举定义集中在 [app_constants.dart](lib/constants/app_constants.dart)
- 算法逻辑集中在 [game_algorithm.dart](lib/services/game_algorithm.dart)

### 运行测试

```bash
flutter test
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

## 路线图

### App 端
- [x] 第一阶段：Flutter 项目骨架 + 5 步角色创建
- [x] 第二阶段：怪物战斗系统 + 饮食/锻炼追踪
- [x] 第三阶段：BLE 蓝牙集成 + IMU 动作识别
- [x] 第四阶段：Android 模拟器测试通过
- [x] 第五阶段：摄像头姿态识别（MediaPipe Pose）融合
- [x] 第六阶段：语音播报 + 游戏化即时反馈系统
- [ ] 第七阶段：扩展四肢 ESP32+IMU 节点
- [ ] 第八阶段：食物拍照 AI 识别
- [ ] 第九阶段：发布到 Google Play

### Web 端
- [x] Web 版本基础框架（React + Vite + Tailwind）
- [x] 角色创建与怪物战斗系统
- [x] 饮食/锻炼/统计页面
- [x] 成就殿堂 + 每日任务 + 技能系统
- [x] 摄像头姿态检测（MediaPipe Pose）
- [x] 游戏化即时反馈（XP 浮动、连击、升级弹窗）
- [x] 部署到 ModelScope 创空间
- [ ] 食物拍照 AI 识别集成
- [ ] 排行榜与社交分享

## 常见问题

### Q: 为什么选择腰部作为 IMU 佩戴点？
A: 腰部靠近人体重心，能稳定反映步数、深蹲、卷腹等躯干主导动作，且佩戴舒适，适合全天候监测。

### Q: 为什么不一开始就用 5 个 IMU？
A: 多设备方案调试复杂、佩戴繁琐。先用"摄像头 + 一个腰部 IMU"验证核心流程，后续再扩展四肢，符合渐进式迭代原则。

### Q: 没有 ESP32 硬件能运行吗？
A: 可以。应用核心功能（角色创建、饮食/锻炼记录、战斗系统）不依赖硬件，BLE 连接失败时自动降级为纯手动录入模式。

### Q: 支持 iOS 吗？
A: 当前仅支持 Android。iOS 适配在路线图中，主要工作是 BLE 权限与签名配置。

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
  用游戏化的方式，让减肥不再枯燥 💪
</p>
