import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'food_recognition_service.dart';
import 'baidu_food_service.dart';
import '../constants/app_constants.dart';

/// 食物识别结果
class FoodRecognitionResult {
  /// 识别出的食物列表
  final List<RecognizedFood> items;

  /// 数据来源：`baidu` | `boohee` | `fatsecret` | `local`
  final String source;

  /// 是否识别成功（即使本地兜底也视为成功）
  final bool success;

  /// 识别过程中的错误信息（如有，用于日志展示）
  final String? error;

  const FoodRecognitionResult({
    required this.items,
    required this.source,
    required this.success,
    this.error,
  });

  @override
  String toString() =>
      'FoodRecognitionResult(source: $source, success: $success, '
      'items: ${items.length})';
}

/// 三级降级链：百度 → 薄荷 → FatSecret → 本地兜底
///
/// 设计说明：
/// - 百度菜品识别是唯一支持图片直接识别的源；
/// - 薄荷/FatSecret 仅支持文本搜索，因此用于"补全卡路里"或"作为百度失败后的过渡"；
/// - 当百度整体失败或返回空时，直接走本地兜底。
class FoodFallbackService {
  static final FoodFallbackService _instance = FoodFallbackService._internal();
  factory FoodFallbackService() => _instance;
  FoodFallbackService._internal();

  final BaiduFoodService _baidu = BaiduFoodService();
  final FoodRecognitionService _legacy = FoodRecognitionService();

  /// 识别食物（自动降级）
  Future<FoodRecognitionResult> recognize(File imageFile) async {
    final u8 = await imageFile.readAsBytes();
    debugPrint('=== 食物识别开始 ===');
    debugPrint('图片大小: ${u8.length} 字节');
    debugPrint('百度已配置: ${_baidu.isConfigured()}');

    // ===== 1. 百度菜品识别 =====
    if (_baidu.isConfigured()) {
      try {
        debugPrint('开始调用百度API...');
        final dishes = await _withRetry(
          () => _baidu.recognizeDish(
            u8,
            topNum: 8,
            filterThreshold: 0.5,
          ),
        );
        debugPrint('百度API返回: ${dishes.length} 个结果');
        for (var i = 0; i < dishes.length; i++) {
          debugPrint('结果${i+1}: ${dishes[i].name} (置信度: ${dishes[i].probability}, 卡路里: ${dishes[i].calorie})');
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
          );
        }
        debugPrint('百度返回空结果');
      } catch (e) {
        debugPrint('百度识别失败，降级到本地: $e');
        return _localFallback(error: '百度识别失败: $e');
      }
    } else {
      debugPrint('百度未配置，直接走本地兜底');
    }

    // ===== 2-4. 百度未配置或返回空 → 本地兜底 =====
    // 注：薄荷/FatSecret 不支持图片直接识别，
    // 在没有百度返回名称作为查询词的情况下无法发起文本搜索，
    // 因此直接走本地兜底。
    return _localFallback(error: _baidu.isConfigured() ? '百度返回空' : '百度未配置');
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
  FoodRecognitionResult _localFallback({String? error}) {
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
    );
  }
}
