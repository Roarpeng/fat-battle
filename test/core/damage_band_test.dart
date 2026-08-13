import 'package:flutter_test/flutter_test.dart';
import 'package:fat_battle/constants/app_constants.dart';
import 'package:fat_battle/core/barrel.dart';

void main() {
  group('calorie band hit', () {
    test('打中预算带给予加成，吃得更少不会更高', () {
      const target = 1800;
      final inBand = calculateDamage(1800, 400, Difficulty.normal, targetCalories: target);
      final farBelow = calculateDamage(800, 400, Difficulty.normal, targetCalories: target);
      final farAbove = calculateDamage(2600, 400, Difficulty.normal, targetCalories: target);

      expect(inBand, greaterThan(farBelow));
      expect(inBand, greaterThan(farAbove));
      expect(farBelow, farAbove); // 都不在带内，基础伤害相同
      expect(inBand, 460); // 400 * 1.15
      expect(farBelow, 400);
    });

    test('不再因 burn > food 额外加伤', () {
      final eatLess = calculateDamage(0, 1000, Difficulty.normal, targetCalories: 1800);
      final inBand = calculateDamage(1800, 1000, Difficulty.normal, targetCalories: 1800);
      expect(eatLess, 1000);
      expect(inBand, 1150);
    });

    test('未传 targetCalories 时无吃少加成', () {
      expect(calculateDamage(0, 1000, Difficulty.normal), 1000);
    });

    test('isIntakeInCalorieBand 半宽至少 100kcal', () {
      expect(isIntakeInCalorieBand(1800, 1800), isTrue);
      expect(isIntakeInCalorieBand(1650, 1800), isTrue); // ±180
      expect(isIntakeInCalorieBand(1000, 1800), isFalse);
    });
  });
}
