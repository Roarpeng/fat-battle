import 'package:flutter_test/flutter_test.dart';
import 'package:fat_battle/core/barrel.dart';

void main() {
  test('连续 7 天极端赤字：降奖励、禁成就、含危机热线', () {
    expect(isExtremeDeficitCrisis(6), isFalse);
    expect(isExtremeDeficitCrisis(7), isTrue);
    expect(extremeDeficitCombatMultiplier(7), kExtremeDeficitRewardMultiplier);
    expect(extremeDeficitCombatMultiplier(3), 1.0);

    var streak = 0;
    for (var i = 0; i < 7; i++) {
      streak = nextExtremeDeficitStreak(
        currentStreak: streak,
        yesterdayWasExtreme: true,
      );
    }
    expect(streak, 7);
    expect(isExtremeDeficitCrisis(streak), isTrue);

    final copy = extremeDeficitHelpCopy();
    expect(copy, contains(kCrisisHotlineBeijing1));
    expect(copy, contains(kCrisisHotlineBeijing2));
    expect(copy, contains(kCrisisOrgUrl));
    expect(copy.toLowerCase(), isNot(contains('失败')));
  });

  test('无活动不计入极端赤字', () {
    expect(
      wasExtremeDeficitDay(intake: 0, calorieFloor: 1500, hadActivity: false),
      isFalse,
    );
    expect(
      wasExtremeDeficitDay(intake: 800, calorieFloor: 1500, hadActivity: true),
      isTrue,
    );
  });

  test('平滑体重窗口夹在 7–14 日', () {
    final records = [
      for (var i = 1; i <= 14; i++)
        WeightLogEntry(
          date: '2026-08-${i.toString().padLeft(2, '0')}',
          weightKg: 70 + i * 0.1,
        ),
    ];
    final seven = smoothWeightSeries(records, windowDays: 7);
    final fourteen = smoothWeightSeries(records, windowDays: 14);
    expect(seven.length, 14);
    expect(fourteen.length, 14);
    expect(seven.last, isNot(equals(records.last.weightKg)));
  });
}
