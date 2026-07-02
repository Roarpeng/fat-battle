import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum VoiceStyle { pet, warrior, mage, assassin }

class VoiceService {
  static final VoiceService _instance = VoiceService._();
  factory VoiceService() => _instance;
  VoiceService._();

  FlutterTts? _tts;
  VoiceStyle _style = VoiceStyle.pet;
  bool _enabled = true;
  bool _initialized = false;

  Map<VoiceStyle, double> get _pitchMap => {
        VoiceStyle.pet: 1.4,
        VoiceStyle.warrior: 0.8,
        VoiceStyle.mage: 1.0,
        VoiceStyle.assassin: 0.6,
      };

  Map<VoiceStyle, double> get _rateMap => {
        VoiceStyle.pet: 1.1,
        VoiceStyle.warrior: 0.9,
        VoiceStyle.mage: 1.0,
        VoiceStyle.assassin: 1.0,
      };

  Future<void> init() async {
    if (_initialized) return;
    _tts = FlutterTts();
    _tts!.setLanguage('zh-CN');
    _tts!.setSpeechRate(_rateMap[_style]!);
    _tts!.setPitch(_pitchMap[_style]!);
    _tts!.awaitSpeakCompletion(true);
    await _tts!.getVoices.then((voices) {
      final zhVoice = voices.where((v) => v.language.startsWith('zh')).toList();
      if (zhVoice.isNotEmpty) {
        final female =
            zhVoice.where((v) => v.name.toLowerCase().contains('female')).toList();
        _tts!.setVoice(female.isNotEmpty ? female.first : zhVoice.first);
      }
    });
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

  Future<void> speak(String text) async {
    if (!_enabled || !_initialized) return;
    await _tts!.stop();
    await _tts!.speak(text);
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
      speak('完美~ 主人造成了${damage}点伤害~ 好厉害~');
  Future<void> monsterDefeated(String name, int coins) =>
      speak('太棒了~ 主人击败了${name}！获得了${coins}金币~ 主人最厉害了~');
  Future<void> monsterFailed() =>
      speak('没关系主人~ 明天继续加油~ 你一定可以的~');
  Future<void> foodOver(int over) =>
      speak('主人注意~ 超标了${over}卡路里，脂肪怪在偷偷增强防御~');
  Future<void> foodAdded(String name) => speak('已记录${name}~');
  Future<void> dailySummary(int calIn, int calEx, int net) {
    final rating = net <= 0 ? '优秀' : net < 300 ? '不错' : '加油';
    speak('今天主人摄入${calIn}卡路里，锻炼消耗${calEx}，净摄入${net}，表现${rating}~');
  }

  Future<void> streak(int days) =>
      speak('连续${days}天~ 主人已经是真正的减肥战士了~ 好棒~');
  Future<void> maintenanceEnter() =>
      speak('恭喜主人~ 达到目标体重了~ 进入维护模式，继续守护成果哦~');
  Future<void> maintenanceAttack() =>
      speak('主人~ 脂肪怪来进攻了~ 赶紧防御~');
}

final voiceServiceProvider = Provider<VoiceService>((ref) => VoiceService());
