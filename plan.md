# 减肥大作战 — 实现计划

> 文档版本: v1.0 | 创建日期: 2026-06-19 | 对应PRD: spec.md v2.0

---

## 0. 第一性思考：这个产品的本质是什么

在动手之前，先回到原点。

减肥大作战的本质不是"记录工具加了个皮肤"，而是一个**行为塑造引擎**。它的核心价值循环是：

```
记录行为 → 怪物血量即时变化 → 击败获得奖励 → 期待明天再战
```

这个循环如果断了，所有AI识别、传感器、语音都是空中楼阁。所以实现的第一原则是：**先让核心循环跑通，再叠加智能层**。

第二个关键判断是**平台差异化**。Android/iOS能调用摄像头做实时姿态识别、能融合多传感器、能后台推送；而小程序受限于沙箱环境，摄像头只能拍照不能实时分析，传感器接口有限，后台能力弱。强行让小程序实现全部功能，要么做不到，要么体验极差。所以第二原则是：**App做全量，小程序做轻量核心版**，共享后端和游戏逻辑。

---

## 1. 技术选型

### 1.1 选型决策

| 层 | 选型 | 理由 |
|----|------|------|
| App端（Android/iOS） | Flutter | 单代码库双端发布；摄像头/传感器/动画性能好；Dart语言适合游戏状态管理 |
| 小程序端 | Taro 3 (React语法) | 可与App端共享TypeScript游戏逻辑层；多端编译能力强 |
| 后端 | Node.js (NestJS) | 与前端同语言；适合高并发IO；NestJS提供规范架构 |
| 数据库 | PostgreSQL + Redis | PG存用户/游戏数据；Redis存排行榜/会话/缓存 |
| AI服务 | Python (FastAPI) | 食物识别/动作识别模型部署；与Node后端通过HTTP通信 |
| 对象存储 | 阿里云OSS / AWS S3 | 存食物照片、用户头像 |
| 推送 | FCM (Android) + APNs (iOS) + 小程序订阅消息 | 三端推送 |

### 1.2 代码复用策略

```
┌──────────────────────────────────────────────────┐
│              共享层 (TypeScript)                  │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────┐ │
│  │ 游戏逻辑  │ │ 数据模型  │ │ API客户端(SDK)   │ │
│  │ (pure ts)│ │ (types)  │ │ (http client)    │ │
│  └──────────┘ └──────────┘ └──────────────────┘ │
│         共享 npm package: @fatbattle/core        │
└──────────────────────────────────────────────────┘
         │                          │
    ┌────┴────┐               ┌────┴────┐
    │ Flutter │               │  Taro   │
    │  App    │               │ 小程序   │
    │(Dart桥接)│               │(React)  │
    └─────────┘               └─────────┘
```

**共享层包含：**
- 游戏核心逻辑：BMI计算、怪物血量公式、伤害计算、每日结算、赛季逻辑
- 数据模型定义：User、Monster、FoodRecord、ExerciseRecord等TypeScript类型
- API客户端：封装所有后端接口调用

**Flutter端独有：**
- 摄像头实时姿态识别（MediaPipe / Google ML Kit）
- 多传感器融合（GPS + 加速度计 + 陀螺仪 + 气压计）
- TTS/ASR语音交互
- 复杂动画（怪物战斗、血条、粒子效果）

**小程序端独有：**
- 微信生态能力（订阅消息、分享、登录）
- 简化版提醒（订阅消息推送）
- 无摄像头实时分析，仅支持拍照上传识别

---

## 2. 平台功能矩阵

| 功能 | Flutter App | 小程序 | 说明 |
|------|------------|--------|------|
| 角色创建（5步） | 全量 | 全量 | 纯表单，两端一致 |
| 手动饮食记录 | 全量 | 全量 | 核心功能 |
| 食物拍照识别 | 拍照+实时 | 拍照上传 | 小程序不支持实时分析 |
| 分量调整 | 全量 | 全量 | |
| 混合场景估算 | 全量 | 全量 | |
| 室内锻炼-摄像头识别 | 实时姿态 | 不支持 | 小程序无法实时分析 |
| 室内锻炼-手动模式 | 全量 | 全量 | 核心兜底 |
| 室外锻炼-传感器 | 全传感器 | GPS+加速度计 | 小程序传感器接口有限 |
| 怪物战斗系统 | 全量+动画 | 全量+简化动画 | |
| 赛季制 | 全量 | 全量 | |
| 智能提醒 | 本地通知+推送 | 订阅消息 | 小程序后台能力弱 |
| 勿扰模式/场景感知 | 全量 | 基础勿扰 | |
| 语音播报 | TTS全量 | 不支持 | 小程序无TTS能力 |
| 语音指令 | ASR全量 | 不支持 | |
| 排行榜 | 全量 | 全量 | |
| 成就/徽章 | 全量 | 全量 | |
| 维护模式 | 全量 | 全量 | |
| 离线可用 | 全量 | 不支持 | 小程序需联网 |

---

## 3. 数据模型设计

### 3.1 核心实体

```typescript
// ===== 用户 =====
interface User {
  id: string;
  phone: string;           // 手机号登录
  nickname: string;
  avatar: string;          // 头像URL
  // 基本信息设置
  height: number;          // cm
  weight: number;          // kg（当前，动态更新）
  targetWeight: number;    // kg
  bmi: number;             // 计算值
  // 生活习惯
  sleepType: 'early' | 'normal' | 'night_owl';
  workType: 'sedentary' | 'occasional_walk' | 'frequent_outdoor';
  exerciseTime: 'morning' | 'evening' | 'night' | 'flexible';
  characterStyle: 'warrior' | 'mage' | 'pet' | 'assassin';
  // 体能评估
  fitnessLevel: 'low' | 'medium' | 'high';
  pushupCount: number;     // 俯卧撑个数
  runDuration: number;     // 跑步时长(分钟)
  weeklyExerciseFreq: number;
  // 难度
  difficulty: 'easy' | 'normal' | 'hard';
  // 游戏状态
  day: number;             // 第几天
  coins: number;           // 金币
  kills: number;           // 击败怪物数
  totalDamage: number;     // 总伤害
  totalExercise: number;   // 总锻炼消耗(kcal)
  streak: number;          // 连续打卡天数
  shieldCount: number;     // 护盾数（断签缓冲）
  restDaysLeft: number;    // 本月剩余休息日
  // 状态
  status: 'active' | 'maintenance'; // 减肥中 / 维护模式
  createdAt: string;
  updatedAt: string;
}

// ===== 每日状态 =====
interface DailyState {
  id: string;
  userId: string;
  date: string;            // YYYY-MM-DD
  day: number;             // 第几天
  // 怪物
  monsterId: string;       // 当前怪物配置ID
  monsterMaxHp: number;
  monsterHp: number;       // 当前血量
  monsterLevel: number;
  // 玩家
  playerMaxHp: number;
  playerHp: number;
  // 今日数据
  todayCalIn: number;      // 摄入
  todayCalExercise: number; // 锻炼消耗
  todayDamage: number;     // 对怪物造成的伤害
  targetCal: number;       // 今日目标
  // 结算
  settled: boolean;        // 是否已结算
  killed: boolean;         // 是否击败
  coinsEarned: number;     // 获得金币
}

// ===== 食物记录 =====
interface FoodRecord {
  id: string;
  userId: string;
  date: string;
  meal: 'breakfast' | 'lunch' | 'dinner' | 'snack';
  items: FoodItem[];
  totalCal: number;
  source: 'manual' | 'ai_photo' | 'ai_voice' | 'mixed';
  photoUrl?: string;       // 拍照识别时的图片
  createdAt: string;
}

interface FoodItem {
  name: string;
  cal: number;             // 基础卡路里
  portion: 'small' | 'medium' | 'large';
  actualCal: number;       // 根据分量调整后的卡路里
}

// ===== 锻炼记录 =====
interface ExerciseRecord {
  id: string;
  userId: string;
  date: string;
  type: 'indoor' | 'outdoor';
  // 室内
  exerciseName?: string;   // 俯卧撑/深蹲等
  count?: number;          // 个数
  duration?: number;       // 时长(秒)
  mode?: 'camera' | 'manual'; // 摄像头/手动
  // 室外
  outdoorType?: 'running' | 'walking' | 'cycling' | 'stairs';
  distance?: number;       // 距离(km)
  track?: string;          // GPS轨迹(JSON)
  // 通用
  cal: number;             // 消耗卡路里
  damage: number;          // 对怪物造成的伤害
  accuracyScore?: number;  // 动作标准度(摄像头模式)
  createdAt: string;
}

// ===== 怪物配置 =====
interface MonsterConfig {
  id: string;
  name: string;
  emoji: string;
  baseHp: number;
  level: number;
  healRateBonus: number;   // 回血加成系数
  season: string;          // 赛季标识
  description: string;
}

// ===== 成就 =====
interface Achievement {
  id: string;
  userId: string;
  type: 'first_kill' | 'streak_7' | 'streak_30' | 'diet_master' | 'exercise_master' | 'weight_goal' | 'season_champion';
  unlockedAt: string;
  metadata?: any;
}

// ===== 体重记录 =====
interface WeightRecord {
  id: string;
  userId: string;
  date: string;
  weight: number;
  source: 'manual' | 'scale_bluetooth';
}
```

### 3.2 核心算法（共享层）

```typescript
// ===== BMI计算 =====
function calcBMI(weightKg: number, heightCm: number): number {
  return weightKg / Math.pow(heightCm / 100, 2);
}

// ===== 体型判断 =====
function getBodyType(bmi: number): string {
  if (bmi < 18.5) return '偏瘦';
  if (bmi < 24) return '正常';
  if (bmi < 28) return '偏胖';
  return '肥胖';
}

// ===== 目标卡路里 =====
function calcTargetCal(weightKg: number, difficulty: string): number {
  const base = Math.round(weightKg * 24);
  if (difficulty === 'easy') return base + 200;
  if (difficulty === 'hard') return base - 400;
  return base;
}

// ===== 怪物初始血量 =====
function calcMonsterHp(baseHp: number, difficulty: string, fitnessLevel: string): number {
  let hp = baseHp;
  if (difficulty === 'easy') hp *= 0.8;
  if (difficulty === 'hard') hp *= 1.3;
  if (fitnessLevel === 'low') hp *= 0.8;
  if (fitnessLevel === 'high') hp *= 1.1;
  return Math.round(hp);
}

// ===== 饮食对怪物的影响 =====
function foodImpactOnMonster(cal: number, todayCalIn: number, targetCal: number, monsterMaxHp: number) {
  const baseHeal = Math.round(cal * 0.05);
  let overageHeal = 0;
  const oldCal = todayCalIn - cal;
  if (oldCal <= targetCal && todayCalIn > targetCal) {
    const over = todayCalIn - targetCal;
    overageHeal = Math.round(over * 0.3);
  }
  const totalHeal = baseHeal + overageHeal;
  return {
    heal: totalHeal,
    newMonsterHp: Math.min(monsterMaxHp, /* currentHp + */ totalHeal),
    isOverage: overageHeal > 0
  };
}

// ===== 锻炼对怪物的影响 =====
function exerciseImpactOnMonster(cal: number, mode: 'camera' | 'manual'): number {
  const baseDamage = Math.round(cal * 0.8);
  if (mode === 'manual') return Math.round(baseDamage * 0.8); // 手动模式降20%
  return baseDamage;
}

// ===== 7日移动平均体重 =====
function calcWeightMovingAverage(records: WeightRecord[]): number {
  const recent = records.slice(-7);
  if (recent.length === 0) return 0;
  return recent.reduce((sum, r) => sum + r.weight, 0) / recent.length;
}

// ===== 断签缓冲判断 =====
function checkStreakShield(streak: number, shieldCount: number): boolean {
  if (streak >= 7 && shieldCount > 0) return true; // 有护盾
  return false;
}

// ===== 赛季判断 =====
function getCurrentSeason(date: Date): string {
  const month = date.getMonth() + 1;
  if (month >= 1 && month <= 3) return 'spring_festival';
  if (month >= 4 && month <= 6) return 'summer';
  if (month >= 7 && month <= 9) return 'back_to_school';
  return 'year_end';
}
```

---

## 4. API设计

### 4.1 接口列表

| 方法 | 路径 | 说明 | 端 |
|------|------|------|-----|
| POST | /api/auth/login | 手机号登录 | App+小程序 |
| POST | /api/user/setup | 角色创建（5步提交） | App+小程序 |
| GET | /api/user/profile | 获取用户信息 | App+小程序 |
| PUT | /api/user/weight | 更新体重 | App+小程序 |
| PUT | /api/user/settings | 更新设置（难度/勿扰等） | App+小程序 |
| GET | /api/daily/today | 获取今日状态（怪物/血量/数据） | App+小程序 |
| POST | /api/daily/settle | 每日结算 | App+小程序 |
| POST | /api/daily/next | 进入下一天 | App+小程序 |
| GET | /api/food/records?date= | 获取某日饮食记录 | App+小程序 |
| POST | /api/food/records | 添加饮食记录 | App+小程序 |
| DELETE | /api/food/records/:id | 删除饮食记录 | App+小程序 |
| POST | /api/food/recognize | 食物拍照识别（上传图片） | App+小程序 |
| POST | /api/food/mixed-estimate | 混合场景估算 | App+小程序 |
| GET | /api/exercise/records?date= | 获取某日锻炼记录 | App+小程序 |
| POST | /api/exercise/records | 添加锻炼记录 | App+小程序 |
| DELETE | /api/exercise/records/:id | 删除锻炼记录 | App+小程序 |
| GET | /api/monster/config | 获取怪物配置 | App+小程序 |
| GET | /api/stats/overview | 统计概览 | App+小程序 |
| GET | /api/stats/weekly | 本周概览 | App+小程序 |
| GET | /api/stats/weight-trend | 体重趋势（7日移动平均） | App+小程序 |
| GET | /api/achievements | 成就列表 | App+小程序 |
| GET | /api/leaderboard?type= | 排行榜 | App+小程序 |
| POST | /api/coins/spend | 消费金币 | App+小程序 |
| POST | /api/reminder/settings | 提醒设置 | App+小程序 |
| POST | /api/status/mark | 标记状态（加班/出差/勿扰） | App+小程序 |

### 4.2 关键接口设计

**POST /api/user/setup — 角色创建**

```json
// Request
{
  "height": 170,
  "weight": 75,
  "targetWeight": 65,
  "sleepType": "night_owl",
  "workType": "sedentary",
  "exerciseTime": "evening",
  "characterStyle": "pet",
  "fitnessLevel": "medium",
  "pushupCount": 15,
  "runDuration": 15,
  "weeklyExerciseFreq": 3,
  "difficulty": "normal"
}

// Response
{
  "userId": "xxx",
  "bmi": 26.0,
  "bodyType": "偏胖",
  "targetCal": 1800,
  "monster": {
    "id": "slime_001",
    "name": "贪吃史莱姆",
    "emoji": "👾",
    "maxHp": 100,
    "level": 1
  },
  "day": 1
}
```

**POST /api/food/recognize — 食物识别**

```json
// Request: multipart/form-data
// file: 食物照片
// meal: breakfast

// Response
{
  "items": [
    {"name": "米饭", "cal": 230, "confidence": 0.92},
    {"name": "鸡腿", "cal": 180, "confidence": 0.88},
    {"name": "炒青菜", "cal": 80, "confidence": 0.85}
  ],
  "totalCal": 490,
  "suggestions": [
    {"type": "good", "text": "青菜比例很好，继续保持！"},
    {"type": "warning", "text": "米饭可以减半，换成粗粮更佳"}
  ]
}
```

---

## 5. 实现阶段

### Phase 0: 基础架构（第1-2周）

**目标：** 搭建项目骨架，跑通"Hello World"级别的全链路。

| 任务 | 说明 | 产出 |
|------|------|------|
| Flutter项目初始化 | 项目结构、路由、状态管理(Riverpod)、主题 | 可运行的空App |
| Taro小程序初始化 | 项目结构、页面路由、状态管理 | 可运行的空小程序 |
| NestJS后端初始化 | 项目结构、数据库连接、JWT认证中间件 | 可运行的后端骨架 |
| PostgreSQL建表 | 按数据模型创建所有表 | 数据库schema |
| 共享层npm包 | TypeScript游戏逻辑、数据模型、API客户端 | @fatbattle/core包 |
| CI/CD | GitHub Actions: Flutter构建、后端部署 | 自动化流水线 |

**验收标准：** Flutter App能登录后端，小程序能登录后端，数据库表创建完成。

---

### Phase 1: 核心游戏循环（第3-6周）

**目标：** 让"记录→战斗→奖励→下一天"这个循环完整跑通。这是产品的命脉，没有这个什么都没用。

#### Sprint 1（第3周）：角色创建 + 游戏状态

| 任务 | 平台 | 详情 |
|------|------|------|
| 角色创建5步流程 | App+小程序 | 基本信息→生活习惯→体能评估→难度选择→生成关卡 |
| BMI计算 | 共享层 | 实现calcBMI、getBodyType、calcTargetCal |
| 怪物生成 | 共享层 | 根据BMI/难度/体能生成初始怪物 |
| 用户信息存储 | 后端 | POST /api/user/setup, GET /api/user/profile |
| 今日状态获取 | 后端 | GET /api/daily/today |

**关键决策：** 角色创建流程必须极简。5步问卷每步只问1个问题，用户3分钟内完成。任何让用户填超过5分钟的设计都是失败的。

#### Sprint 2（第4周）：饮食记录 + 怪物血量联动

| 任务 | 平台 | 详情 |
|------|------|------|
| 饮食记录页 | App+小程序 | 4餐分区、快捷食物、手动添加、分量调整 |
| 食物数据库 | 后端 | 预置200+常见食物卡路里数据 |
| 饮食→怪物影响 | 共享层 | foodImpactOnMonster算法 |
| 血条动画 | App | 怪物血量变化动画、伤害飘字、回血效果 |
| 血条简化展示 | 小程序 | 基础血条展示（无复杂动画） |
| 饮食记录CRUD | 后端 | 增删改查接口 |

**关键决策：** 快捷食物列表要接地气。不是"鸡胸肉沙拉"，而是"黄焖鸡米饭""螺蛳粉""煎饼果子"。用户看到自己常吃的才会点。

#### Sprint 3（第5周）：锻炼记录 + 伤害计算

| 任务 | 平台 | 详情 |
|------|------|------|
| 锻炼页-手动模式 | App+小程序 | 8种动作选择、数量输入、计时、语音计数 |
| 锻炼→怪物影响 | 共享层 | exerciseImpactOnMonster算法 |
| 锻炼记录CRUD | 后端 | 增删改查接口 |
| 今日战况汇总 | App+小程序 | 摄入/消耗/净摄入/伤害汇总 |

**关键决策：** MVP阶段锻炼只做手动模式。摄像头识别是Phase 2的事，不要在Phase 1纠结。先让用户能记录锻炼、能打怪。

#### Sprint 4（第6周）：每日结算 + 统计页

| 任务 | 平台 | 详情 |
|------|------|------|
| 每日结算逻辑 | 共享层 | 24:00结算、胜负判定、金币奖励、连续打卡 |
| 断签缓冲 | 共享层 | 护盾机制、休息日机制 |
| 下一天生成 | 后端 | 新怪物生成、数据重置 |
| 统计页 | App+小程序 | 减肥进度、战斗数据、本周概览 |
| 体重记录 | App+小程序 | 手动输入体重、7日移动平均 |
| 离线缓存 | App | 本地SQLite缓存，断网可记录，联网同步 |

**关键决策：** 每日结算时间不是硬性24:00。用户可能深夜才打开App，结算时机应该是"用户当天首次打开App时检查昨日是否已结算"。这样不会漏掉夜猫子用户。

**Phase 1验收标准：**
- 用户能完成角色创建，生成专属怪物
- 能记录饮食和锻炼，怪物血量实时变化
- 能击败怪物，获得金币，进入下一天
- 能查看统计页
- App端支持离线记录
- 小程序端核心循环可用

---

### Phase 2: 智能层（第7-10周）

**目标：** 在核心循环跑通的基础上，叠加AI识别、智能提醒、语音交互，降低使用门槛、提升体验。

#### Sprint 5（第7周）：食物拍照识别

| 任务 | 平台 | 详情 |
|------|------|------|
| 食物识别模型 | AI服务 | 训练/接入食物识别模型（可先用第三方API） |
| 拍照页 | App | 摄像头拍照、上传、识别结果展示 |
| 拍照页 | 小程序 | wx.chooseImage拍照、上传、识别结果展示 |
| 分量调整 | App+小程序 | 识别后用户可调整分量，重新计算卡路里 |
| 混合场景估算 | App+小程序 | 火锅/自助餐食材清单勾选 |
| 饮食建议引擎 | 后端 | 基于营养结构生成建议文本 |

**关键决策：** 食物识别准确率初期可能只有70-80%。这没关系，关键是让用户能快速修正。识别结果出来后，用户可以增删食物条目、调整分量。比"识别准但慢"更重要的是"识别快但可修正"。

#### Sprint 6（第8周）：摄像头动作识别（App独有）

| 任务 | 平台 | 详情 |
|------|------|------|
| 姿态识别集成 | App | MediaPipe Pose / Google ML Kit Pose Detection |
| 动作判断算法 | App | 8种动作的关节角度判断逻辑 |
| 实时overlay | App | 骨骼关键点绘制、姿势正确/错误提示 |
| 语音引导 | App | 动作计数、纠正提示、鼓励语 |
| 安全机制 | App | 热身提醒、风险评级确认、疲劳检测 |
| 无摄像头模式 | App | 兜底：手动选择动作+语音计数 |

**关键决策：** 动作识别在端侧完成，不上传视频到云端。一是隐私，二是延迟。MediaPipe Pose在手机端能跑到30fps，足够实时反馈。

#### Sprint 7（第9周）：智能提醒系统

| 任务 | 平台 | 详情 |
|------|------|------|
| 本地通知引擎 | App | 基于作息的餐饮提醒、办公健康提醒调度 |
| 订阅消息 | 小程序 | 微信订阅消息推送（需用户授权） |
| 勿扰模式 | App+小程序 | 时段设置、静默通知 |
| 场景感知 | App | 蓝牙耳机检测、外放/静音检测、通话检测 |
| 状态标记 | App+小程序 | 加班/出差/勿扰手动标记 |
| 提醒规则引擎 | 共享层 | 根据作息/办公方式/状态生成提醒计划 |

**关键决策：** 小程序的订阅消息有次数限制（每次授权只能推1条），所以小程序端提醒策略要更保守——只推关键提醒（餐饮记录、锻炼提醒），不推站立/喝水这种高频低价值的。

#### Sprint 8（第10周）：语音交互（App独有）

| 任务 | 平台 | 详情 |
|------|------|------|
| TTS引擎集成 | App | Flutter TTS插件，支持多角色音色参数 |
| 语音播报场景 | App | 提醒/指导/鼓励/庆祝/安慰/报告6类语音 |
| ASR语音指令 | App | "开始锻炼""记录早餐""今天战绩"等指令 |
| 角色语音包 | 后端 | 4种角色风格的语音文案模板 |
| 智能场景检测 | App | 蓝牙耳机→正常播报；外放→降音量；静音→震动 |

**关键决策：** TTS用系统自带引擎即可（iOS AVSpeechSynthesizer / Android TextToSpeech），不需要花钱买第三方。音色差异通过语速、音调参数调整来模拟"热血/冷静/可爱/神秘"四种风格。

**Phase 2验收标准：**
- App端能拍照识别食物，准确率>=75%
- App端能通过摄像头识别8种锻炼动作，延迟<=200ms
- App端能语音播报提醒和鼓励，支持4种角色风格
- 两端都能接收智能提醒，支持勿扰模式
- 小程序端能拍照上传识别食物

---

### Phase 3: 社交与长期留存（第11-14周）

**目标：** 让用户留下来。核心循环解决了"首次体验"，智能层解决了"便利性"，这一层解决"长期动力"。

#### Sprint 9（第11周）：室外运动 + 传感器

| 任务 | 平台 | 详情 |
|------|------|------|
| GPS轨迹记录 | App | 后台GPS追踪、轨迹绘制、距离计算 |
| 计步器 | App | 加速度计计步、步频计算 |
| 运动类型识别 | App | 跑步/快走/骑行/爬楼自动判断 |
| 卡路里计算 | 共享层 | 速度×体重×时间×系数 |
| 小程序版 | 小程序 | wx.startLocationUpdate + 加速度计（简化版） |
| 地图轨迹展示 | App+小程序 | 轨迹回放、配速/步频展示 |

**关键决策：** GPS耗电是室外运动的最大痛点。策略是：仅在用户主动开始"室外锻炼"时才开启GPS，结束后立即关闭。不做全天候步数追踪（那是微信运动的事）。

#### Sprint 10（第12周）：排行榜 + 成就系统

| 任务 | 平台 | 详情 |
|------|------|------|
| 排行榜 | 后端 | Redis Sorted Set实现，支持BMI分组 |
| 排行榜页 | App+小程序 | 周榜/月榜、好友/全区、可见范围设置 |
| 成就系统 | 后端 | 成就触发条件检测、解锁通知 |
| 成就页 | App+小程序 | 徽章展示、解锁动画 |
| 金币消费 | 后端 | 虚拟装扮/补签卡/公益捐赠 |
| 商店页 | App+小程序 | 金币消费商城 |

**关键决策：** 排行榜默认"仅自己可见"。用户主动选择加入排行后才显示在榜单上。避免新用户一进来就看到自己排名垫底而流失。

#### Sprint 11（第13周）：赛季制 + 维护模式

| 任务 | 平台 | 详情 |
|------|------|------|
| 赛季配置 | 后端 | 4个赛季主题、怪物配置、特殊机制 |
| 赛季切换 | 共享层 | 自动判断当前赛季、赛季结算 |
| 赛季UI | App+小程序 | 主题切换、赛季倒计时、赛季奖励 |
| 维护模式触发 | 共享层 | 达到目标体重自动切换 |
| 脂肪怪进攻 | 共享层 | 每3天一次防御战机制 |
| 塑形关卡 | 共享层 | 增肌方向可选开启 |

**关键决策：** 赛季制不是必须4个赛季全做完才上线。先做1个赛季（当前季节对应的），验证用户对主题变化的反应，再补齐其他赛季。

#### Sprint 12（第14周）：打磨 + 性能优化

| 任务 | 平台 | 详情 |
|------|------|------|
| 动画优化 | App | 怪物战斗动画、粒子效果、过渡动画 |
| 离线同步 | App | 冲突解决策略、断网重连 |
| 性能优化 | App+小程序 | 启动速度、列表滚动、内存管理 |
| 埋点接入 | App+小程序 | 所有埋点事件接入数据平台 |
| 崩溃监控 | App+小程序 | Sentry接入 |
| A/B测试框架 | 后端 | 难度系数、提醒频率等参数A/B测试 |

**Phase 3验收标准：**
- App端能记录室外运动（GPS轨迹+卡路里）
- 两端都有排行榜和成就系统
- 赛季制生效，当前赛季主题正常
- 维护模式可触发
- App启动<=3秒，动作识别延迟<=200ms
- 所有埋点事件正常上报

---

### Phase 4: 小程序适配收尾（第15-16周）

**目标：** 小程序版从"能用"升级到"好用"。

| 任务 | 说明 |
|------|------|
| 小程序UI打磨 | 适配小程序设计规范、加载优化 |
| 分享能力 | 战绩分享到微信好友/朋友圈（拉新） |
| 订阅消息优化 | 精简推送策略，在次数限制内最大化触达 |
| 小程序登录 | 微信一键登录，绑定手机号 |
| 小程序数据同步 | 与App端数据互通（同一账号） |
| 小程序审核 | 提交微信审核，处理审核反馈 |

**关键决策：** 小程序的核心价值是**拉新入口**。用户在朋友圈看到好友分享"我击败了脂肪巨魔！"，点进小程序就能玩，不需要下载App。所以小程序的分享卡片设计至关重要——要让人有点击欲望。

---

## 6. 团队配置建议

| 角色 | 人数 | 职责 | 阶段 |
|------|------|------|------|
| Flutter开发 | 2 | App端开发 | Phase 1-3 |
| 小程序开发 | 1 | Taro小程序开发 | Phase 1, 4 |
| 后端开发 | 1 | NestJS API + 数据库 | Phase 1-3 |
| AI开发 | 1 | 食物识别/动作识别模型 | Phase 2 |
| UI设计 | 1 | 界面设计、动画设计 | 全程 |
| 产品/测试 | 1 | 需求管理、测试验收 | 全程 |

**最小启动配置：** 1 Flutter + 1后端 + 1设计，3人即可启动Phase 1。

---

## 7. 风险与应对

| 风险 | 概率 | 影响 | 应对 |
|------|------|------|------|
| 食物识别准确率不足 | 高 | 高 | MVP以手动为主，AI为辅；提供分量调整和手动修正 |
| 动作识别延迟超标 | 中 | 中 | 端侧模型优化；提供无摄像头模式兜底 |
| 小程序审核被拒 | 中 | 中 | 提前研究审核规范；避免"减肥"敏感词，用"健康管理"替代 |
| GPS耗电过快 | 高 | 中 | 仅锻炼时开启GPS；提供"省电模式"降低采样率 |
| 用户3天流失（核心风险） | 高 | 极高 | Phase 1上线后立即观察次日留存；如果<40%，优先优化新手引导和首日体验 |
| 后端并发压力 | 低 | 中 | Phase 1-2用户量小，单机够用；Phase 3引入Redis缓存和读写分离 |

---

## 8. 里程碑

| 里程碑 | 时间 | 交付物 | 验收标准 |
|--------|------|--------|---------|
| M0: 架构就绪 | 第2周末 | 项目骨架 | 三端可通信 |
| M1: 核心循环可用 | 第6周末 | MVP版本 | 核心循环跑通，可内测 |
| M2: 智能版可用 | 第10周末 | Beta版本 | AI识别+提醒+语音上线 |
| M3: 全功能版 | 第14周末 | GA版本 | 全功能上线，可公测 |
| M4: 小程序上线 | 第16周末 | 小程序版 | 小程序审核通过 |

---

## 9. 度量与迭代

### 9.1 上线后核心看板

| 指标 | Phase 1目标 | Phase 2目标 | Phase 3目标 |
|------|------------|------------|------------|
| 次日留存 | >= 40% | >= 50% | >= 60% |
| 7日留存 | >= 20% | >= 30% | >= 35% |
| 饮食记录率 | >= 50% | >= 60% | >= 70% |
| 怪物击败率 | >= 40% | >= 50% | >= 60% |

### 9.2 迭代节奏

- **每周：** 看核心指标，发现异常立即排查
- **每两周：** 发一个小版本，修复问题+小优化
- **每月：** 发一个中版本，包含1-2个新功能
- **每赛季（3个月）：** 发一个大版本，赛季主题更新+重大功能

### 9.3 如果留存不达标怎么办

| 现象 | 诊断 | 行动 |
|------|------|------|
| 次日留存<30% | 新手引导有问题 | 简化角色创建流程；首日怪物血量降低50%让用户必赢 |
| 7日留存<15% | 核心循环不够上瘾 | 增加首周怪物多样性；加大首周金币奖励 |
| 饮食记录率<40% | 记录太麻烦 | 优先上线食物识别；增加更多快捷食物 |
| 怪物击败率<30% | 难度太高 | 动态难度调整：连续3天未击败，怪物血量自动降低20% |

---

*本计划将根据开发进展和用户反馈持续调整。核心原则：先跑通循环，再叠加智能，最后做长期留存。*
