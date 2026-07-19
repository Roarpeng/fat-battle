import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as imgLib;

import '../config/api_config.dart';

/// GLM-4.6V-Flash 食物识别结果项
class GlmFoodItem {
  /// 食物名称
  final String name;

  /// 每 100g 卡路里
  final double calorie;

  /// 置信度，范围 0~1
  final double confidence;

  /// 是否有卡路里数据
  final bool hasCalorie;

  /// 食物类别：主食/蔬菜/水果/肉类/蛋奶/零食/饮品/快餐/其他
  final String? category;

  /// 食物描述
  final String? description;

  const GlmFoodItem({
    required this.name,
    required this.calorie,
    required this.confidence,
    required this.hasCalorie,
    this.category,
    this.description,
  });

  factory GlmFoodItem.fromJson(Map<String, dynamic> json) {
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

    return GlmFoodItem(
      name: json['name']?.toString() ?? '',
      calorie: calorie,
      confidence: confidence,
      hasCalorie: json['has_calorie'] == true || (calorie > 0),
      category: json['category']?.toString(),
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'calorie': calorie,
        'confidence': confidence,
        'has_calorie': hasCalorie,
        'category': category,
        'description': description,
      };

  @override
  String toString() =>
      'GlmFoodItem(name: $name, calorie: $calorie, '
      'confidence: $confidence, category: $category)';
}

/// GLM-4.6V-Flash 食物识别服务
///
/// 直接调用智谱 GLM-4.6V-Flash 多模态大模型 API，无需后端代理。
///
/// App 端职责：
/// - 图片预处理（方向校正、缩放、格式转换、压缩）
/// - base64 编码
/// - 直接调用 https://open.bigmodel.cn/api/paas/v4/chat/completions
/// - 解析 GLM 返回的 JSON 结构化结果
class GlmFoodService {
  static final GlmFoodService _instance = GlmFoodService._internal();
  factory GlmFoodService() => _instance;
  GlmFoodService._internal();

  /// 请求超时时间（GLM-4.6V-Flash 视觉任务响应较慢，给到 45s）
  static const _timeout = Duration(seconds: 45);

  /// 图片 base64 后最大字节数
  static const _maxImageBytes = 10 * 1024 * 1024;

  /// 目标压缩大小（base64 后 2MB，GLM 对高分辨率图片识别更好，
  /// 但太大影响传输速度，2MB 是质量与速度的平衡）
  static const _targetCompressedBytes = 2 * 1024 * 1024;

  /// 推荐长边尺寸（GLM-4.6V-Flash 视觉模型在 1024-1280px 范围识别效果最佳）
  static const _targetLongEdge = 1280;

  /// 是否配置了 API Key
  bool get isConfigured => ApiConfig.zhipuApiKey.isNotEmpty;

  /// 食物识别系统提示词
  static const String _systemPrompt = '''你是专业的食物识别和营养分析专家。请识别图片中的食物，返回结构化 JSON 结果。

【重要】只输出 JSON，不要有任何其他文字、解释或代码块标记。

【输出格式】
{
  "items": [
    {
      "name": "食物名称",
      "calorie": 每100克卡路里数值,
      "confidence": 置信度0-1,
      "category": "食物类别",
      "description": "简短描述"
    }
  ]
}

【食物分类】
主食、蔬菜、水果、肉类、蛋奶、零食、饮品、快餐、其他

【卡路里参考（每100g）】
主食类：米饭116、馒头221、面条109、饺子240、包子227、面包312、煎饼336
蔬菜类：白菜17、西兰花36、番茄20、黄瓜16、胡萝卜37、土豆77、菠菜24
水果类：苹果52、香蕉89、橙子47、葡萄69、西瓜30、草莓32、梨44
肉类：猪肉143、牛肉125、鸡肉165、鱼肉113、羊肉203、鸭肉240
蛋奶类：鸡蛋143、牛奶54、酸奶72、奶酪328、豆腐70
零食类：薯片536、巧克力546、饼干433、蛋糕347、冰淇淋207
饮品类：可乐43、果汁54、奶茶80、咖啡2、啤酒43
快餐类：汉堡295、薯条298、披萨266、炸鸡240

【置信度判定标准】
0.9-1.0：非常确定，特征清晰明显
0.7-0.89：比较确定，有一些不确定因素
0.5-0.69：一般确定，可能是也可能不是
0.3-0.49：不太确定，特征模糊
<0.3：非常不确定，可能误判

【要求】
1. 识别图片中所有可辨识的食物
2. 置信度低于 0.3 的不要返回
3. calorie 填每100克的卡路里数值（千卡kcal）
4. name 用中文
5. category 从上面分类中选一个最贴切的''';

  /// 识别食物
  ///
  /// [imageBytes] 图片原始字节。
  /// [topNum] 返回候选数量，默认 5（GLM 可能返回多个）。
  /// [thinking] 是否开启深度思考模式（默认 false，追求低延迟）。
  ///
  /// 返回 [GlmFoodItem] 列表；若识别失败会抛出 [Exception]。
  Future<List<GlmFoodItem>> recognizeFood(
    Uint8List imageBytes, {
    int topNum = 5,
    bool thinking = false,
  }) async {
    if (imageBytes.isEmpty) {
      throw ArgumentError('图片字节为空');
    }
    if (imageBytes.length > _maxImageBytes) {
      throw ArgumentError('图片过大，不能超过 10MB（当前 ${imageBytes.length} 字节）');
    }
    if (!isConfigured) {
      throw Exception('GLM API Key 未配置');
    }

    debugPrint('=== GLM-4.6V-Flash 食物识别开始 ===');
    debugPrint('原始图片大小: ${imageBytes.length} 字节');
    debugPrint('thinking 模式: $thinking');
    debugPrint('API 端点: ${ApiConfig.glmApiUrl}');
    debugPrint('模型: ${ApiConfig.glmVisionModel}');

    final preprocessed = _preprocessImage(imageBytes);
    final base64Str = base64Encode(preprocessed);
    debugPrint('预处理后大小: ${preprocessed.length} 字节');
    debugPrint('base64 长度: ${base64Str.length}');

    try {
      final userContent = [
        {
          'type': 'image_url',
          'image_url': {
            'url': 'data:image/jpeg;base64,$base64Str',
          },
        },
        {
          'type': 'text',
          'text':
              '请识别这张图片中的食物，返回最多 $topNum 个结果。只输出 JSON。',
        },
      ];

      final requestBody = <String, dynamic>{
        'model': ApiConfig.glmVisionModel,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': userContent},
        ],
        'temperature': 0.3,
        'max_tokens': 2048,
      };

      if (thinking) {
        requestBody['do_sample'] = true;
      }

      debugPrint('发送请求到 GLM API...');
      final t0 = DateTime.now().millisecondsSinceEpoch;

      final response = await http
          .post(
            Uri.parse(ApiConfig.glmApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${ApiConfig.zhipuApiKey}',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      final elapsed = DateTime.now().millisecondsSinceEpoch - t0;
      debugPrint('响应状态码: ${response.statusCode} (耗时 ${elapsed}ms)');

      if (response.statusCode != 200) {
        debugPrint('HTTP错误响应: ${response.body}');
        throw Exception(
            'GLM 识别 HTTP 错误: ${response.statusCode} ${response.body}');
      }

      final Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('响应解析失败: $e');
        throw Exception('GLM 响应解析失败: $e');
      }

      // 解析 usage 信息
      final usage = data['usage'] as Map<String, dynamic>?;
      if (usage != null) {
        debugPrint(
          'Token 用量: prompt=${usage['prompt_tokens']}, '
          'completion=${usage['completion_tokens']}, '
          'total=${usage['total_tokens']}',
        );
      }

      // 提取内容
      final choices = data['choices'];
      if (choices is! List || choices.isEmpty) {
        debugPrint('choices 为空或格式错误');
        return const [];
      }

      final message = choices[0]['message'] as Map<String, dynamic>?;
      final content = message?['content']?.toString() ?? '';
      debugPrint('原始响应内容长度: ${content.length}');

      if (content.isEmpty) {
        debugPrint('响应内容为空');
        return const [];
      }

      // 从内容中提取 JSON（兼容可能的 markdown 代码块包裹）
      final jsonStr = _extractJson(content);
      if (jsonStr == null) {
        debugPrint('无法从响应中提取 JSON');
        debugPrint('内容预览: ${content.substring(0, content.length > 200 ? 200 : content.length)}');
        return const [];
      }

      final Map<String, dynamic> resultData;
      try {
        resultData = jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('JSON 解析失败: $e');
        return const [];
      }

      final resultList = resultData['items'];
      if (resultList is! List) {
        debugPrint('items 不是 List: ${resultList.runtimeType}');
        return const [];
      }

      final items = <GlmFoodItem>[];
      for (final item in resultList) {
        if (item is Map<String, dynamic>) {
          final foodItem = GlmFoodItem.fromJson(item);
          // 置信度过滤：低于 0.3 的丢弃
          if (foodItem.confidence >= 0.3) {
            items.add(foodItem);
          }
        }
      }

      debugPrint('识别结果数量: ${items.length}');
      for (var i = 0; i < items.length; i++) {
        debugPrint('结果${i + 1}: ${items[i].name} '
            '(置信度: ${items[i].confidence.toStringAsFixed(3)}, '
            '卡路里: ${items[i].calorie} kcal/100g, '
            '类别: ${items[i].category ?? 'N/A'})');
      }

      return items;
    } on TimeoutException {
      debugPrint('识别请求超时（${_timeout.inSeconds}s）');
      throw Exception('GLM 识别请求超时');
    } catch (e, stack) {
      debugPrint('识别请求失败: $e');
      debugPrint('堆栈: $stack');
      rethrow;
    }
  }

  /// 文本搜索食物（纯文本模式，无需图片）
  ///
  /// 用于条码号查询、关键词搜索等场景，让 GLM 根据文字描述
  /// 推断最可能的食物及其营养信息。
  Future<List<GlmFoodItem>> searchFoodByText(
    String query, {
    int topNum = 3,
  }) async {
    if (query.trim().isEmpty) return const [];
    if (!isConfigured) {
      throw Exception('GLM API Key 未配置');
    }

    debugPrint('=== GLM-4.6V-Flash 文本搜索食物 ===');
    debugPrint('查询词: $query');

    final systemPrompt = '''你是一个食物搜索引擎。用户输入关键词，你必须搜索并返回最匹配的食物。

规则：
1. 只输出JSON，禁止输出任何其他文字、解释、markdown标记
2. 将用户输入视为食物搜索关键词
3. 如果输入有错别字（如"酸菜睡觉"可能是"酸菜水饺"），自动纠正并搜索
4. 返回与搜索词最相关的食物，不要返回无关食物
5. 如果实在无法匹配任何食物，返回 {"items": []}

JSON格式：
{"items":[{"name":"食物中文名","calorie":每100克卡路里数值,"confidence":0到1的置信度,"category":"主食/蔬菜/水果/肉类/蛋奶/零食/饮品/快餐/其他","description":"简短描述"}]}

常见食物卡路里参考（每100g）：
米饭116、馒头221、面条109、水饺240、包子227、面包312、白菜17、西兰花36、番茄20、黄瓜16、土豆77、苹果52、香蕉89、橙子47、西瓜30、猪肉143、牛肉125、鸡肉165、鱼肉113、鸡蛋143、牛奶54、酸奶72、豆腐70、薯片536、巧克力546、饼干433、可乐43、果汁54、奶茶80、汉堡295、薯条298、披萨266、炸鸡240、方便面450

最多返回$topNum个结果，置信度低于0.3的不返回。''';

    try {
      final requestBody = <String, dynamic>{
        'model': ApiConfig.glmTextModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': '搜索：$query'},
        ],
        'temperature': 0.1,
        'max_tokens': 1024,
      };

      debugPrint('发送文本搜索请求到 GLM API...');
      final t0 = DateTime.now().millisecondsSinceEpoch;

      final response = await http
          .post(
            Uri.parse(ApiConfig.glmApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${ApiConfig.zhipuApiKey}',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      final elapsed = DateTime.now().millisecondsSinceEpoch - t0;
      debugPrint('响应状态码: ${response.statusCode} (耗时 ${elapsed}ms)');

      if (response.statusCode != 200) {
        debugPrint('HTTP错误响应: ${response.body}');
        throw Exception('GLM 文本搜索 HTTP 错误: ${response.statusCode}');
      }

      final Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('响应解析失败: $e');
        throw Exception('GLM 响应解析失败: $e');
      }

      final choices = data['choices'];
      if (choices is! List || choices.isEmpty) {
        return const [];
      }

      final message = choices[0]['message'] as Map<String, dynamic>?;
      final content = message?['content']?.toString() ?? '';
      debugPrint('原始响应内容长度: ${content.length}');

      if (content.isEmpty) return const [];

      final jsonStr = _extractJson(content);
      if (jsonStr == null) {
        debugPrint('无法从响应中提取 JSON');
        return const [];
      }

      final Map<String, dynamic> resultData;
      try {
        resultData = jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('JSON 解析失败: $e');
        return const [];
      }

      final resultList = resultData['items'];
      if (resultList is! List) return const [];

      final items = <GlmFoodItem>[];
      for (final item in resultList) {
        if (item is Map<String, dynamic>) {
          final foodItem = GlmFoodItem.fromJson(item);
          if (foodItem.confidence >= 0.3) {
            items.add(foodItem);
          }
        }
      }

      debugPrint('文本搜索结果数量: ${items.length}');
      for (var i = 0; i < items.length; i++) {
        debugPrint('结果${i + 1}: ${items[i].name} '
            '(置信度: ${items[i].confidence.toStringAsFixed(3)}, '
            '卡路里: ${items[i].calorie} kcal/100g)');
      }

      return items;
    } on TimeoutException {
      debugPrint('文本搜索请求超时');
      throw Exception('GLM 文本搜索请求超时');
    } catch (e, stack) {
      debugPrint('文本搜索请求失败: $e');
      debugPrint('堆栈: $stack');
      rethrow;
    }
  }

  /// 从响应文本中提取 JSON 对象
  /// 兼容纯 JSON、markdown 代码块包裹等情况
  String? _extractJson(String content) {
    // 先尝试直接解析
    final trimmed = content.trim();
    if (trimmed.startsWith('{')) {
      return trimmed;
    }

    // 尝试从 markdown 代码块中提取
    final codeBlockRegex = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```', caseSensitive: false);
    final match = codeBlockRegex.firstMatch(trimmed);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    // 尝试提取第一个 { 到最后一个 } 之间的内容
    final firstBrace = trimmed.indexOf('{');
    final lastBrace = trimmed.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      return trimmed.substring(firstBrace, lastBrace + 1);
    }

    return null;
  }

  /// 智能压缩图片，确保 base64 后不超过目标大小
  Uint8List _compressToTarget(
      imgLib.Image img, {int targetBytes = _targetCompressedBytes}) {
    debugPrint('=== 智能压缩 ===');
    debugPrint('原始尺寸: ${img.width}x${img.height}');

    // 从 85% 质量开始尝试，保证识别质量
    int quality = 85;
    List<int> jpgBytes = imgLib.encodeJpg(img, quality: quality);
    int base64Len = base64Encode(jpgBytes).length;

    if (base64Len <= targetBytes) {
      debugPrint('一次压缩完成，质量$quality，base64长度=$base64Len');
      return Uint8List.fromList(jpgBytes);
    }

    // 二分法逼近目标大小
    int low = 30;
    int high = quality;
    while (low < high) {
      final mid = ((low + high) / 2).ceil();
      final testBytes = imgLib.encodeJpg(img, quality: mid);
      final testLen = base64Encode(testBytes).length;
      if (testLen <= targetBytes) {
        low = mid;
        jpgBytes = testBytes;
        base64Len = testLen;
      } else {
        high = mid - 1;
      }
    }

    debugPrint('二分压缩完成，质量=$low，base64长度=$base64Len');
    return Uint8List.fromList(jpgBytes);
  }

  /// 图片预处理（方向校正 + 缩放 + 格式转换 + 压缩）
  Uint8List _preprocessImage(Uint8List imageBytes) {
    debugPrint('=== 图片预处理 ===');
    debugPrint('输入大小: ${imageBytes.length} bytes');

    final img = imgLib.decodeImage(imageBytes);
    if (img == null) {
      throw Exception('图片解码失败');
    }
    debugPrint('原始尺寸: ${img.width}x${img.height}');

    // 自动旋转：保证图片方向正确（EXIF方向校正）
    imgLib.Image oriented = imgLib.bakeOrientation(img);
    if (oriented.width != img.width || oriented.height != img.height) {
      debugPrint('方向校正: ${img.width}x${img.height} → ${oriented.width}x${oriented.height}');
    }

    // 尺寸归一化，最大边缩放到目标尺寸（GLM视觉模型最佳范围）
    imgLib.Image resized;
    final longEdge = oriented.width > oriented.height
        ? oriented.width
        : oriented.height;

    if (longEdge > _targetLongEdge) {
      if (oriented.width > oriented.height) {
        resized = imgLib.copyResize(oriented, width: _targetLongEdge);
      } else {
        resized = imgLib.copyResize(oriented, height: _targetLongEdge);
      }
      debugPrint(
          '尺寸归一化: ${oriented.width}x${oriented.height} → ${resized.width}x${resized.height}');
    } else if (longEdge < 640) {
      // 小图适当放大，提升识别效果（放大到 640px）
      if (oriented.width > oriented.height) {
        resized = imgLib.copyResize(oriented, width: 640);
      } else {
        resized = imgLib.copyResize(oriented, height: 640);
      }
      debugPrint(
          '小图放大: ${oriented.width}x${oriented.height} → ${resized.width}x${resized.height}');
    } else {
      resized = oriented;
      debugPrint('尺寸无需调整');
    }

    // 智能压缩（二分法逼近目标大小）
    final compressed = _compressToTarget(resized);
    debugPrint('预处理完成: ${compressed.length} bytes');
    return compressed;
  }
}
