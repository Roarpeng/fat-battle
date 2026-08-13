import 'package:flutter_test/flutter_test.dart';
import 'package:fat_battle/core/barrel.dart';
import 'package:fat_battle/constants/app_constants.dart';
import 'package:fat_battle/services/game_algorithm.dart';

void main() {
  group('calorieFloorFor', () {
    test('女性下限至少 1200，且不低于 BMR', () {
      expect(calorieFloorFor(gender: Gender.female, bmr: 1100), 1200);
      expect(calorieFloorFor(gender: Gender.female, bmr: 1400), 1400);
    });

    test('男性下限至少 1500，且不低于 BMR', () {
      expect(calorieFloorFor(gender: Gender.male, bmr: 1400), 1500);
      expect(calorieFloorFor(gender: Gender.male, bmr: 1800), 1800);
    });
  });

  group('calculateTargetCalories 安全下限与赤字上限', () {
    test('默认 loss 赤字不超过 500', () {
      final result = calculateTargetCalories(
        Gender.male,
        80,
        180,
        30,
        ActivityLevel.moderate,
      );
      expect(result.dailyDeficit, lessThanOrEqualTo(kDefaultDailyDeficitKcal));
      expect(result.dailyDeficit, lessThanOrEqualTo(kMaxDailyDeficitKcal));
      expect(result.targetCalories, greaterThanOrEqualTo(result.calorieFloor));
    });

    test('extremeLoss 赤字不超过 750', () {
      final result = calculateTargetCalories(
        Gender.male,
        90,
        185,
        28,
        ActivityLevel.active,
        CaloriesGoal.extremeLoss,
      );
      expect(result.dailyDeficit, lessThanOrEqualTo(kMaxDailyDeficitKcal));
      expect(result.targetCalories, equals(result.tdee - result.dailyDeficit));
      expect(result.targetCalories, greaterThanOrEqualTo(result.calorieFloor));
    });

    test('男性目标永不低于 1500 与 BMR 的较大值', () {
      final result = calculateTargetCalories(
        Gender.male,
        50,
        160,
        50,
        ActivityLevel.sedentary,
        CaloriesGoal.extremeLoss,
      );
      expect(result.targetCalories, greaterThanOrEqualTo(1500));
      expect(result.targetCalories, greaterThanOrEqualTo(result.bmr));
      expect(result.targetCalories, greaterThanOrEqualTo(result.calorieFloor));
      expect(result.dailyDeficit, lessThanOrEqualTo(kMaxDailyDeficitKcal));
    });

    test('女性目标永不低于 1200 与 BMR 的较大值', () {
      final result = calculateTargetCalories(
        Gender.female,
        45,
        150,
        50,
        ActivityLevel.sedentary,
        CaloriesGoal.extremeLoss,
      );
      expect(result.targetCalories, greaterThanOrEqualTo(1200));
      expect(result.targetCalories, greaterThanOrEqualTo(result.bmr));
      expect(result.dailyDeficit, lessThanOrEqualTo(kMaxDailyDeficitKcal));
    });

    test('capDailyDeficit 将过大赤字夹到 750', () {
      expect(capDailyDeficit(1000), kMaxDailyDeficitKcal);
      expect(capDailyDeficit(-20), 0);
      expect(capDailyDeficit(500), 500);
    });

    test('GameAlgorithm 困难模式也不会低于下限', () {
      final target = GameAlgorithm.calcTargetCal(
        48,
        Difficulty.hard,
        heightCm: 150,
        age: 55,
        gender: Gender.female,
        workType: WorkType.sedentary,
      );
      final bmr = calculateBmr(Gender.female, 48, 150, 55);
      expect(target, greaterThanOrEqualTo(calorieFloorFor(gender: Gender.female, bmr: bmr)));
      expect(target, greaterThanOrEqualTo(1200));
    });
  });
}
