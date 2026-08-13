import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'auth_service.dart';

/// 识别纠错反馈：用户改了菜名/克数后回传后端 `POST /api/v1/food/feedback`。
class FoodFeedbackService {
  FoodFeedbackService._();
  static final FoodFeedbackService instance = FoodFeedbackService._();
  factory FoodFeedbackService() => instance;

  /// 与识别结果不一致时上报；未连后端则静默跳过。
  Future<void> submitCorrection({
    required String originalName,
    required String correctedName,
    required int originalGrams,
    required int correctedGrams,
    required int caloriePer100g,
    required int userCal,
    String? imageUrl,
  }) async {
    final nameChanged = originalName.trim() != correctedName.trim();
    final gramsChanged = originalGrams != correctedGrams;
    if (!nameChanged && !gramsChanged) return;
    if (!ApiConfig.isBackendEnabled) return;

    try {
      final resp = await AuthService().authedPost(
        '/api/v1/food/feedback',
        body: {
          if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
          'ocr_result': {
            'original_name': originalName,
            'corrected_name': correctedName,
            'original_grams': originalGrams,
            'corrected_grams': correctedGrams,
            'calorie_per_100g': caloriePer100g,
          },
          'user_cal': userCal,
        },
      );
      if (resp.statusCode != 200) {
        debugPrint('FoodFeedback HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      debugPrint('FoodFeedback 上报失败（忽略）: $e');
    }
  }
}
