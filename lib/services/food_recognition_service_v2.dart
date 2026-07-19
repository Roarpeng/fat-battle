import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'baidu_food_service.dart';
import 'food_fallback_service.dart';
import 'food_recognition_service.dart';
import 'glm_food_service.dart';

export 'food_recognition_service.dart' show RecognizedFood;

/// 食物识别服务 V2 —— 升级版
///
/// 与旧版 [FoodRecognitionService] 的差异：
/// - 新增 [recognize] 方法：基于 [FoodFallbackService] 的三级降级链
///   （百度→薄荷→FatSecret→本地兜底）；
/// - [recognizeByImage] 保持向后兼容，内部走 V2 降级链；
/// - [searchByText] / [lookupByBarcode] 增强降级链，加入 GLM 文本搜索。
///
/// 旧版服务 [FoodRecognitionService] 保留可用，不做删除。
class FoodRecognitionServiceV2 {
  static final FoodRecognitionServiceV2 _instance =
      FoodRecognitionServiceV2._internal();
  factory FoodRecognitionServiceV2() => _instance;
  FoodRecognitionServiceV2._internal();

  final FoodFallbackService _fallback = FoodFallbackService();
  final FoodRecognitionService _legacy = FoodRecognitionService();
  final BaiduFoodService _baidu = BaiduFoodService();
  final GlmFoodService _glm = GlmFoodService();

  /// 健康检查：百度凭据是否已配置
  bool get isBaiduConfigured => _baidu.isConfigured();

  /// V2 主入口：基于文件识别食物（走降级链）
  Future<FoodRecognitionResult> recognize(File imageFile) {
    return _fallback.recognize(imageFile);
  }

  /// 向后兼容入口：基于图片字节识别食物
  ///
  /// 与旧版签名一致，方便 food_page.dart 平滑切换到 V2。
  Future<List<RecognizedFood>> recognizeByImage(List<int> imageBytes) async {
    final u8 = imageBytes is Uint8List
        ? imageBytes
        : Uint8List.fromList(imageBytes);
    // 写入临时文件交给 fallback 处理
    final tmpPath = '${Directory.systemTemp.path}'
        '/fatbattle_food_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final tmp = File(tmpPath);
    try {
      await tmp.writeAsBytes(u8, flush: true);
      final result = await _fallback.recognize(tmp);
      return result.items;
    } finally {
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }

  /// 文本搜索食物（GLM 优先，legacy 兜底）
  Future<List<RecognizedFood>> searchByText(String query) async {
    // GLM 文本搜索优先
    if (_glm.isConfigured) {
      try {
        final glmResults = await _glm.searchFoodByText(query, topNum: 5);
        if (glmResults.isNotEmpty) {
          return glmResults
              .map((g) => RecognizedFood(
                    name: g.name,
                    calories: g.calorie.toInt(),
                    source: 'GLM-4V',
                    description: g.description,
                  ))
              .toList();
        }
        // GLM 返回空结果时也降级到 legacy
      } catch (e) {
        // GLM 失败时降级到 legacy，不中断流程
        debugPrint('GLM 搜索失败，降级到 legacy: $e');
      }
    }

    // legacy 兜底（薄荷健康 / FatSecret / 本地）
    try {
      final legacyResults = await _legacy.searchByText(query);
      if (legacyResults.isNotEmpty) return legacyResults;
    } catch (_) {}

    return [];
  }

  /// 条形码查询食物（增强版降级链）
  ///
  /// 降级顺序：
  /// 1. Open Food Facts（API可用，国际商品覆盖好）
  /// 2. 薄荷健康条码查询
  /// 3. FatSecret 条码查询
  /// 4. 本地常见条码库
  /// 5. GLM 文本搜索（智能推断）
  /// 6. 文本搜索兜底
  Future<List<RecognizedFood>> lookupByBarcode(String barcode) async {
    // 先走 legacy 的完整降级链
    try {
      final legacyResults = await _legacy.lookupByBarcode(barcode);
      if (legacyResults.isNotEmpty) return legacyResults;
    } catch (_) {}

    // GLM 文本搜索兜底（智能推断条码对应的食物）
    if (_glm.isConfigured) {
      try {
        final glmResults = await _glm.searchFoodByText(
          '条形码 $barcode 对应的食物是什么',
          topNum: 3,
        );
        if (glmResults.isNotEmpty) {
          return glmResults
              .map((g) => RecognizedFood(
                    name: g.name,
                    calories: g.calorie.toInt(),
                    source: 'GLM-4V(条码推断)',
                    code: barcode,
                    description: g.description,
                  ))
              .toList();
        }
      } catch (_) {}
    }

    return [];
  }
}

/// Riverpod Provider
final foodRecognitionV2Provider =
    Provider<FoodRecognitionServiceV2>((ref) {
  return FoodRecognitionServiceV2();
});
