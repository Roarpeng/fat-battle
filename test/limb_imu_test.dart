import 'package:flutter_test/flutter_test.dart';
import 'package:fat_battle/models/game_models.dart';
import 'package:fat_battle/services/limb_imu.dart';

List<int> _i16le(int value) {
  final v = value < 0 ? value + 0x10000 : value;
  return [v & 0xFF, (v >> 8) & 0xFF];
}

List<int> _imuBytes({
  int ax = 100,
  int ay = 0,
  int az = 0,
  int gx = 0,
  int gy = 0,
  int gz = 0,
}) {
  return [
    ..._i16le(ax),
    ..._i16le(ay),
    ..._i16le(az),
    ..._i16le(gx),
    ..._i16le(gy),
    ..._i16le(gz),
  ];
}

void main() {
  group('LimbImuCodec', () {
    test('12 字节旧包仍解析为腰部 Hub', () {
      final frame = LimbImuCodec.decode(_imuBytes(ax: 150));
      expect(frame, isNotNull);
      expect(frame!.hasWaist, isTrue);
      expect(frame.nodeCount, 1);
      expect(frame.waist!.ax, closeTo(1.5, 0.001));
    });

    test('0xFB 聚合帧拆出腰 + 左臂，缺肢不造假', () {
      final payload = <int>[
        LimbImuCodec.aggMagic,
        2,
        ImuNodeId.waist.index,
        ..._imuBytes(ax: 200),
        ImuNodeId.leftArm.index,
        ..._imuBytes(ax: 80),
      ];
      final frame = LimbImuCodec.decode(payload)!;
      expect(frame.nodes.keys, containsAll([ImuNodeId.waist, ImuNodeId.leftArm]));
      expect(frame.nodes.containsKey(ImuNodeId.rightLeg), isFalse);
      expect(frame.waist!.ax, closeTo(2.0, 0.001));
    });

    test('残缺聚合帧返回 null', () {
      expect(LimbImuCodec.decode([LimbImuCodec.aggMagic, 3]), isNull);
    });
  });

  group('广播名', () {
    test('Hub 与四肢前缀可解析，未知名忽略', () {
      expect(ImuNodeIdX.fromAdvertisedName('ESP32-Hub'), ImuNodeId.waist);
      expect(ImuNodeIdX.fromAdvertisedName('ESP32-Limb-RL'), ImuNodeId.rightLeg);
      expect(ImuNodeIdX.fromAdvertisedName('Random'), isNull);
      expect(ImuNodeId.leftArm.advertisedName, 'ESP32-Limb-LA');
    });
  });

  group('LimbImuFusion', () {
    test('只有腰点峰值才加次；缺腰不加', () {
      var t = DateTime(2026, 1, 1);
      final fusion = LimbImuFusion(
        exerciseType: 'squat',
        now: () => t,
        limbConfirmEnabled: true,
      );
      fusion.ingest(
        AggregatedImuFrame(
          timestamp: t,
          nodes: {
            ImuNodeId.waist: ImuData(timestamp: t, ax: 0.2, ay: 0, az: 0),
          },
        ),
      );
      t = t.add(const Duration(milliseconds: 20));
      fusion.ingest(
        AggregatedImuFrame(
          timestamp: t,
          nodes: {
            ImuNodeId.waist: ImuData(timestamp: t, ax: 2.4, ay: 0, az: 0),
          },
        ),
      );
      t = t.add(const Duration(milliseconds: 20));
      final peaked = fusion.ingest(
        AggregatedImuFrame(
          timestamp: t,
          nodes: {
            ImuNodeId.waist: ImuData(timestamp: t, ax: 0.4, ay: 0, az: 0),
          },
        ),
      );
      expect(peaked, isTrue);
      expect(fusion.fusedCount, 1);

      expect(
        fusion.ingest(
          AggregatedImuFrame(
            timestamp: t,
            nodes: {
              ImuNodeId.leftArm: ImuData(timestamp: t, ax: 3.0),
            },
          ),
        ),
        isFalse,
      );
      expect(fusion.fusedCount, 1);
    });
  });
}
