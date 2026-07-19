import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as imgLib;

import '../config/api_config.dart';

/// MiniCPM-V 食物识别结果项
class MiniCPMFoodItem {
  /// 食物名称
  final String name;

  /// 每 100g 卡路里
  final double calorie;

  /// 置信度，范围 0~1
  final double confidence;

  /// 是否有卡路里数据
  final bool hasCalorie;

  /// 食物描述
  final String? description;

  const MiniCPMFoodItem({
    required this.name,
    required this.calorie,
    required this.confidence,
    required this.hasCalorie,
    this.description,
  });

  factory MiniCPMFoodItem.fromJson(Map<String, dynamic> json) {
    final calRaw = json['calorie'];
    double calorie = 0;
    if (calRaw != null) {
      calorie = double.tryParse(calRaw.toString()) ?? 0;
    }

    final confRaw = json['confidence'];
    double confidence = 0;
    if (confRaw != null) {
      confidence = double.tryParse(confRaw.toString()) ?? 0;
    }

    return MiniCPMFoodItem(
      name: json['name']?.toString() ?? '',
      calorie: calorie,
      confidence: confidence,
      hasCalorie: json['has_calorie'] == true || (calorie > 0),
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'calorie': calorie,
        'confidence': confidence,
        'has_calorie': hasCalorie,
        'description': description,
      };

  @override
  String toString() =>
      'MiniCPMFoodItem(name: $name, calorie: $calorie, confidence: $confidence)';
}

/// MiniCPM-V 食物识别服务
///
/// 基于 MiniCPM-V 4.6 多模态大模型的食物识别服务，
/// 通过后端代理调用，API Key 不暴露到前端。
class MiniCPMFoodService {
  static final MiniCPMFoodService _instance = MiniCPMFoodService._internal();
  factory MiniCPMFoodService() => _instance;
  MiniCPMFoodService._internal();

  /// 请求超时时间
  static const _timeout = Duration(seconds: 15);

  /// 图片 base64 后最大字节数（MiniCPM-V 支持较大图片）
  static const _maxImageBytes = 10 * 1024 * 1024;

  /// 目标压缩大小（base64 后 3MB，留余量）
  static const _targetCompressedBytes = 3 * 1024 * 1024;

  /// 健康检查：后端代理是否可用
  Future<bool> isHealthy() async {
    try {
      final uri = Uri.parse('${ApiConfig.minicpmBaseUrl}/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['configured'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('MiniCPM 健康检查失败: $e');
      return false;
    }
  }

  /// 识别食物
  ///
  /// [imageBytes] 图片原始字节。
  /// [topNum] 返回候选数量，默认 5。
  ///
  /// 返回 [MiniCPMFoodItem] 列表；若识别失败会抛出 [Exception]。
  Future<List<MiniCPMFoodItem>> recognizeFood(
    Uint8List imageBytes, {
    int topNum = 5,
  }) async {
    if (imageBytes.isEmpty) {
      throw ArgumentError('图片字节为空');
    }
    if (imageBytes.length > _maxImageBytes) {
      throw ArgumentError('图片过大，不能超过 10MB（当前 ${imageBytes.length} 字节）');
    }

    debugPrint('=== MiniCPM-V 食物识别开始 ===');
    debugPrint('原始图片大小: ${imageBytes.length} 字节');

    final preprocessed = _preprocessImage(imageBytes);
    final base64Str = base64Encode(preprocessed);
    debugPrint('预处理后大小: ${preprocessed.length} 字节');
    debugPrint('base64 长度: ${base64Str.length}');

    try {
      final uri = Uri.parse('${ApiConfig.minicpmBaseUrl}/recognize');
      debugPrint('请求URL: $uri');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'image': base64Str,
              'topNum': topNum,
            }),
          )
          .timeout(_timeout);

      debugPrint('响应状态码: ${response.statusCode}');
      debugPrint('响应长度: ${response.body.length}');

      if (response.statusCode != 200) {
        debugPrint('HTTP错误响应: ${response.body}');
        throw Exception('MiniCPM-V 识别 HTTP 错误: ${response.statusCode} ${response.body}');
      }

      final Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('响应解析失败: $e');
        throw Exception('MiniCPM-V 响应解析失败: $e');
      }

      if (data['success'] != true) {
        final error = data['error'] ?? '未知错误';
        final code = data['code'] ?? 'UNKNOWN';
        debugPrint('API错误: $code / $error');
        throw Exception('MiniCPM-V 识别失败: $code / $error');
      }

      final resultList = data['items'];
      if (resultList is! List) {
        debugPrint('识别结果不是List: ${resultList.runtimeType}');
        return const [];
      }

      final items = <MiniCPMFoodItem>[];
      for (final item in resultList) {
        if (item is Map<String, dynamic>) {
          items.add(MiniCPMFoodItem.fromJson(item));
        }
      }

      debugPrint('识别结果数量: ${items.length}');
      for (var i = 0; i < items.length; i++) {
        debugPrint('结果${i + 1}: ${items[i].name} '
            '(置信度: ${items[i].confidence.toStringAsFixed(3)}, '
            '卡路里: ${items[i].calorie} kcal/100g)');
      }

      return items;
    } on TimeoutException {
      debugPrint('识别请求超时');
      throw Exception('MiniCPM-V 识别请求超时');
    } catch (e) {
      debugPrint('识别请求失败: $e');
      rethrow;
    }
  }

  /// 智能压缩图片，确保 base64 后不超过目标大小
  Uint8List _compressToTarget(imgLib.Image img, {int targetBytes = _targetCompressedBytes}) {
    debugPrint('=== 智能压缩 ===');
    debugPrint('原始尺寸: ${img.width}x${img.height}');

    final jpgBytes = imgLib.encodeJpg(img, quality: 70);
    final base64Len = base64Encode(jpgBytes).length;

    if (base64Len <= targetBytes) {
      debugPrint('一次压缩完成，质量70，base64长度=$base64Len');
      return Uint8List.fromList(jpgBytes);
    }

    final targetQuality = (70 * targetBytes / base64Len).round().clamp(40, 70);
    debugPrint('需要二次压缩，目标质量=$targetQuality');
    final finalBytes = imgLib.encodeJpg(img, quality: targetQuality);
    debugPrint('二次压缩完成，base64长度=${base64Encode(finalBytes).length}');
    return Uint8List.fromList(finalBytes);
  }

  /// 图片预处理
  Uint8List _preprocessImage(Uint8List imageBytes) {
    debugPrint('=== 图片预处理 ===');
    debugPrint('输入大小: ${imageBytes.length} bytes');

    final img = imgLib.decodeImage(imageBytes);
    if (img == null) {
      throw Exception('图片解码失败');
    }
    debugPrint('原始尺寸: ${img.width}x${img.height}');

    // 尺寸归一化，最大边缩放到 1280px（MiniCPM-V 支持较高分辨率）
    imgLib.Image resized;
    if (img.width > img.height) {
      if (img.width > 1280) {
        resized = imgLib.copyResize(img, width: 1280);
        debugPrint('尺寸归一化: ${img.width}x${img.height} → ${resized.width}x${resized.height}');
      } else {
        resized = img;
        debugPrint('尺寸无需归一化');
      }
    } else {
      if (img.height > 1280) {
        resized = imgLib.copyResize(img, height: 1280);
        debugPrint('尺寸归一化: ${img.width}x${img.height} → ${resized.width}x${resized.height}');
      } else {
        resized = img;
        debugPrint('尺寸无需归一化');
      }
    }

    // 智能压缩
    final compressed = _compressToTarget(resized);
    debugPrint('预处理完成: ${compressed.length} bytes');
    return compressed;
  }
}
