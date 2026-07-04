# 减肥大作战 Web 版

> 用游戏的方式打赢脂肪战争 — Web 体验版

## 🎮 项目简介

减肥大作战 Web 版是一款游戏化减肥应用的浏览器体验版本，将减肥过程转化为 RPG 打怪冒险。

**核心玩法：**
- 🍽️ **饮食记录** → 怪物回血
- 🏋️ **锻炼攻击** → 对怪物造成伤害
- ⚔️ **击败怪物** → 获得金币，进入下一关

## ✨ 功能特性

### 核心功能
- ✅ 5步角色创建（BMI 计算、体能评估、难度选择）
- ✅ 怪物战斗系统（8种怪物，渐进式难度）
- ✅ 饮食记录（快捷食物、搜索、自定义）
- ✅ 锻炼记录（10种运动、手动模式）
- ✅ 数据统计（体重趋势、本周概览、成就）
- ✅ 本地持久化（localStorage）

### Web 增强功能
- 📷 **摄像头姿态识别** — MediaPipe Pose 实时检测深蹲/俯卧撑
- 📶 **Web Bluetooth** — 连接 ESP32 腰部 Hub 读取 IMU 数据
- 🍔 **食物拍照识别** — AI 识别食物热量
- 🔍 **条码扫描** — 扫描食品条码自动识别
- 📱 **PWA** — 可安装到桌面，离线可用
- 🎨 **暗色游戏风格** — 与 Flutter App 一致的视觉体验

## 🛠️ 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | React 18 + TypeScript |
| 构建工具 | Vite 5 |
| 样式 | Tailwind CSS 4 |
| 状态管理 | Zustand + persist |
| 路由 | React Router v7 |
| 动画 | Framer Motion |
| 图表 | Recharts |
| 图标 | Lucide React |
| PWA | vite-plugin-pwa |
| 姿态识别 | MediaPipe Pose (CDN) |
| 蓝牙 | Web Bluetooth API |
| 条码 | BarcodeDetector API |

## 🚀 快速开始

### 开发
```bash
# 安装依赖
npm install

# 启动开发服务器
npm run dev

# 构建生产版本
npm run build

# 预览生产构建
npm run preview
```

访问 http://localhost:5173

## 📱 兼容性

### 浏览器支持
| 功能 | Chrome | Edge | Safari | Firefox |
|------|--------|------|--------|---------|
| 核心游戏 | ✅ | ✅ | ✅ | ✅ |
| 摄像头姿态识别 | ✅ | ✅ | ✅ | ✅ |
| Web Bluetooth | ✅ | ✅ | ⚠️ 部分 | ❌ |
| 条码扫描 | ✅ | ✅ | ⚠️ 部分 | ❌ |
| PWA | ✅ | ✅ | ✅ | ✅ |

### 蓝牙设备
- 设备：ESP32-S3-Touch-AMOLED-1.43
- Service UUID: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- 数据格式：12字节 IMU 数据（ax/ay/az/gx/gy/gz，int16 小端序）

## 🏗️ 项目结构

```
web/
├── public/              # 静态资源
├── src/
│   ├── components/      # 可复用组件
│   ├── data/            # 数据配置（怪物/食物/运动）
│   ├── lib/             # 工具函数
│   ├── pages/           # 页面组件
│   ├── services/        # 服务层（蓝牙/姿态/识别）
│   ├── store/           # 状态管理
│   ├── types/           # TypeScript 类型
│   ├── App.tsx          # 应用入口
│   ├── main.tsx         # 渲染入口
│   └── index.css        # 全局样式
├── index.html
├── vite.config.ts
├── vercel.json
└── package.json
```

## 🎯 与 App 版的关系

Web 版是 App 版的**零门槛体验入口**：
- 核心游戏机制与 App 版完全对齐
- 支持与 App 版相同的 BLE 硬件连接
- 新增 Web 专属玩法（键盘节奏挑战等）
- 后续可实现数据互通

## 📄 许可证

MIT License
