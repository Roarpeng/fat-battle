import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum VoiceStyle { pet, warrior, mage, assassin }

/// TTS + 教练音频输出路由（有耳机走耳机，无耳机外放）。
class VoiceService {
  static final VoiceService _instance = VoiceService._();
  factory VoiceService() => _instance;
  VoiceService._();

  static const _audioRoute =
      MethodChannel('fat_battle/audio_route');

  FlutterTts? _tts;
  VoiceStyle _style = VoiceStyle.pet;
  bool _enabled = true;
  bool _initialized = false;

  /// 最近一次 [prepareCoachPlayback] 结果：`headset` / `speaker` / null
  String? lastRoutedTo;

  VoiceStyle get style => _style;
  bool get enabled => _enabled;

  Map<VoiceStyle, double> get _pitchMap => {
        VoiceStyle.pet: 1.4,
        VoiceStyle.warrior: 0.8,
        VoiceStyle.mage: 1.0,
        VoiceStyle.assassin: 0.6,
      };

  Map<VoiceStyle, double> get _rateMap => {
        // 教练远场：略慢一点更清晰
        VoiceStyle.pet: 1.0,
        VoiceStyle.warrior: 0.85,
        VoiceStyle.mage: 0.95,
        VoiceStyle.assassin: 0.95,
      };

  Future<void> init() async {
    if (_initialized) return;
    _tts = FlutterTts();
    await _tts!.setLanguage('zh-CN');
    await _tts!.setSpeechRate(_rateMap[_style]!);
    await _tts!.setPitch(_pitchMap[_style]!);
    await _tts!.setVolume(1.0);
    _tts!.awaitSpeakCompletion(true);
    try {
      final voices = await _tts!.getVoices;
      if (voices is List) {
        final zhVoice = voices
            .whereType<Map>()
            .where((v) {
              final lang = (v['locale'] ?? v['language'] ?? '').toString();
              return lang.startsWith('zh');
            })
            .toList();
        if (zhVoice.isNotEmpty) {
          final female = zhVoice
              .where((v) =>
                  (v['name'] ?? '').toString().toLowerCase().contains('female'))
              .toList();
          final pick = Map<String, String>.from(
            (female.isNotEmpty ? female.first : zhVoice.first)
                .map((k, v) => MapEntry(k.toString(), v.toString())),
          );
          await _tts!.setVoice(pick);
        }
      }
    } catch (e) {
      debugPrint('VoiceService voice pick failed: $e');
    }
    _initialized = true;
  }

  void setStyle(VoiceStyle style) {
    _style = style;
    if (_tts != null) {
      _tts!.setSpeechRate(_rateMap[style]!);
      _tts!.setPitch(_pitchMap[style]!);
    }
  }

  void setEnabled(bool enabled) => _enabled = enabled;

  /// 开练前调用：检测耳机；无耳机强制外放，有耳机走耳机。
  Future<String> prepareCoachPlayback() async {
    await init();
    try {
      final raw = await _audioRoute.invokeMethod<dynamic>('prepareCoachPlayback');
      if (raw is Map) {
        lastRoutedTo = (raw['routedTo'] ?? 'speaker').toString();
      } else {
        lastRoutedTo = 'speaker';
      }
    } catch (e) {
      debugPrint('prepareCoachPlayback failed: $e');
      lastRoutedTo = 'speaker';
    }
    await _tts?.setVolume(1.0);
    return lastRoutedTo ?? 'speaker';
  }

  Future<void> restorePlayback() async {
    try {
      await _audioRoute.invokeMethod<void>('restorePlayback');
    } catch (e) {
      debugPrint('restorePlayback failed: $e');
    }
    lastRoutedTo = null;
  }

  Future<bool> isHeadsetConnected() async {
    try {
      return await _audioRoute.invokeMethod<bool>('isHeadsetConnected') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> speak(String text) async {
    if (!_enabled || !_initialized) return;
    await _tts!.stop();
    await _tts!.speak(text);
  }

  /// Coach/realtime path: start TTS without waiting for utterance to finish.
  /// Restores [awaitSpeakCompletion] so legacy [speak] still blocks until done.
  Future<void> speakNonBlocking(String text) async {
    if (!_enabled || !_initialized) return;
    final tts = _tts!;
    await tts.awaitSpeakCompletion(false);
    try {
      await tts.stop();
      await tts.speak(text);
    } finally {
      await tts.awaitSpeakCompletion(true);
    }
  }

  Future<void> stop() async {
    await _tts?.stop();
  }

  // ===== 场景语音 =====
  Future<void> morningGreeting() =>
      speak('早上好主人~ 新的一天开始啦，脂肪怪在等着你哦~');
  Future<void> lunchReminder() =>
      speak('该吃午饭啦主人~ 记得拍照记录哦~');
  Future<void> dinnerReminder() =>
      speak('晚餐时间到~ 主人记得记录饮食哦~');
  Future<void> drinkWater() =>
      speak('主人该喝水啦~ 保持代谢，让脂肪怪无处藏身~');
  Future<void> standUp() =>
      speak('坐太久啦主人~ 站起来走走，脂肪怪最怕你动起来~');
  Future<void> exerciseStart() =>
      speak('准备好了吗主人~ 让我们开始击败脂肪怪！');
  Future<void> exerciseCount(int n) => speak('$n');
  Future<void> exerciseCorrect() => speak('对就是这样~ 主人好棒~');
  Future<void> exerciseEncourage(int remaining) =>
      speak('太棒了~ 还有${remaining}个，脂肪怪在惨叫~ 主人加油~');
  Future<void> exerciseComplete(int damage) =>
      speak('完美~ 主人造成了${damage}点伤害~ 超级厉害~');
  Future<void> monsterDefeated(String name, int coins) =>
      speak('太棒了~ 主人击败了${name}！获得了${coins}金币~ 主人最厉害了~');
  Future<void> monsterFailed() =>
      speak('没关系主人~ 明天继续加油~ 你一定可以的~');
  Future<void> foodOver(int over) =>
      speak('摄入超过预算带 ${over} kcal，怪物生成了护盾，去锤炼就能削掉~');
  Future<void> foodAdded(String name) => speak('已记录${name}~');
  Future<void> dailySummary(int calIn, int calEx, int net) {
    final rating = net <= 0 ? '优秀' : net < 300 ? '不错' : '加油';
    return speak('今天主人摄入${calIn}卡路里，锻炼消耗${calEx}，净摄入${net}，表现$rating~');
  }

  Future<void> streak(int days) =>
      speak('连续$days天~ 主人已经是真正的减肥战士了~ 好棒~');
  Future<void> maintenanceEnter() =>
      speak('恭喜主人~ 达到目标体重了~ 进入维护模式，继续守护成果哦~');
  Future<void> maintenanceAttack() =>
      speak('主人~ 脂肪怪来进攻了~ 赶紧防御~');
}

final voiceServiceProvider = Provider<VoiceService>((ref) => VoiceService());
