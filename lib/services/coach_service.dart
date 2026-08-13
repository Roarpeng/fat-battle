import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../core/coach_safety.dart';
import 'auth_service.dart';

/// 营养教练客户端：走后端 `POST /api/v1/coach/turn`，密钥不进 APK。
class CoachService {
  CoachService._();
  static final CoachService instance = CoachService._();
  factory CoachService() => instance;

  bool get isAvailable => ApiConfig.isBackendEnabled;

  Future<CoachTurnResult> turn({
    required String message,
    required CoachTurnContext context,
    List<Map<String, String>> history = const [],
  }) async {
    if (!isAvailable) {
      return CoachTurnResult(
        reply: context.localAnswer(message),
        fromLocal: true,
      );
    }

    try {
      final response = await AuthService().authedPost(
        '/api/v1/coach/turn',
        body: {
          'message': message,
          'history': history,
          'context': context.toJson(),
        },
      );
      if (response.statusCode == 429) {
        return CoachTurnResult(
          reply: '问得太勤，炉子要歇一会儿。先看一眼剩余预算：还剩 ${context.budget['remainingCal']} kcal。',
          fromLocal: true,
        );
      }
      if (response.statusCode != 200) {
        debugPrint('CoachService HTTP ${response.statusCode}: ${response.body}');
        return CoachTurnResult(
          reply: context.localAnswer(message),
          fromLocal: true,
        );
      }
      final data = jsonDecode(response.body);
      if (data is! Map || data['success'] != true) {
        return CoachTurnResult(
          reply: context.localAnswer(message),
          fromLocal: true,
        );
      }
      final rawReply = data['reply']?.toString() ?? '';
      final filteredServer = data['filtered'] == true;
      final local = CoachSafety.filter(
        rawReply,
        floor: context.calorieFloor,
      );
      final logs = <CoachProposedLog>[];
      if (!local.filtered) {
        final rawLogs = data['proposedLogs'];
        if (rawLogs is List) {
          for (final item in rawLogs) {
            if (item is Map) {
              final log = CoachProposedLog.fromJson(
                Map<String, dynamic>.from(item),
              );
              if (log.name.isNotEmpty) logs.add(log);
            }
          }
        }
      }
      return CoachTurnResult(
        reply: local.text,
        filtered: filteredServer || local.filtered,
        proposedLogs: logs,
      );
    } catch (e) {
      debugPrint('CoachService 失败，走本地回答: $e');
      return CoachTurnResult(
        reply: context.localAnswer(message),
        fromLocal: true,
      );
    }
  }
}
