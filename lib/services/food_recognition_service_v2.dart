import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'baidu_food_service.dart';
import 'food_fallback_service.dart';
import 'food_recognition_service.dart';

export 'food_recognition_service.dart' show RecognizedFood;

/// 食物识别服务 V2 —— 升级版
///
/// 与旧版 [FoodRecognitionService] 的差异：
/// - 新增 [recognize] 方法：基于 [FoodFallbackService] 的三级降级链
///   （百度→薄荷→FatSecret→本地兜底）；
/// - [recognizeByImage] 保持向后兼容，内部走 V2 降级链；
/// - [searchByText] / [lookupByBarcode] 委托给旧版实现，避免行为变更。
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

  /// 文本搜索食物（委托旧版实现，行为不变）
  Future<List<RecognizedFood>> searchByText(String query) {
    return _legacy.searchByText(query);
  }

  /// 条形码查询食物（委托旧版实现，行为不变）
  Future<List<RecognizedFood>> lookupByBarcode(String barcode) {
    return _legacy.lookupByBarcode(barcode);
  }
}

/// Riverpod Provider
final foodRecognitionV2Provider =
    Provider<FoodRecognitionServiceV2>((ref) {
  return FoodRecognitionServiceV2();
});
