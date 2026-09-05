import 'package:flutter_test/flutter_test.dart';
import 'package:fat_battle/services/coach_api.dart';
import 'package:fat_battle/services/offline_form_recap.dart';

void main() {
  group('OfflineFormRecap', () {
    test('有效次数 + 等级 + 浅蹲生成 2–4 句中文', () {
      final text = OfflineFormRecap.build(
        exerciseType: 'squat',
        repCount: 12,
        qualityGrades: const ['A', 'B', 'A', 'C'],
        minKneeAngle: 118,
        durationSec: 40,
        avgGrade: 'B',
        shallowCount: 3,
        commonFaults: const ['幅度不够哦，再蹲低一点~'],
      );
      final sentences = text
          .split('。')
          .where((s) => s.trim().isNotEmpty)
          .toList();
      expect(sentences.length, inInclusiveRange(2, 4));
      expect(text, contains('深蹲'));
      expect(text, contains('12 次'));
      expect(text, contains('B 级'));
      expect(text, contains('3 次'));
      expect(text, contains('浅'));
    });

    test('0 次不编造成绩，提示入镜/幅度', () {
      final text = OfflineFormRecap.build(
        exerciseType: 'pushup',
        repCount: 0,
        qualityGrades: const [],
        durationSec: 8,
        shallowCount: 2,
      );
      expect(text, contains('没计到'));
      expect(text, contains('俯卧撑'));
      expect(text, isNot(contains('完美')));
      expect(text, contains('浅'));
    });

    test('平板按秒描述，不说次数', () {
      final text = OfflineFormRecap.build(
        exerciseType: 'plank',
        repCount: 28,
        qualityGrades: const ['A', 'A'],
        durationSec: 28,
        avgGrade: 'A',
        commonFaults: const ['腰往下塌了，收紧核心把髋抬平'],
      );
      expect(text, contains('28 秒'));
      expect(text, contains('A 级'));
      expect(text, contains('塌腰'));
    });

    test('高抬腿 / 波比使用正确中文名', () {
      final hk = OfflineFormRecap.build(
        exerciseType: 'highknee',
        repCount: 20,
        qualityGrades: const ['S', 'A'],
        durationSec: 25,
        avgGrade: 'S',
      );
      expect(hk, contains('高抬腿'));
      expect(hk, contains('20 次'));

      final bp = OfflineFormRecap.build(
        exerciseType: 'burpee',
        repCount: 6,
        qualityGrades: const ['C', 'D'],
        durationSec: 40,
        avgGrade: 'C',
        shallowCount: 2,
      );
      expect(bp, contains('波比'));
      expect(bp, contains('浅'));
    });

    test('S 级且无浅幅度仍至少两句', () {
      final text = OfflineFormRecap.build(
        exerciseType: 'lunge',
        repCount: 10,
        qualityGrades: const ['S', 'S', 'A'],
        minKneeAngle: 92,
        durationSec: 30,
        avgGrade: 'S',
      );
      expect(text.split('。').where((s) => s.trim().isNotEmpty).length, greaterThanOrEqualTo(2));
      expect(text, contains('S 级'));
    });
  });

  group('CoachApi.localFormRecap', () {
    test('委托离线构建器，API 关闭时同一套文本', () {
      final a = CoachApi.localFormRecap(
        exerciseType: 'squat',
        repCount: 8,
        qualityGrades: const ['B', 'C'],
        minKneeAngle: 130,
        durationSec: 22,
        avgGrade: 'C',
        shallowCount: 4,
      );
      final b = OfflineFormRecap.build(
        exerciseType: 'squat',
        repCount: 8,
        qualityGrades: const ['B', 'C'],
        minKneeAngle: 130,
        durationSec: 22,
        avgGrade: 'C',
        shallowCount: 4,
      );
      expect(a, b);
      expect(a, contains('浅'));
    });
  });
}
