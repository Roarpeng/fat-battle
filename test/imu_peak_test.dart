import 'package:flutter_test/flutter_test.dart';
import 'package:fat_battle/services/imu_peak.dart';
import 'package:fat_battle/services/coach_api.dart';

void main() {
  group('IMU 峰值 + 不应期', () {
    test('走路幅度的单样本尖刺不计次', () {
      var t = DateTime(2026, 1, 1, 12);
      final c = ImuPeakCounter(
        peakThreshold: 2.15,
        refractory: const Duration(milliseconds: 1000),
        now: () => t,
      );
      // 静息 ~1.0g，走路偶发 1.4–1.8，达不到跑步阈值
      final walk = [1.0, 1.2, 1.5, 1.1, 1.0, 1.3, 1.6, 1.2, 1.0, 1.4, 1.1];
      var hits = 0;
      for (final m in walk) {
        t = t.add(const Duration(milliseconds: 40));
        if (c.ingest(m)) hits++;
      }
      expect(hits, 0);
      expect(c.count, 0);
    });

    test('过阈值的峰在不应期内只计 1 次', () {
      var t = DateTime(2026, 1, 1, 12);
      final c = ImuPeakCounter(
        peakThreshold: 1.65,
        refractory: const Duration(milliseconds: 1200),
        now: () => t,
      );
      // 峰：1.0 → 2.4 → 1.0，随后 400ms 内再来一个峰
      expect(c.ingest(1.0), isFalse);
      t = t.add(const Duration(milliseconds: 40));
      expect(c.ingest(2.4), isFalse); // 还在填窗
      t = t.add(const Duration(milliseconds: 40));
      expect(c.ingest(1.0), isTrue);
      expect(c.count, 1);

      t = t.add(const Duration(milliseconds: 400));
      c.ingest(1.0);
      t = t.add(const Duration(milliseconds: 40));
      c.ingest(2.5);
      t = t.add(const Duration(milliseconds: 40));
      expect(c.ingest(1.0), isFalse, reason: '仍在 1.2s 不应期');
      expect(c.count, 1);

      t = t.add(const Duration(milliseconds: 900));
      c.ingest(1.0);
      t = t.add(const Duration(milliseconds: 40));
      c.ingest(2.3);
      t = t.add(const Duration(milliseconds: 40));
      expect(c.ingest(1.1), isTrue);
      expect(c.count, 2);
    });

    test('forType 给 running 1s 不应期', () {
      final c = ImuExercisePeaks.forType('running');
      expect(c.refractory, const Duration(milliseconds: 1000));
      expect(c.peakThreshold, greaterThan(2.0));
    });
  });

  group('组后 recap 本地兑底', () {
    test('LLM 关闭时仍给出 1–2 句', () {
      final text = CoachApi.localFormRecap(
        exerciseType: 'squat',
        repCount: 10,
        qualityGrades: ['A', 'B', 'A'],
        minKneeAngle: 88,
        durationSec: 40,
        avgGrade: 'A',
      );
      expect(text.contains('深蹲'), isTrue);
      expect(text.contains('10'), isTrue);
      expect(text.length, lessThan(80));
    });

    test('浅幅度兑底提到不计次', () {
      final text = CoachApi.localFormRecap(
        exerciseType: 'pushup',
        repCount: 8,
        qualityGrades: ['D', 'D'],
        durationSec: 20,
        avgGrade: 'D',
      );
      expect(text.contains('浅'), isTrue);
    });
  });
}
