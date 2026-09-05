import 'package:flutter_test/flutter_test.dart';
import 'package:fat_battle/services/tflite_accel.dart';

void main() {
  test('加速结果标签：CPU / GPU / NNAPI', () {
    const cpu = TfliteAccelResult(
      gpuRequested: false,
      gpuAttached: false,
      nnapiAttached: false,
      backend: 'cpu',
    );
    expect(cpu.label, 'CPU');
    expect(cpu.gpuAttached, isFalse);

    const gpu = TfliteAccelResult(
      gpuRequested: true,
      gpuAttached: true,
      nnapiAttached: false,
      backend: 'gpu',
    );
    expect(gpu.label, 'GPU');

    const nnapi = TfliteAccelResult(
      gpuRequested: false,
      gpuAttached: false,
      nnapiAttached: true,
      backend: 'nnapi',
    );
    expect(nnapi.label, 'NNAPI');
  });

  test('偏好键名稳定，供设置页与锻炼页共用', () {
    expect(TfliteAccelPrefs.gpuKey, 'coach_tflite_prefer_gpu');
    expect(TfliteAccelPrefs.engineKey, 'coach_camera_engine');
  });
}
