import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'baidu_food_service.dart';
import 'food_fallback_service.dart';
import 'food_recognition_service.dart';
import 'glm_food_service.dart';
import '../config/api_config.dart';

export 'food_fallback_service.dart' show FoodRecognitionResult;
export 'food_recognition_service.dart' show RecognizedFood;

/// 文本/条码查询结果（含降级路径，供 UI 展示）
class FoodQueryResult {
  final List<RecognizedFood> items;
  final List<String> attemptedSources;
  final List<String> failures;

  const FoodQueryResult({
    required this.items,
    this.attemptedSources = const [],
    this.failures = const [],
  });

  bool get isEmpty => items.isEmpty;

  /// 全失败时的用户可读说明
  String get emptyMessage {
    if (items.isNotEmpty) return '';
    final tried = attemptedSources.isEmpty
        ? '未尝试在线查询'
        : '已尝试：${attemptedSources.join(' → ')}';
    final detail = failures.isEmpty ? '' : '\n${failures.join('\n')}';
    return '$tried$detail';
  }
}

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

  /// 健康检查：GLM 是否已配置（真实后端代理 / 直连 Key / 旧代理）
  bool get isGlmConfigured =>
      ApiConfig.isBackendEnabled || _glm.isConfigured;

  /// 拍照识别是否至少有一个在线源（真实后端代理也算已配置）
  bool get hasAnyVisionConfig => ApiConfig.hasAnyFoodVisionConfig;

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
    return (await searchByTextDetailed(query)).items;
  }

  /// 文本搜索（含降级路径元数据）
  Future<FoodQueryResult> searchByTextDetailed(String query) async {
    if (query.trim().isEmpty) {
      return const FoodQueryResult(items: []);
    }

    final attempted = <String>[];
    final failures = <String>[];

    // GLM 文本搜索优先
    if (_glm.isConfigured) {
      attempted.add('GLM-4V');
      try {
        final glmResults = await _glm.searchFoodByText(query, topNum: 5);
        if (glmResults.isNotEmpty) {
          return FoodQueryResult(
            items: glmResults
                .map((g) => RecognizedFood(
                      name: g.name,
                      calories: g.calorie.toInt(),
                      source: 'GLM-4V',
                      description: g.description,
                    ))
                .toList(),
            attemptedSources: attempted,
            failures: failures,
          );
        }
        failures.add('GLM 未找到匹配');
      } catch (e) {
        failures.add('GLM: $e');
        debugPrint('GLM 搜索失败，降级到 legacy: $e');
      }
    } else {
      failures.add('GLM 未配置');
    }

    // legacy 兜底（薄荷健康 / FatSecret / 本地）
    attempted.add('薄荷/FatSecret/本地');
    try {
      final legacyResults = await _legacy.searchByText(query);
      if (legacyResults.isNotEmpty) {
        return FoodQueryResult(
          items: legacyResults,
          attemptedSources: attempted,
          failures: failures,
        );
      }
      failures.add('在线与本地库均未找到「$query」');
    } catch (e) {
      failures.add('搜索服务: $e');
    }

    return FoodQueryResult(
      items: [],
      attemptedSources: attempted,
      failures: failures,
    );
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
    return (await lookupByBarcodeDetailed(barcode)).items;
  }

  /// 条形码查询（含降级路径元数据）
  Future<FoodQueryResult> lookupByBarcodeDetailed(String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) {
      return const FoodQueryResult(
        items: [],
        failures: ['条形码为空'],
      );
    }

    final attempted = <String>[];
    final failures = <String>[];

    // 先走 legacy 的完整降级链
    attempted.add('OpenFoodFacts/薄荷/FatSecret/本地条码库');
    try {
      final legacyResults = await _legacy.lookupByBarcode(clean);
      if (legacyResults.isNotEmpty) {
        return FoodQueryResult(
          items: legacyResults,
          attemptedSources: attempted,
          failures: failures,
        );
      }
      failures.add('条码库未收录 $clean');
    } catch (e) {
      failures.add('条码查询: $e');
    }

    // GLM 文本搜索兜底（智能推断条码对应的食物）
    if (_glm.isConfigured) {
      attempted.add('GLM-4V(推断)');
      try {
        final glmResults = await _glm.searchFoodByText(
          '条形码 $clean 对应的食物是什么',
          topNum: 3,
        );
        if (glmResults.isNotEmpty) {
          return FoodQueryResult(
            items: glmResults
                .map((g) => RecognizedFood(
                      name: g.name,
                      calories: g.calorie.toInt(),
                      source: 'GLM-4V(条码推断)',
                      code: clean,
                      description: g.description,
                    ))
                .toList(),
            attemptedSources: attempted,
            failures: failures,
          );
        }
        failures.add('GLM 未能推断该条码');
      } catch (e) {
        failures.add('GLM: $e');
      }
    } else {
      failures.add('GLM 未配置');
    }

    return FoodQueryResult(
      items: [],
      attemptedSources: attempted,
      failures: failures,
    );
  }
}

/// Riverpod Provider
final foodRecognitionV2Provider =
    Provider<FoodRecognitionServiceV2>((ref) {
  return FoodRecognitionServiceV2();
});
