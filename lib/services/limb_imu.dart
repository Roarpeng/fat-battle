import '../models/game_models.dart';
import 'imu_peak.dart';

/// 多节点 IMU：腰部 Hub + 四肢。架构与协议，不假装已有硬件。
enum ImuNodeId {
  waist,
  leftArm,
  rightArm,
  leftLeg,
  rightLeg,
}

extension ImuNodeIdX on ImuNodeId {
  String get wireName {
    switch (this) {
      case ImuNodeId.waist:
        return 'waist';
      case ImuNodeId.leftArm:
        return 'LA';
      case ImuNodeId.rightArm:
        return 'RA';
      case ImuNodeId.leftLeg:
        return 'LL';
      case ImuNodeId.rightLeg:
        return 'RL';
    }
  }

  String get label {
    switch (this) {
      case ImuNodeId.waist:
        return '腰部 Hub';
      case ImuNodeId.leftArm:
        return '左臂';
      case ImuNodeId.rightArm:
        return '右臂';
      case ImuNodeId.leftLeg:
        return '左腿';
      case ImuNodeId.rightLeg:
        return '右腿';
    }
  }

  /// 广播名：Hub 保持 `ESP32-Hub`；四肢为 `ESP32-Limb-{LA,RA,LL,RL}`。
  String get advertisedName {
    if (this == ImuNodeId.waist) return 'ESP32-Hub';
    return 'ESP32-Limb-$wireName';
  }

  static ImuNodeId? fromAdvertisedName(String name) {
    if (name.contains('ESP32-Hub')) return ImuNodeId.waist;
    if (name.contains('ESP32-Limb-LA')) return ImuNodeId.leftArm;
    if (name.contains('ESP32-Limb-RA')) return ImuNodeId.rightArm;
    if (name.contains('ESP32-Limb-LL')) return ImuNodeId.leftLeg;
    if (name.contains('ESP32-Limb-RL')) return ImuNodeId.rightLeg;
    return null;
  }

  static ImuNodeId? fromWire(int code) {
    if (code < 0 || code >= ImuNodeId.values.length) return null;
    return ImuNodeId.values[code];
  }
}

/// 单节点一帧六轴。
class LimbImuSample {
  final ImuNodeId node;
  final ImuData imu;
  final int? rssi;

  const LimbImuSample({
    required this.node,
    required this.imu,
    this.rssi,
  });
}

/// Hub 聚合帧：一拍内腰 + 0–4 肢。缺肢节点不填，不造假数据。
class AggregatedImuFrame {
  final DateTime timestamp;
  final Map<ImuNodeId, ImuData> nodes;

  const AggregatedImuFrame({
    required this.timestamp,
    required this.nodes,
  });

  ImuData? get waist => nodes[ImuNodeId.waist];

  bool get hasWaist => waist != null;

  int get nodeCount => nodes.length;

  /// 兼容旧腰部路径：没有腰点则 null。
  ImuData? get waistOrNull => waist;
}

/// 线格式：
/// - 旧：12 字节小端 int16 ×6（仅腰）
/// - 新：`0xFB` + count + N×(nodeId u8 + 12 字节 IMU)
class LimbImuCodec {
  static const int aggMagic = 0xFB;
  static const int sampleBytes = 12;

  /// 解析通知 payload。旧 12 字节视为腰部；新聚合帧按节点拆。
  static AggregatedImuFrame? decode(List<int> data, {DateTime? timestamp}) {
    if (data.isEmpty) return null;
    final ts = timestamp ?? DateTime.now();

    if (data.length >= 12 && data[0] != aggMagic) {
      final imu = _parseImu(data, 0);
      if (imu == null) return null;
      return AggregatedImuFrame(
        timestamp: ts,
        nodes: {ImuNodeId.waist: imu},
      );
    }

    if (data[0] != aggMagic || data.length < 2) return null;
    final count = data[1];
    final need = 2 + count * (1 + sampleBytes);
    if (data.length < need) return null;

    final nodes = <ImuNodeId, ImuData>{};
    var offset = 2;
    for (var i = 0; i < count; i++) {
      final id = ImuNodeIdX.fromWire(data[offset]);
      offset += 1;
      final imu = _parseImu(data, offset);
      offset += sampleBytes;
      if (id == null || imu == null) continue;
      nodes[id] = imu;
    }
    if (nodes.isEmpty) return null;
    return AggregatedImuFrame(timestamp: ts, nodes: nodes);
  }

  static ImuData? _parseImu(List<int> data, int offset) {
    if (data.length < offset + sampleBytes) return null;
    int i16(int o) {
      final low = data[o];
      final high = data[o + 1];
      var v = (high << 8) | low;
      if (v >= 0x8000) v -= 0x10000;
      return v;
    }

    return ImuData(
      timestamp: DateTime.now(),
      ax: i16(offset) / 100.0,
      ay: i16(offset + 2) / 100.0,
      az: i16(offset + 4) / 100.0,
      gx: i16(offset + 6) / 10.0,
      gy: i16(offset + 8) / 10.0,
      gz: i16(offset + 10) / 10.0,
    );
  }
}

/// 腰部峰值为主；四肢峰值仅作确认票，缺肢不影响单 Hub。
class LimbImuFusion {
  LimbImuFusion({
    required this.exerciseType,
    DateTime Function()? now,
    this.limbConfirmEnabled = false,
  })  : waist = ImuExercisePeaks.forType(exerciseType, now: now),
        _now = now ?? DateTime.now;

  final String exerciseType;
  final bool limbConfirmEnabled;
  final DateTime Function() _now;
  final ImuPeakCounter waist;
  final Map<ImuNodeId, ImuPeakCounter> limbs = {};

  int fusedCount = 0;
  DateTime? lastFusedAt;

  /// 喂入聚合帧。始终用腰点计次；[limbConfirmEnabled] 时四肢峰值只加置信，不单独加次。
  bool ingest(AggregatedImuFrame frame) {
    final w = frame.waist;
    if (w == null) return false;
    final peaked = waist.ingest(w.accelMagnitude);
    if (limbConfirmEnabled) {
      for (final e in frame.nodes.entries) {
        if (e.key == ImuNodeId.waist) continue;
        final c = limbs.putIfAbsent(
          e.key,
          () => limbPeakCounterFor(exerciseType, now: _now),
        );
        c.ingest(e.value.accelMagnitude);
      }
    }
    if (!peaked) return false;
    fusedCount++;
    lastFusedAt = _now();
    return true;
  }

  void reset() {
    waist.reset();
    for (final c in limbs.values) {
      c.reset();
    }
    fusedCount = 0;
    lastFusedAt = null;
  }
}

/// 四肢节点阈值略低于腰部（杠杆臂更长、冲击更大），仍走同一峰值+不应期。
ImuPeakCounter limbPeakCounterFor(
  String exerciseType, {
  DateTime Function()? now,
}) {
  final waist = ImuExercisePeaks.forType(exerciseType, now: now);
  return ImuPeakCounter(
    peakThreshold: (waist.peakThreshold * 0.85).clamp(1.2, 3.0),
    refractory: waist.refractory,
    now: now,
  );
}
