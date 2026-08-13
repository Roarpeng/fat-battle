import '../constants/app_constants.dart';

/// 课后 3 档手感。
enum CoachFeel {
  tooEasy, // 太轻松 → 明天加量
  justRight, // 刚好
  tooHard, // 太累 → 明天减量
}

extension CoachFeelExt on CoachFeel {
  String get label => switch (this) {
        CoachFeel.tooEasy => '太轻松',
        CoachFeel.justRight => '刚好',
        CoachFeel.tooHard => '太累',
      };

  String get hint => switch (this) {
        CoachFeel.tooEasy => '炉火还能再旺一点',
        CoachFeel.justRight => '保持这套节奏',
        CoachFeel.tooHard => '下次把火候调小',
      };
}

/// 手感微调结果：训练量档位 + 可选难度轻推。
class CoachFeelAdjustment {
  /// 训练量档位，范围 [-2, 2]。
  final int volumeNudge;

  /// 若已顶到量档边界，则轻推游戏难度一档；否则保持原难度。
  final Difficulty difficulty;

  /// 难度是否相对输入发生了变化。
  final bool difficultyChanged;

  const CoachFeelAdjustment({
    required this.volumeNudge,
    required this.difficulty,
    this.difficultyChanged = false,
  });
}

/// 将课后手感落到「明天训练量 / 难度」上，全部有界。
///
/// - 太轻松：volumeNudge +1；已到 +2 则难度 easy→normal→hard
/// - 太累：volumeNudge -1；已到 -2 则难度 hard→normal→easy
/// - 刚好：nudge 向 0 回落一档，难度不变
CoachFeelAdjustment applyCoachFeel({
  required CoachFeel feel,
  int currentNudge = 0,
  Difficulty difficulty = Difficulty.normal,
}) {
  var nudge = currentNudge.clamp(-2, 2);
  var nextDiff = difficulty;
  var diffChanged = false;

  switch (feel) {
    case CoachFeel.tooEasy:
      if (nudge >= 2) {
        final bumped = _bumpHarder(difficulty);
        diffChanged = bumped != difficulty;
        nextDiff = bumped;
      } else {
        nudge += 1;
      }
    case CoachFeel.tooHard:
      if (nudge <= -2) {
        final eased = _bumpEasier(difficulty);
        diffChanged = eased != difficulty;
        nextDiff = eased;
      } else {
        nudge -= 1;
      }
    case CoachFeel.justRight:
      if (nudge > 0) {
        nudge -= 1;
      } else if (nudge < 0) {
        nudge += 1;
      }
  }

  return CoachFeelAdjustment(
    volumeNudge: nudge.clamp(-2, 2),
    difficulty: nextDiff,
    difficultyChanged: diffChanged,
  );
}

/// 训练量倍率：每档 ±10%，夹在 0.8～1.2。
double volumeScaleForNudge(int nudge) {
  return (1.0 + nudge * 0.1).clamp(0.8, 1.2);
}

Difficulty _bumpHarder(Difficulty d) => switch (d) {
      Difficulty.easy => Difficulty.normal,
      Difficulty.normal => Difficulty.hard,
      Difficulty.hard => Difficulty.hard,
    };

Difficulty _bumpEasier(Difficulty d) => switch (d) {
      Difficulty.hard => Difficulty.normal,
      Difficulty.normal => Difficulty.easy,
      Difficulty.easy => Difficulty.easy,
    };
