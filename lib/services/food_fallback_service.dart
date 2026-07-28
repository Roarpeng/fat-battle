import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'food_recognition_service.dart';
import 'baidu_food_service.dart';
import 'glm_food_service.dart';
import '../constants/app_constants.dart';

/// 食物识别结果
class FoodRecognitionResult {
  /// 识别出的食物列表
  final List<RecognizedFood> items;

  /// 数据来源：`glm` | `baidu` | `boohee` | `fatsecret` | `local`
  final String source;

  /// 是否识别成功（即使本地兜底也视为成功）
  final bool success;

  /// 识别过程中的错误信息（如有，用于日志展示）
  final String? error;

  /// 已尝试的数据源（用于 UI 展示降级路径）
  final List<String> attemptedSources;

  /// 各源失败原因摘要
  final List<String> failures;

  const FoodRecognitionResult({
    required this.items,
    required this.source,
    required this.success,
    this.error,
    this.attemptedSources = const [],
    this.failures = const [],
  });

  /// 供 SnackBar / 对话框使用的简短说明
  String get sourceLabel => switch (source) {
        'glm' => 'GLM-4.6V',
        'baidu' => '百度菜品识别',
        'local' => '本地推荐',
        _ => source,
      };

  @override
  String toString() =>
      'FoodRecognitionResult(source: $source, success: $success, '
      'items: ${items.length})';
}

/// 多级降级链：GLM-4.6V-FLASH → 百度 → 本地兜底
///
/// 设计说明：
/// - GLM-4.6V-Flash 是首选识别源（免费多模态大模型，识别效果最佳，支持各类食物）
/// - 百度菜品识别作为备选，在 GLM 不可用时兜底
/// - 当所有在线识别失败时，走本地兜底保证可用性
class FoodFallbackService {
  static final FoodFallbackService _instance = FoodFallbackService._internal();
  factory FoodFallbackService() => _instance;
  FoodFallbackService._internal();

  final GlmFoodService _glm = GlmFoodService();
  final BaiduFoodService _baidu = BaiduFoodService();
  final FoodRecognitionService _legacy = FoodRecognitionService();

  /// 识别食物（自动降级）
  Future<FoodRecognitionResult> recognize(File imageFile) async {
    final u8 = await imageFile.readAsBytes();
    final attempted = <String>[];
    final failures = <String>[];

    debugPrint('=== 食物识别开始 ===');
    debugPrint('图片大小: ${u8.length} 字节');
    debugPrint('GLM 已配置: ${ApiConfig.hasGlmConfig}');
    debugPrint('百度已配置: ${_baidu.isConfigured()}');

    // ===== 1. GLM-4.6V-Flash（主源） =====
    if (ApiConfig.hasGlmConfig) {
      attempted.add('GLM-4.6V');
      try {
        debugPrint('开始调用 GLM-4.6V-Flash API...');
        final glmItems = await _withRetry(
          () => _glm.recognizeFood(u8, topNum: 5, thinking: false),
        );
        debugPrint('GLM API 返回: ${glmItems.length} 个结果');
        for (var i = 0; i < glmItems.length; i++) {
          debugPrint('结果${i + 1}: ${glmItems[i].name} '
              '(置信度: ${glmItems[i].confidence.toStringAsFixed(3)}, '
              '卡路里: ${glmItems[i].calorie} kcal/100g)');
        }
        if (glmItems.isNotEmpty) {
          final items = glmItems
              .map((g) => RecognizedFood(
                    name: g.name,
                    calories: g.calorie.round(),
                    source: 'GLM-4.6V',
                    description: g.description,
                  ))
              .toList();
          return FoodRecognitionResult(
            items: items,
            source: 'glm',
            success: true,
            attemptedSources: attempted,
            failures: failures,
          );
        }
        failures.add('GLM 未识别到食物');
        debugPrint('GLM 返回空结果，降级到百度');
      } catch (e) {
        failures.add('GLM: $e');
        debugPrint('GLM 识别失败，降级到百度: $e');
      }
    } else {
      failures.add('GLM 未配置');
      debugPrint('GLM 未配置，直接走百度');
    }

    // ===== 2. 百度菜品识别（备选） =====
    if (_baidu.isConfigured()) {
      attempted.add('百度菜品识别');
      try {
        debugPrint('开始调用百度API...');
        final dishes = await _withRetry(
          () => _baidu.recognizeFood(
            u8,
            topNum: 8,
            filterThreshold: 0.5,
          ),
        );
        debugPrint('百度API返回: ${dishes.length} 个结果');
        for (var i = 0; i < dishes.length; i++) {
          debugPrint('结果${i + 1}: ${dishes[i].name} '
              '(置信度: ${dishes[i].probability}, '
              '卡路里: ${dishes[i].calorie})');
        }
        if (dishes.isNotEmpty) {
          final items = <RecognizedFood>[];
          for (final dish in dishes) {
            items.add(await _enrichBaiduDish(dish));
          }
          return FoodRecognitionResult(
            items: items,
            source: 'baidu',
            success: true,
            attemptedSources: attempted,
            failures: failures,
          );
        }
        failures.add('百度未识别到食物');
        debugPrint('百度返回空结果');
      } catch (e) {
        failures.add('百度: $e');
        debugPrint('百度识别失败，降级到本地: $e');
        return _localFallback(
          error: '百度识别失败: $e',
          attempted: attempted,
          failures: failures,
        );
      }
    } else {
      failures.add('百度未配置');
      debugPrint('百度未配置，直接走本地兜底');
    }

    // ===== 3. 本地兜底 =====
    return _localFallback(
      error: _baidu.isConfigured() ? '百度返回空' : '百度未配置',
      attempted: attempted,
      failures: failures,
    );
  }

  /// 用薄荷/FatSecret 文本搜索补全百度菜品的卡路里
  ///
  /// - 若百度已返回卡路里，直接使用；
  /// - 否则用菜名在薄荷/FatSecret 中搜索，取第一个结果作为卡路里来源；
  /// - 若都找不到，返回卡路里为 0 的菜品。
  Future<RecognizedFood> _enrichBaiduDish(BaiduDishItem dish) async {
    if (dish.hasCalorie && dish.calorie > 0) {
      return RecognizedFood(
        name: dish.name,
        calories: dish.calorie.round(),
        source: '百度',
        thumbUrl: dish.baikeImageUrl,
      );
    }

    // ===== 2. 薄荷健康文本搜索 =====
    try {
      final results = await _withRetry(
        () => _legacy.searchByText(dish.name),
        maxRetries: 1,
      );
      if (results.isNotEmpty) {
        final first = results.first;
        return RecognizedFood(
          name: dish.name,
          calories: first.calories,
          source: first.source,
          code: first.code,
          thumbUrl: dish.baikeImageUrl ?? first.thumbUrl,
          protein: first.protein,
          fat: first.fat,
          carb: first.carb,
          amountGram: first.amountGram,
        );
      }
    } catch (_) {
      // 薄荷失败，继续尝试 FatSecret（旧版 searchByText 内部已包含 FatSecret 降级，
      // 因此这里只是兜底捕获）
    }

    // ===== 4. 完全无卡路里数据 =====
    return RecognizedFood(
      name: dish.name,
      calories: 0,
      source: '百度(无卡路里)',
      thumbUrl: dish.baikeImageUrl,
    );
  }

  /// 网络错误重试（指数退避）
  Future<T> _withRetry<T>(
    Future<T> Function() fn, {
    int maxRetries = 2,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;
        // 指数退避：300ms, 600ms, ...
        await Future.delayed(
          Duration(milliseconds: 300 * (1 << (attempt - 1))),
        );
      }
    }
  }

  /// 本地兜底：返回随机本地食物
  FoodRecognitionResult _localFallback({
    String? error,
    List<String> attempted = const [],
    List<String> failures = const [],
  }) {
    final sources = [...attempted, '本地推荐'];
    final allFoods = <QuickFood>[
      ...QuickFoods.breakfast,
      ...QuickFoods.lunch,
      ...QuickFoods.dinner,
      ...QuickFoods.snack,
    ]..shuffle();
    final count = 2 + (allFoods.length % 3);
    final items = allFoods.take(count).map((f) {
      return RecognizedFood(
        name: f.name,
        calories: f.cal,
        source: '本地兜底',
      );
    }).toList();
    return FoodRecognitionResult(
      items: items,
      source: 'local',
      success: true,
      error: error,
      attemptedSources: sources,
      failures: failures,
    );
  }
}
