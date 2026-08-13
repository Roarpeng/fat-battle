import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'auth_service.dart';

/// 组后动作 recap 客户端。走后端 `POST /api/v1/coach/form-recap`，
/// 密钥不进 APK；不发送图像/视频。LLM 不可用时本地兑底一句。
class CoachApi {
  CoachApi._();
  static final CoachApi instance = CoachApi._();
  factory CoachApi() => instance;

  bool get isAvailable => ApiConfig.isBackendEnabled;

  /// 非阻塞：调用方不要 await 来卡住 TTS 计次。
  Future<String> formRecap({
    required String exerciseType,
    required int repCount,
    required List<String> qualityGrades,
    double? minKneeAngle,
    required int durationSec,
    String? avgGrade,
  }) async {
    final local = localFormRecap(
      exerciseType: exerciseType,
      repCount: repCount,
      qualityGrades: qualityGrades,
      minKneeAngle: minKneeAngle,
      durationSec: durationSec,
      avgGrade: avgGrade,
    );
    if (!isAvailable) return local;

    try {
      final response = await AuthService().authedPost(
        '/api/v1/coach/form-recap',
        body: {
          'exerciseType': exerciseType,
          'repCount': repCount,
          'qualityGrades': qualityGrades,
          if (minKneeAngle != null) 'minKneeAngle': minKneeAngle,
          'durationSec': durationSec,
          if (avgGrade != null) 'avgGrade': avgGrade,
        },
      );
      if (response.statusCode == 429) return local;
      if (response.statusCode != 200) {
        debugPrint('CoachApi formRecap HTTP ${response.statusCode}');
        return local;
      }
      final data = jsonDecode(response.body);
      if (data is! Map || data['success'] != true) return local;
      final recap = data['recap']?.toString().trim() ?? '';
      if (recap.isEmpty) return local;
      return recap;
    } catch (e) {
      debugPrint('CoachApi formRecap 失败，走本地: $e');
      return local;
    }
  }

  /// LLM 关闭或失败时的 1–2 句本地兑底（不依赖云端）。
  static String localFormRecap({
    required String exerciseType,
    required int repCount,
    required List<String> qualityGrades,
    double? minKneeAngle,
    required int durationSec,
    String? avgGrade,
  }) {
    final name = _nameOf(exerciseType);
    final grade = (avgGrade ?? _avgGrade(qualityGrades)).toUpperCase();
    final reps = repCount < 0 ? 0 : repCount;
    final depth = minKneeAngle != null
        ? '最低膝角约 ${minKneeAngle.round()}°。'
        : '';
    if (reps <= 0) {
      return '本组几乎没计到有效次数。对准镜头、做满幅度再来一组。';
    }
    switch (grade) {
      case 'S':
      case 'A':
        return '$name完成 $reps 次，幅度到位。$depth保持这个深度即可。';
      case 'B':
        return '$name完成 $reps 次。$depth下一组再蹲/压低一点，质量会更好。';
      default:
        return '$name完成 $reps 次，不少是浅幅度。$depth下次做到底再起来，浅的不计次。';
    }
  }

  static String _avgGrade(List<String> grades) {
    if (grades.isEmpty) return 'D';
    const order = ['D', 'C', 'B', 'A', 'S'];
    var sum = 0;
    for (final g in grades) {
      final i = order.indexOf(g.toUpperCase());
      sum += i < 0 ? 0 : i;
    }
    final avg = (sum / grades.length).round().clamp(0, 4);
    return order[avg];
  }

  static String _nameOf(String type) {
    switch (type) {
      case 'pushup':
        return '俯卧撑';
      case 'lunge':
        return '弓步蹲';
      case 'jumping_jack':
        return '开合跳';
      case 'plank':
        return '平板支撑';
      default:
        return '深蹲';
    }
  }
}
