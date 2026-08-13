import 'voice_service.dart';

/// Local TTS coach phrases for pose training (no LLM).
///
/// Wraps [VoiceService] with Chinese templates, short debounce for long tips,
/// and non-blocking speak so training loops are not stalled by TTS completion.
///
/// 远场约定：口令替代屏幕剪影；计次每次都报。
class PoseCoachVoice {
  PoseCoachVoice([VoiceService? voice]) : _voice = voice ?? VoiceService();

  /// 长句防抖（纠错/站位）；短计次口令不走此窗口。
  static const Duration tipDebounceWindow = Duration(milliseconds: 2500);

  final VoiceService _voice;

  String? _lastSpokenText;
  DateTime? _lastSpokenAt;

  VoiceService get voice => _voice;

  Future<void> ensureReady() => _voice.init();

  /// 开练：准备输出路由（耳机/外放）并初始化 TTS。
  Future<String> prepareSession() async {
    await _voice.init();
    return _voice.prepareCoachPlayback();
  }

  Future<void> endSession() async {
    await _voice.stop();
    await _voice.restorePlayback();
  }

  void setEnabled(bool enabled) => _voice.setEnabled(enabled);

  Future<void> stop() => _voice.stop();

  // ── Setup / align / countdown / start ─────────────────────────────

  /// 架好手机、走到镜头前。
  void announceSetup() => _speakTip('请把手机架稳，然后走到镜头前');

  /// 站进白色虚线框（听口令，不依赖看清屏幕）。
  void announceAlign() => _speakTip('请正对手机，全身入镜，站稳准备');

  /// 倒计时播报，例如 3 / 2 / 1。
  void announceCountdown(int seconds) {
    if (seconds <= 0) return;
    _speakRep('$seconds');
  }

  /// 倒计时结束、开始计数（不提剪影，远场看不见）。
  void announceStartCounting({String? exerciseName}) {
    if (exerciseName != null && exerciseName.isNotEmpty) {
      _speakTip('开始$exerciseName，听口令做动作');
    } else {
      _speakTip('开始锻炼，听口令做动作');
    }
  }

  // ── Form tips ─────────────────────────────────────────────────────

  /// [tip]: `out_of_frame` | `too_close` | `too_far` | `adjusting`
  void announceFormTip(String tip) {
    switch (tip) {
      case 'out_of_frame':
        _speakTip('出画面了，请重新走进镜头');
      case 'too_close':
        _speakTip('太近了，请再退后几步');
      case 'too_far':
        _speakTip('太远了，请再靠近一点');
      case 'adjusting':
        _speakTip('再调整一下姿势，站稳对准');
      default:
        _speakTip('请调整站位，保持全身入镜');
    }
  }

  /// 检测器已暴露的深度/幅度提示（深蹲、弓步）。
  void announceDepthCue({String? exerciseType}) {
    if (exerciseType == 'lunge') {
      _speakTip('弓步再低一点，前膝大约九十度');
    } else {
      _speakTip('蹲再低一点，大腿尽量平行地面');
    }
  }

  /// 检测器实时反馈 → 语音（去表情符号，防抖）。
  void announceLiveCue(String feedback) {
    final cleaned = _stripDecorations(feedback);
    if (cleaned.isEmpty) return;
    // 纯数字/短计数留给 announceRep
    if (RegExp(r'^\d+$').hasMatch(cleaned)) {
      _speakRep(cleaned);
      return;
    }
    _speakTip(cleaned);
  }

  // ── Reps：每次都报 ────────────────────────────────────────────────

  /// 每次有效计次都报数（用户确认：每次都报）。
  void announceRep(int reps) {
    if (reps <= 0) return;
    _speakRep('$reps');
  }

  /// 兼容旧调用；[every] 默认 1 = 每次都报。
  void announceRepMilestone(int reps, {int every = 1}) {
    if (reps <= 0 || every <= 0 || reps % every != 0) return;
    if (every == 1) {
      announceRep(reps);
    } else {
      _speakTip('已经完成$reps次，继续保持');
    }
  }

  // ── Pause / resume ────────────────────────────────────────────────

  void announcePause() => _speakTip('已暂停，休息一下');

  void announceResume() => _speakTip('继续锻炼，加油');

  // ── Plan rest ─────────────────────────────────────────────────────

  /// 式间休息；[nextExerciseName] 可选下一式名称。
  void announcePlanRest(int seconds, {String? nextExerciseName}) {
    if (seconds <= 0) {
      if (nextExerciseName != null && nextExerciseName.isNotEmpty) {
        _speakTip('下一式，$nextExerciseName');
      }
      return;
    }
    if (nextExerciseName != null && nextExerciseName.isNotEmpty) {
      _speakTip('式间休息$seconds秒，下一式是$nextExerciseName');
    } else {
      _speakTip('式间休息$seconds秒，深呼吸准备下一式');
    }
  }

  // ── Complete ──────────────────────────────────────────────────────

  void announceExerciseComplete({String? exerciseName, int? reps}) {
    final name =
        (exerciseName != null && exerciseName.isNotEmpty) ? exerciseName : '本组';
    if (reps != null && reps > 0) {
      _speakTip('$name完成，共$reps次，干得漂亮');
    } else {
      _speakTip('$name完成，干得漂亮');
    }
  }

  void announcePlanComplete({String? planTitle}) {
    if (planTitle != null && planTitle.isNotEmpty) {
      _speakTip('$planTitle全部完成，太棒了');
    } else {
      _speakTip('今日训练全部完成，太棒了');
    }
  }

  // ── Long-break resume + bonus ─────────────────────────────────────

  void announceResumeAfterLongBreak({
    required int bonusSeconds,
    int? gapSeconds,
  }) {
    final bonus = bonusSeconds < 0 ? 0 : bonusSeconds;
    if (gapSeconds != null && gapSeconds > 0 && bonus > 0) {
      _speakTip('欢迎回来，离开了$gapSeconds秒，已为你增加$bonus秒训练时间');
    } else if (bonus > 0) {
      _speakTip('欢迎回来，已为你增加$bonus秒训练时间');
    } else {
      _speakTip('欢迎回来，继续锻炼');
    }
  }

  // ── Internals ─────────────────────────────────────────────────────

  void _speakRep(String text) {
    // 计次短句：不做同文防抖，保证每一次都报（1、2、3…）
    // ignore: discarded_futures
    _voice.speakNonBlocking(text);
    _lastSpokenText = text;
    _lastSpokenAt = DateTime.now();
  }

  void _speakTip(String text) {
    if (!_shouldSpeakTip(text)) return;
    // ignore: discarded_futures
    _voice.speakNonBlocking(text);
  }

  bool _shouldSpeakTip(String text) {
    final now = DateTime.now();
    if (_lastSpokenText == text &&
        _lastSpokenAt != null &&
        now.difference(_lastSpokenAt!) < tipDebounceWindow) {
      return false;
    }
    _lastSpokenText = text;
    _lastSpokenAt = now;
    return true;
  }

  static final _emojiOrSymbol = RegExp(
    r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}⭐💪~～]+',
    unicode: true,
  );

  String _stripDecorations(String raw) {
    return raw
        .replaceAll(_emojiOrSymbol, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
