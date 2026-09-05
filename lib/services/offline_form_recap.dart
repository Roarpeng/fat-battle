import 'camera_move_fsm.dart';

/// 组后离线 form-recap：仅根据本地指标拼 2–4 句中文，不假装 LLM。
///
/// 网络路径仍走 [CoachApi.formRecap]；本构建器是 API/LLM 不可用时的兑底。
class OfflineFormRecap {
  OfflineFormRecap._();

  static const _gradeOrder = ['D', 'C', 'B', 'A', 'S'];

  static String build({
    required String exerciseType,
    required int repCount,
    required List<String> qualityGrades,
    double? minKneeAngle,
    required int durationSec,
    String? avgGrade,
    int shallowCount = 0,
    List<String> commonFaults = const [],
  }) {
    final meta = CameraGuidableCatalog.byType(exerciseType);
    final name = meta?.name ?? _nameOf(exerciseType);
    final timed = meta?.timedHold ?? exerciseType == 'plank';
    final grade = (avgGrade ?? averageGrade(qualityGrades)).toUpperCase();
    final reps = repCount < 0 ? 0 : repCount;
    final shallow = shallowCount < 0 ? 0 : shallowCount;
    final seconds = durationSec < 0 ? 0 : durationSec;
    final dist = gradeDistribution(qualityGrades);

    final sentences = <String>[];

    if (reps <= 0 && !timed) {
      sentences.add('本组几乎没计到有效$name次数。');
      sentences.add(_emptyHint(exerciseType));
      if (shallow > 0) {
        sentences.add('有 $shallow 次幅度偏浅，做到底再起来才会计次。');
      }
      return _join(sentences);
    }

    if (timed) {
      final hold = reps > 0 ? reps : seconds;
      sentences.add('$name坚持了 $hold 秒，本组质量 $grade 级。');
    } else {
      sentences.add('$name完成 $reps 次，本组质量 $grade 级。');
    }

    sentences.add(_gradeSentence(grade, dist, timed: timed));

    if (shallow > 0) {
      sentences.add(
        '另有 $shallow 次浅幅度未计次。${_shallowHint(exerciseType)}',
      );
    } else if (minKneeAngle != null &&
        (exerciseType == 'squat' || exerciseType == 'lunge')) {
      sentences.add('最低膝角约 ${minKneeAngle.round()}°，${_kneeHint(minKneeAngle)}');
    } else if (seconds > 0 && !timed) {
      sentences.add('用时 $seconds 秒，${_paceHint(reps, seconds, exerciseType)}');
    }

    final fault = _faultSentence(exerciseType, commonFaults, grade);
    if (fault != null) sentences.add(fault);

    while (sentences.length < 2) {
      sentences.add('对准镜头、做满幅度再来一组。');
    }
    return _join(sentences.take(4).toList());
  }

  static String averageGrade(List<String> grades) {
    if (grades.isEmpty) return 'D';
    var sum = 0;
    for (final g in grades) {
      final i = _gradeOrder.indexOf(g.toUpperCase());
      sum += i < 0 ? 0 : i;
    }
    return _gradeOrder[(sum / grades.length).round().clamp(0, 4)];
  }

  static Map<String, int> gradeDistribution(List<String> grades) {
    final out = {for (final g in _gradeOrder) g: 0};
    for (final raw in grades) {
      final g = raw.toUpperCase();
      if (out.containsKey(g)) out[g] = out[g]! + 1;
    }
    return out;
  }

  static String _join(List<String> sentences) {
    return sentences
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => s.endsWith('。') || s.endsWith('！') || s.endsWith('~') ? s : '$s。')
        .join('');
  }

  static String _gradeSentence(
    String grade,
    Map<String, int> dist, {
    required bool timed,
  }) {
    final s = dist['S'] ?? 0;
    final a = dist['A'] ?? 0;
    final b = dist['B'] ?? 0;
    final weak = (dist['C'] ?? 0) + (dist['D'] ?? 0);
    final good = s + a;
    switch (grade) {
      case 'S':
      case 'A':
        if (good > 0) {
          return timed
              ? '体线稳定，核心收得住，保持这个姿势即可。'
              : '其中 $good 次达到 A/S，幅度到位，保持这个深度即可。';
        }
        return '幅度到位，保持这个深度即可。';
      case 'B':
        return timed
            ? '大体能撑住，髋再抬平一点质量会更好。'
            : '有 $b 次只到 B 级，下一组再蹲/压低一点。';
      default:
        if (weak > 0) {
          return timed
              ? '塌腰或晃动较多，先缩短时长把髋抬平。'
              : '有 $weak 次只有 C/D，浅的不计次，做到底再起来。';
        }
        return timed ? '核心还不够稳，先把髋抬平再计时。' : '不少是浅幅度，下次做到底再起来。';
    }
  }

  static String _emptyHint(String type) {
    switch (type) {
      case 'pushup':
        return '侧身入镜，胸部靠近地面再撑起。';
      case 'plank':
        return '肩髋踝尽量一条线，塌腰不会累计秒数。';
      case 'highknee':
        return '正对镜头，膝盖抬到接近髋高。';
      case 'burpee':
        return '蹲下、撑地成平板、再跳起，四段都要走到。';
      case 'mountainclimber':
        return '先稳住平板，再交替收膝。';
      case 'jumping_jack':
        return '手脚同时张开，跳起来再并拢。';
      case 'lunge':
        return '前膝大约九十度，后膝靠近地面。';
      default:
        return '对准镜头、做满幅度再来一组。';
    }
  }

  static String _shallowHint(String type) {
    switch (type) {
      case 'pushup':
        return '再往下压，胸部靠近地面。';
      case 'lunge':
        return '弓步再低一点，前膝大约九十度。';
      case 'highknee':
        return '膝盖再抬高，大腿接近水平。';
      case 'burpee':
        return '记得撑地成平板再跳起。';
      case 'jumping_jack':
        return '手脚再张开，跳起来。';
      case 'plank':
        return '塌腰的秒数不会累计。';
      default:
        return '再蹲低一点，蹲到底再起来。';
    }
  }

  static String _kneeHint(double minKnee) {
    if (minKnee <= 95) return '深度足够。';
    if (minKnee <= 120) return '还可以再低一点。';
    return '多数偏浅，蹲到大腿接近水平。';
  }

  static String _paceHint(int reps, int seconds, String type) {
    if (reps <= 0 || seconds <= 0) return '节奏先求稳。';
    final secPer = seconds / reps;
    if (type == 'burpee') {
      return secPer > 6 ? '节奏偏慢，下一组可以稍快。' : '节奏合理。';
    }
    if (secPer < 1.2) return '节奏偏快，注意做满幅度。';
    if (secPer > 4) return '节奏偏慢，质量优先即可。';
    return '节奏稳定。';
  }

  static String? _faultSentence(
    String type,
    List<String> faults,
    String grade,
  ) {
    final text = faults.join(' ');
    if (text.contains('塌') || text.contains('髋抬平')) {
      return '常见问题是塌腰，收紧核心把髋抬平。';
    }
    if (text.contains('入镜') || text.contains('全身')) {
      return '先保证全身入镜，关键点稳了再计次。';
    }
    if (text.contains('再蹲低') || text.contains('再往下压') || text.contains('幅度不够')) {
      return '下一组做到底再起来，浅的继续不计次。';
    }
    if (grade == 'S' || grade == 'A') {
      return '下一组保持这个质量即可。';
    }
    return _nextSetHint(type);
  }

  static String _nextSetHint(String type) {
    switch (type) {
      case 'plank':
        return '下一组先把肩髋踝摆成一条线再计时。';
      case 'highknee':
        return '下一组膝盖抬过髋、落地轻一点。';
      case 'burpee':
        return '下一组四段都走完：蹲、撑、跳、站。';
      case 'mountainclimber':
        return '下一组髋不要晃，只动腿。';
      case 'jumping_jack':
        return '下一组手脚同步张开。';
      case 'pushup':
        return '下一组核心收紧，身体一条线往下压。';
      default:
        return '下一组做满幅度，质量优先。';
    }
  }

  static String _nameOf(String type) {
    return CameraGuidableCatalog.byType(type)?.name ??
        switch (type) {
          'pushup' => '俯卧撑',
          'lunge' => '弓步蹲',
          'jumping_jack' => '开合跳',
          'plank' => '平板支撑',
          'highknee' => '高抬腿',
          'burpee' => '波比跳',
          'mountainclimber' => '登山跑',
          _ => '深蹲',
        };
  }
}
