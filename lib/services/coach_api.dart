import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'auth_service.dart';
import 'offline_form_recap.dart';

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
    int shallowCount = 0,
    List<String> commonFaults = const [],
  }) async {
    final local = localFormRecap(
      exerciseType: exerciseType,
      repCount: repCount,
      qualityGrades: qualityGrades,
      minKneeAngle: minKneeAngle,
      durationSec: durationSec,
      avgGrade: avgGrade,
      shallowCount: shallowCount,
      commonFaults: commonFaults,
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
          'shallowCount': shallowCount,
          if (commonFaults.isNotEmpty) 'commonFaults': commonFaults,
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

  /// LLM 关闭或失败时的 2–4 句本地兑底（不依赖云端，不假装 LLM）。
  static String localFormRecap({
    required String exerciseType,
    required int repCount,
    required List<String> qualityGrades,
    double? minKneeAngle,
    required int durationSec,
    String? avgGrade,
    int shallowCount = 0,
    List<String> commonFaults = const [],
  }) {
    return OfflineFormRecap.build(
      exerciseType: exerciseType,
      repCount: repCount,
      qualityGrades: qualityGrades,
      minKneeAngle: minKneeAngle,
      durationSec: durationSec,
      avgGrade: avgGrade,
      shallowCount: shallowCount,
      commonFaults: commonFaults,
    );
  }
}
