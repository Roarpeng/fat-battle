# 四肢 IMU 协议（腰部 Hub + 4 肢）

> 架构与线格式。当前发售硬件仍是**单个腰部 ESP32-Hub**。四肢节点是预留发现/融合钩子，不假装已连接设备。

## 节点

| 节点 | 广播名 | `ImuNodeId` | 说明 |
|------|--------|-------------|------|
| 腰部 Hub | `ESP32-Hub` | `waist` | 现网唯一主连接 |
| 左臂 | `ESP32-Limb-LA` | `leftArm` | 仅 `coach_limb_imu_enabled` 时扫描 |
| 右臂 | `ESP32-Limb-RA` | `rightArm` | 同上，**不自动连接** |
| 左腿 | `ESP32-Limb-LL` | `leftLeg` | 同上 |
| 右腿 | `ESP32-Limb-RL` | `rightLeg` | 同上 |

GATT 与现网一致：

- Service `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- Notify IMU `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- Write command `6e400002-b5a3-f393-e0a9-e50e24dcca9e`

## 线格式

### 旧（单 Hub，保持兼容）

12 字节小端 `int16`：`ax ay az gx gy gz`（加速度 0.01g，角速度 0.1°/s）。端侧仍映射为 `ImuData`，走腰部峰值计数。

### 新（Hub 聚合，可选）

| 偏移 | 字段 | 说明 |
|------|------|------|
| 0 | `0xFB` | 聚合魔数 |
| 1 | `count` | 本帧节点数 1–5 |
| 2+ | `nodeId` + 12 字节 IMU | `0=waist … 4=rightLeg` |

缺肢节点不填，不造假样本。解析见 `LimbImuCodec.decode`。

## 融合钩子

`LimbImuFusion.ingest`：

1. **腰部**仍用 `ImuPeakCounter`（与现网相同阈值/不应期）。
2. 四肢峰值仅在 `limbConfirmEnabled` 时记确认票，**不加次数**。
3. 没有腰点的帧直接丢弃，保证单 Hub 路径不变。

开关：SharedPreferences `coach_limb_imu_enabled`（锻炼页「高级选项」）。
