import 'voice_service.dart';

/// Local TTS coach phrases for pose training (no LLM).
///
/// Wraps [VoiceService] with Chinese templates, ~2.5s same-phrase debounce,
/// and non-blocking speak so training loops are not stalled by TTS completion.
class PoseCoachVoice {
  PoseCoachVoice([VoiceService? voice]) : _voice = voice ?? VoiceService();

  static const Duration debounceWindow = Duration(milliseconds: 2500);

  final VoiceService _voice;

  String? _lastSpokenText;
  DateTime? _lastSpokenAt;

  VoiceService get voice => _voice;

  Future<void> ensureReady() => _voice.init();

  void setEnabled(bool enabled) => _voice.setEnabled(enabled);

  Future<void> stop() => _voice.stop();

  // ── Setup / align / countdown / start ─────────────────────────────

  /// 架好手机、走到镜头前。
  void announceSetup() => _speak('请把手机架稳，然后走到镜头前');

  /// 站进白色虚线框。
  void announceAlign() => _speak('请站进白色虚线框，全身入镜');

  /// 倒计时播报，例如 3 / 2 / 1。
  void announceCountdown(int seconds) {
    if (seconds <= 0) return;
    _speak('$seconds');
  }

  /// 倒计时结束、开始计数。
  void announceStartCounting({String? exerciseName}) {
    if (exerciseName != null && exerciseName.isNotEmpty) {
      _speak('开始$exerciseName，跟着剪影做动作');
    } else {
      _speak('开始锻炼，跟着剪影做动作');
    }
  }

  // ── Form tips ─────────────────────────────────────────────────────

  /// [tip]: `out_of_frame` | `too_close` | `adjusting`（其它值回退通用提示）。
  void announceFormTip(String tip) {
    switch (tip) {
      case 'out_of_frame':
        _speak('出框了，请重新站进白框');
      case 'too_close':
        _speak('太近了，请再退后几步');
      case 'adjusting':
        _speak('再调整一下姿势，站稳对准');
      default:
        _speak('请调整站位，保持全身入镜');
    }
  }

  // ── Rep milestones ────────────────────────────────────────────────

  /// 每 [every] 次（默认 5，也可传 10）播报一次；非倍数或 0 次不播。
  void announceRepMilestone(int reps, {int every = 5}) {
    if (reps <= 0 || every <= 0 || reps % every != 0) return;
    _speak('已经完成$reps次，继续保持');
  }

  // ── Pause / resume ────────────────────────────────────────────────

  void announcePause() => _speak('已暂停，休息一下');

  void announceResume() => _speak('继续锻炼，加油');

  // ── Plan rest ─────────────────────────────────────────────────────

  /// 式间休息；[nextExerciseName] 可选下一式名称。
  void announcePlanRest(int seconds, {String? nextExerciseName}) {
    if (seconds <= 0) {
      if (nextExerciseName != null && nextExerciseName.isNotEmpty) {
        _speak('下一式，$nextExerciseName');
      }
      return;
    }
    if (nextExerciseName != null && nextExerciseName.isNotEmpty) {
      _speak('式间休息$seconds秒，下一式是$nextExerciseName');
    } else {
      _speak('式间休息$seconds秒，深呼吸准备下一式');
    }
  }

  // ── Complete ──────────────────────────────────────────────────────

  void announceExerciseComplete({String? exerciseName, int? reps}) {
    final name =
        (exerciseName != null && exerciseName.isNotEmpty) ? exerciseName : '本组';
    if (reps != null && reps > 0) {
      _speak('$name完成，共$reps次，干得漂亮');
    } else {
      _speak('$name完成，干得漂亮');
    }
  }

  void announcePlanComplete({String? planTitle}) {
    if (planTitle != null && planTitle.isNotEmpty) {
      _speak('$planTitle全部完成，太棒了');
    } else {
      _speak('今日训练全部完成，太棒了');
    }
  }

  // ── Long-break resume + bonus ─────────────────────────────────────

  /// 长时间离开后恢复；[bonusSeconds] 为补偿时长，[gapSeconds] 可选离开秒数。
  void announceResumeAfterLongBreak({
    required int bonusSeconds,
    int? gapSeconds,
  }) {
    final bonus = bonusSeconds < 0 ? 0 : bonusSeconds;
    if (gapSeconds != null && gapSeconds > 0 && bonus > 0) {
      _speak('欢迎回来，离开了$gapSeconds秒，已为你增加$bonus秒训练时间');
    } else if (bonus > 0) {
      _speak('欢迎回来，已为你增加$bonus秒训练时间');
    } else {
      _speak('欢迎回来，继续锻炼');
    }
  }

  // ── Internals ─────────────────────────────────────────────────────

  void _speak(String text) {
    if (!_shouldSpeak(text)) return;
    // Fire-and-forget: never await TTS completion on the training path.
    // ignore: discarded_futures
    _voice.speakNonBlocking(text);
  }

  bool _shouldSpeak(String text) {
    final now = DateTime.now();
    if (_lastSpokenText == text &&
        _lastSpokenAt != null &&
        now.difference(_lastSpokenAt!) < debounceWindow) {
      return false;
    }
    _lastSpokenText = text;
    _lastSpokenAt = now;
    return true;
  }
}
