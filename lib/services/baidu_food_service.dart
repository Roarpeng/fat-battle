import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as imgLib;

import '../config/api_config.dart';

/// 百度菜品识别 API 返回的单个菜品项
class BaiduDishItem {
  /// 菜品名称
  final String name;

  /// 每 100g 卡路里（无数据时为 0）
  final double calorie;

  /// 置信度，范围 0~1
  final double probability;

  /// 是否有卡路里数据
  final bool hasCalorie;

  /// 百科链接
  final String? baikeUrl;

  /// 百科图片 URL
  final String? baikeImageUrl;

  /// 百科描述
  final String? baikeDescription;

  const BaiduDishItem({
    required this.name,
    required this.calorie,
    required this.probability,
    required this.hasCalorie,
    this.baikeUrl,
    this.baikeImageUrl,
    this.baikeDescription,
  });

  factory BaiduDishItem.fromJson(Map<String, dynamic> json) {
    // 卡路里字段可能为空字符串或数字
    final calRaw = json['calorie'];
    double calorie = 0;
    if (calRaw != null) {
      calorie = double.tryParse(calRaw.toString()) ?? 0;
    }
    // 概率字段
    final probRaw = json['probability'];
    double probability = 0;
    if (probRaw != null) {
      probability = double.tryParse(probRaw.toString()) ?? 0;
    }
    // 百科信息
    final baike = json['baike_info'];
    String? baikeUrl;
    String? baikeImageUrl;
    String? baikeDescription;
    if (baike is Map<String, dynamic>) {
      baikeUrl = baike['baike_url']?.toString();
      baikeImageUrl = baike['image_url']?.toString();
      baikeDescription = baike['description']?.toString();
    }

    return BaiduDishItem(
      name: json['name']?.toString() ?? '',
      calorie: calorie,
      probability: probability,
      hasCalorie: json['has_calorie'] == true || (calorie > 0),
      baikeUrl: baikeUrl,
      baikeImageUrl: baikeImageUrl,
      baikeDescription: baikeDescription,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'calorie': calorie,
        'probability': probability,
        'has_calorie': hasCalorie,
        'baike_url': baikeUrl,
        'baike_image_url': baikeImageUrl,
        'baike_description': baikeDescription,
      };

  @override
  String toString() =>
      'BaiduDishItem(name: $name, calorie: $calorie, probability: $probability, hasCalorie: $hasCalorie)';
}

/// 百度菜品识别 API 客户端
///
/// 负责 access_token 的获取与缓存，以及菜品识别请求。
/// Token 缓存在内存中，过期前 5 分钟自动刷新；
/// 请求遇到 token 失效错误码时强制刷新并重试一次。
class BaiduFoodService {
  static final BaiduFoodService _instance = BaiduFoodService._internal();
  factory BaiduFoodService() => _instance;
  BaiduFoodService._internal();

  // ===== Token 缓存（内存级） =====
  String? _accessToken;
  DateTime? _tokenExpiresAt;
  // 防止并发获取 token 时多次请求
  Future<String>? _tokenFetchFuture;

  /// 请求超时时间
  static const _timeout = Duration(seconds: 15);

  /// 图片 base64 后最大字节数（4MB）
  static const _maxImageBytes = 4 * 1024 * 1024;

  /// 目标压缩大小（base64 后 2MB，留余量）
  static const _targetCompressedBytes = 2 * 1024 * 1024;

  /// 健康检查：是否已配置百度凭据
  bool isConfigured() => ApiConfig.hasBaiduCredentials;

  /// 清除 token 缓存（用于手动刷新或测试）
  void clearTokenCache() {
    _accessToken = null;
    _tokenExpiresAt = null;
    _tokenFetchFuture = null;
  }

  /// 获取 access_token（带缓存与并发去重）
  ///
  /// 缓存有效期到过期前 5 分钟为止；过期或不存在时自动刷新。
  /// [forceRefresh=true] 时强制刷新。
  Future<String> _getAccessToken({bool forceRefresh = false}) async {
    if (!isConfigured()) {
      throw StateError('百度 API 凭据未配置，请通过 --dart-define 注入 '
          'BAIDU_API_KEY 与 BAIDU_SECRET_KEY');
    }

    // 缓存命中
    if (!forceRefresh &&
        _accessToken != null &&
        _tokenExpiresAt != null &&
        DateTime.now().isBefore(_tokenExpiresAt!.subtract(const Duration(minutes: 5)))) {
      return _accessToken!;
    }

    // 并发去重：避免多个调用同时刷新 token
    if (_tokenFetchFuture != null) {
      return _tokenFetchFuture!;
    }

    _tokenFetchFuture = _fetchAccessToken().whenComplete(() {
      _tokenFetchFuture = null;
    });
    return _tokenFetchFuture!;
  }

  Future<String> _fetchAccessToken() async {
    debugPrint('=== 获取百度 Access Token ===');
    debugPrint('API Key: ${ApiConfig.baiduApiKey.isNotEmpty ? '已配置' : '未配置'}');
    debugPrint('Secret Key: ${ApiConfig.baiduSecretKey.isNotEmpty ? '已配置' : '未配置'}');

    final uri = Uri.parse(ApiConfig.baiduTokenUrl).replace(queryParameters: {
      'grant_type': 'client_credentials',
      'client_id': ApiConfig.baiduApiKey,
      'client_secret': ApiConfig.baiduSecretKey,
    });

    debugPrint('请求URL: ${uri.toString()}');
    final response = await http.post(uri).timeout(_timeout);
    debugPrint('Token请求状态码: ${response.statusCode}');
    debugPrint('Token响应长度: ${response.body.length}');

    if (response.statusCode != 200) {
      debugPrint('Token获取失败响应: ${response.body}');
      throw Exception('百度 access_token 获取失败: HTTP ${response.statusCode} '
          '${response.body}');
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Token响应解析失败: $e');
      throw Exception('百度 access_token 响应解析失败: $e');
    }

    final token = data['access_token']?.toString();
    if (token == null || token.isEmpty) {
      final err = data['error'] ?? 'unknown';
      final errDesc = data['error_description'] ?? '';
      debugPrint('Token为空: $err / $errDesc');
      throw Exception('百度 access_token 获取失败: $err / $errDesc');
    }

    debugPrint('Token获取成功，长度: ${token.length}');
    final expiresInSec = (data['expires_in'] is int)
        ? (data['expires_in'] as int)
        : int.tryParse(data['expires_in'].toString()) ?? 2592000;

    _accessToken = token;
    _tokenExpiresAt = DateTime.now().add(Duration(seconds: expiresInSec));
    return token;
  }

  /// 识别菜品
  ///
  /// [imageBytes] 图片原始字节。
  /// [topNum] 返回候选数量，默认 5。
  /// [filterThreshold] 置信度过滤阈值（0~1），默认 0.8。
  ///
  /// 返回 [BaiduDishItem] 列表；若识别失败会抛出 [Exception]。
  Future<List<BaiduDishItem>> recognizeDish(
    Uint8List imageBytes, {
    int topNum = 5,
    double filterThreshold = 0.8,
  }) async {
    return _recognizeInternal(
      imageBytes: imageBytes,
      apiUrl: ApiConfig.baiduDishUrl,
      topNum: topNum,
      filterThreshold: filterThreshold,
      apiName: '百度菜品识别',
    );
  }

  /// 识别果蔬
  ///
  /// [imageBytes] 图片原始字节。
  /// [topNum] 返回候选数量，默认 5。
  ///
  /// 返回 [BaiduDishItem] 列表；若识别失败会抛出 [Exception]。
  Future<List<BaiduDishItem>> recognizeIngredient(
    Uint8List imageBytes, {
    int topNum = 5,
  }) async {
    return _recognizeInternal(
      imageBytes: imageBytes,
      apiUrl: ApiConfig.baiduIngredientUrl,
      topNum: topNum,
      filterThreshold: 0.0,
      apiName: '百度果蔬识别',
    );
  }

  Future<List<BaiduDishItem>> _recognizeInternal({
    required Uint8List imageBytes,
    required String apiUrl,
    required int topNum,
    required double filterThreshold,
    required String apiName,
  }) async {
    if (imageBytes.isEmpty) {
      throw ArgumentError('图片字节为空');
    }
    if (imageBytes.length > _maxImageBytes) {
      throw ArgumentError('图片过大，base64 后不能超过 4MB（当前 ${imageBytes.length} 字节）');
    }

    final base64Str = base64Encode(imageBytes);

    try {
      return await _doRecognize(
        base64Str: base64Str,
        apiUrl: apiUrl,
        topNum: topNum,
        filterThreshold: filterThreshold,
        apiName: apiName,
        forceTokenRefresh: false,
      );
    } on _TokenInvalidException {
      return await _doRecognize(
        base64Str: base64Str,
        apiUrl: apiUrl,
        topNum: topNum,
        filterThreshold: filterThreshold,
        apiName: apiName,
        forceTokenRefresh: true,
      );
    }
  }

  Future<List<BaiduDishItem>> _doRecognize({
    required String base64Str,
    required String apiUrl,
    required int topNum,
    required double filterThreshold,
    required String apiName,
    required bool forceTokenRefresh,
  }) async {
    debugPrint('=== 调用$apiName ===');
    debugPrint('base64长度: ${base64Str.length}');
    debugPrint('topNum: $topNum, filterThreshold: $filterThreshold');

    final token = await _getAccessToken(forceRefresh: forceTokenRefresh);
    debugPrint('Token已获取，长度: ${token.length}');

    final uri = Uri.parse(apiUrl)
        .replace(queryParameters: {'access_token': token});

    debugPrint('识别请求URL: ${uri.toString().substring(0, 50)}...');

    final body = <String, String>{
      'image': base64Str,
      'top_num': topNum.toString(),
      'filter_threshold': filterThreshold.toString(),
    };

    debugPrint('请求体大小: image=${base64Str.length}');

    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: body,
          )
          .timeout(_timeout);
      debugPrint('识别请求状态码: ${response.statusCode}');
      debugPrint('识别响应长度: ${response.body.length}');
    } on TimeoutException {
      debugPrint('识别请求超时');
      throw Exception('百度菜品识别请求超时');
    } catch (e) {
      debugPrint('识别请求失败: $e');
      throw Exception('百度菜品识别请求失败: $e');
    }

    if (response.statusCode != 200) {
      debugPrint('识别HTTP错误响应: ${response.body}');
      throw Exception('$apiName HTTP 错误: ${response.statusCode} ${response.body}');
    }

    debugPrint('识别响应前1000字符: ${response.body.substring(0, response.body.length > 1000 ? 1000 : response.body.length)}');

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('识别响应解析失败: $e');
      throw Exception('$apiName 响应解析失败: $e');
    }

    // 错误码处理
    // 参考：https://ai.baidu.com/ai-doc/IMAGERECOGNITION/Xk3bcxe9l
    final errorCode = data['error_code'];
    if (errorCode != null) {
      final errorMsg = data['error_msg']?.toString() ?? '未知错误';
      debugPrint('识别API错误: $errorCode / $errorMsg');
      // token 相关错误：110/111 -> access_token 无效或过期
      if (errorCode == 110 || errorCode == 111) {
        throw _TokenInvalidException(errorMsg);
      }
      throw Exception('$apiName API 错误: $errorCode / $errorMsg');
    }

    final resultList = data['result'];
    if (resultList is! List) {
      debugPrint('识别结果不是List: ${resultList.runtimeType}');
      return const [];
    }

    debugPrint('识别结果数量: ${resultList.length}');
    final items = <BaiduDishItem>[];
    for (final item in resultList) {
      if (item is Map<String, dynamic>) {
        items.add(BaiduDishItem.fromJson(item));
      }
    }
    return items;
  }

  /// 智能压缩图片，确保 base64 后不超过目标大小
  Uint8List _compressToTarget(imgLib.Image img, {int targetBytes = _targetCompressedBytes}) {
    debugPrint('=== 智能压缩 ===');
    debugPrint('原始尺寸: ${img.width}x${img.height}');

    var quality = 85;
    Uint8List result;

    while (quality >= 40) {
      final jpgBytes = imgLib.encodeJpg(img, quality: quality);
      final base64Len = base64Encode(jpgBytes).length;
      debugPrint('质量$quality: base64长度=$base64Len (目标=$targetBytes)');

      if (base64Len <= targetBytes) {
        result = Uint8List.fromList(jpgBytes);
        debugPrint('压缩完成，最终质量: $quality');
        return result;
      }

      quality -= 10;
    }

    final jpgBytes = imgLib.encodeJpg(img, quality: 40);
    result = Uint8List.fromList(jpgBytes);
    debugPrint('已达最低质量40，base64长度: ${base64Encode(result).length}');
    return result;
  }

  /// 图片预处理流水线
  _PreprocessedImage _preprocessImage(Uint8List imageBytes) {
    debugPrint('=== 图片预处理流水线 ===');
    debugPrint('输入大小: ${imageBytes.length} bytes');

    final img = imgLib.decodeImage(imageBytes);
    if (img == null) {
      throw Exception('图片解码失败');
    }
    debugPrint('原始尺寸: ${img.width}x${img.height}');

    // 步骤1：尺寸归一化，最大边缩放到 1024px
    imgLib.Image resized;
    if (img.width > img.height) {
      if (img.width > 1024) {
        resized = imgLib.copyResize(img, width: 1024);
        debugPrint('尺寸归一化: ${img.width}x${img.height} → ${resized.width}x${resized.height}');
      } else {
        resized = img;
        debugPrint('尺寸无需归一化');
      }
    } else {
      if (img.height > 1024) {
        resized = imgLib.copyResize(img, height: 1024);
        debugPrint('尺寸归一化: ${img.width}x${img.height} → ${resized.width}x${resized.height}');
      } else {
        resized = img;
        debugPrint('尺寸无需归一化');
      }
    }

    // 步骤2：自动裁剪边缘纯色区域
    final cropped = _autoCropBorders(resized);
    debugPrint('自动裁剪: ${resized.width}x${resized.height} → ${cropped.width}x${cropped.height}');

    // 步骤3：生成 ROI 中心裁剪图（四周各裁 15%）
    final roiW = (cropped.width * 0.7).round();
    final roiH = (cropped.height * 0.7).round();
    final roiX = (cropped.width - roiW) ~/ 2;
    final roiY = (cropped.height - roiH) ~/ 2;
    final roiImg = imgLib.copyCrop(cropped, x: roiX, y: roiY, width: roiW, height: roiH);
    debugPrint('ROI裁剪: ${cropped.width}x${cropped.height} → ${roiImg.width}x${roiImg.height}');

    // 步骤4：智能压缩
    final fullBytes = _compressToTarget(cropped);
    final roiBytes = _compressToTarget(roiImg);

    debugPrint('预处理完成: full=${fullBytes.length} bytes, roi=${roiBytes.length} bytes');

    return _PreprocessedImage(
      fullBytes: fullBytes,
      roiBytes: roiBytes,
    );
  }

  /// 综合识别：智能分级识别
  Future<List<BaiduDishItem>> recognizeFood(
    Uint8List imageBytes, {
    int topNum = 5,
    double filterThreshold = 0.5,
  }) async {
    if (imageBytes.isEmpty) {
      throw ArgumentError('图片字节为空');
    }

    debugPrint('=== 智能分级识别开始 ===');

    // 预处理
    final preprocessed = _preprocessImage(imageBytes);

    // 第1级：ROI中心裁剪图
    debugPrint('--- 第1级：ROI中心裁剪图 ---');
    var level1Items = await _recognizeSingleImage(
      preprocessed.roiBytes,
      topNum: topNum,
      filterThreshold: filterThreshold,
    );
    level1Items = _filterValidItems(level1Items);
    final level1Best = level1Items.isNotEmpty ? level1Items.first.probability : 0.0;
    debugPrint('第1级最佳置信度: $level1Best');

    if (level1Best >= 0.5) {
      debugPrint('第1级命中，直接返回');
      return level1Items;
    }

    // 第2级：全图（去边后）
    debugPrint('--- 第2级：全图（去边后） ---');
    var level2Items = await _recognizeSingleImage(
      preprocessed.fullBytes,
      topNum: topNum,
      filterThreshold: filterThreshold,
    );
    level2Items = _filterValidItems(level2Items);
    final level2Best = level2Items.isNotEmpty ? level2Items.first.probability : 0.0;
    debugPrint('第2级最佳置信度: $level2Best');

    if (level2Best >= 0.5) {
      debugPrint('第2级命中，直接返回');
      return level2Items;
    }

    // 第3级：全图（去边后）旋转90°
    debugPrint('--- 第3级：全图旋转90° ---');
    final fullImg = imgLib.decodeImage(preprocessed.fullBytes);
    if (fullImg != null) {
      final rotated = imgLib.copyRotate(fullImg, angle: 90);
      final rotatedBytes = _compressToTarget(rotated);
      var level3Items = await _recognizeSingleImage(
        rotatedBytes,
        topNum: topNum,
        filterThreshold: filterThreshold,
      );
      level3Items = _filterValidItems(level3Items);
      final level3Best = level3Items.isNotEmpty ? level3Items.first.probability : 0.0;
      debugPrint('第3级最佳置信度: $level3Best');

      if (level3Best >= 0.5) {
        debugPrint('第3级命中，直接返回');
        return level3Items;
      }
    } else {
      debugPrint('第3级跳过：图片解码失败');
    }

    // 第4级：全图（去边后）→ 组合服务
    debugPrint('--- 第4级：组合服务兜底 ---');
    final base64Str = base64Encode(preprocessed.fullBytes);
    final comboItems = await _callCombinationApi(base64Str);
    final validCombo = _filterValidItems(comboItems);
    debugPrint('第4级组合服务结果数: ${validCombo.length}');

    if (validCombo.isNotEmpty) {
      debugPrint('第4级命中，返回组合服务结果');
      return validCombo;
    }

    // 全部失败，返回所有级别中最好的结果（如果有的话）
    debugPrint('所有级别均未达到阈值，返回最佳可用结果');
    final allCandidates = <List<BaiduDishItem>>[level1Items, level2Items];
    allCandidates.sort((a, b) {
      final aBest = a.isNotEmpty ? a.first.probability : 0.0;
      final bBest = b.isNotEmpty ? b.first.probability : 0.0;
      return bBest.compareTo(aBest);
    });

    for (final candidate in allCandidates) {
      if (candidate.isNotEmpty) {
        return candidate;
      }
    }

    return [];
  }

  /// 过滤有效菜品项（排除"非菜"和以"非"开头的结果）
  List<BaiduDishItem> _filterValidItems(List<BaiduDishItem> items) {
    return items.where((d) =>
        d.name != '非菜' &&
        !d.name.startsWith('非') &&
        d.probability > 0.1,
    ).toList();
  }

  /// 识别单张图片（并行调用菜品+组合服务）
  Future<List<BaiduDishItem>> _recognizeSingleImage(
    Uint8List imageBytes, {
    required int topNum,
    required double filterThreshold,
  }) async {
    final base64Str = base64Encode(imageBytes);
    final allItems = <BaiduDishItem>[];

    final results = await Future.wait([
      _callDishApi(base64Str, topNum: topNum, filterThreshold: filterThreshold),
      _callCombinationApi(base64Str),
    ], eagerError: false);

    final dishItems = results[0] as List<BaiduDishItem>;
    final validDishes = dishItems.where((d) => d.name != '非菜').toList();
    allItems.addAll(validDishes);

    final comboItems = results[1] as List<BaiduDishItem>;
    final validCombos = comboItems.where((d) =>
        !d.name.startsWith('非') && d.probability > 0.1).toList();
    for (final item in validCombos) {
      if (!allItems.any((e) => e.name == item.name)) {
        allItems.add(item);
      }
    }

    allItems.sort((a, b) => b.probability.compareTo(a.probability));
    return allItems;
  }

  /// 调用菜品识别API
  Future<List<BaiduDishItem>> _callDishApi(
    String base64Str, {
    required int topNum,
    required double filterThreshold,
  }) async {
    try {
      return await _doRecognize(
        base64Str: base64Str,
        apiUrl: ApiConfig.baiduDishUrl,
        topNum: topNum,
        filterThreshold: filterThreshold,
        apiName: '百度菜品识别',
        forceTokenRefresh: false,
      );
    } on _TokenInvalidException {
      return await _doRecognize(
        base64Str: base64Str,
        apiUrl: ApiConfig.baiduDishUrl,
        topNum: topNum,
        filterThreshold: filterThreshold,
        apiName: '百度菜品识别',
        forceTokenRefresh: true,
      );
    } catch (e) {
      debugPrint('菜品识别失败: $e');
      return [];
    }
  }

  /// 调用组合服务API（果蔬+植物+动物，一次请求）
  Future<List<BaiduDishItem>> _callCombinationApi(String base64Str) async {
    try {
      final token = await _getAccessToken();
      final uri = Uri.parse(
        'https://aip.baidubce.com/api/v1/solution/direct/imagerecognition/combination'
      ).replace(queryParameters: {'access_token': token});

      final payload = {
        'image': base64Str,
        'scenes': ['ingredient', 'plant', 'animal'],
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('组合服务HTTP错误: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['error_code'] != null) {
        debugPrint('组合服务API错误: ${data['error_msg']}');
        return [];
      }

      final result = data['result'] as Map<String, dynamic>?;
      if (result == null) return [];

      final items = <BaiduDishItem>[];

      // 解析果蔬识别结果
      final ingredient = result['ingredient'] as Map<String, dynamic>?;
      if (ingredient != null) {
        final ingredientResults = ingredient['result'] as List?;
        if (ingredientResults != null) {
          for (final item in ingredientResults) {
            if (item is Map<String, dynamic>) {
              items.add(BaiduDishItem(
                name: item['name']?.toString() ?? '',
                calorie: 0,
                probability: (item['score'] is num)
                    ? (item['score'] as num).toDouble()
                    : double.tryParse(item['score'].toString()) ?? 0,
                hasCalorie: false,
              ));
            }
          }
        }
      }

      // 解析植物识别结果
      final plant = result['plant'] as Map<String, dynamic>?;
      if (plant != null) {
        final plantResults = plant['result'] as List?;
        if (plantResults != null) {
          for (final item in plantResults) {
            if (item is Map<String, dynamic>) {
              final name = item['name']?.toString() ?? '';
              final score = (item['score'] is num)
                  ? (item['score'] as num).toDouble()
                  : double.tryParse(item['score'].toString()) ?? 0;
              // 去重
              if (!items.any((e) => e.name == name)) {
                items.add(BaiduDishItem(
                  name: name,
                  calorie: 0,
                  probability: score,
                  hasCalorie: false,
                ));
              }
            }
          }
        }
      }

      // 解析动物识别结果
      final animal = result['animal'] as Map<String, dynamic>?;
      if (animal != null) {
        final animalResults = animal['result'] as List?;
        if (animalResults != null) {
          for (final item in animalResults) {
            if (item is Map<String, dynamic>) {
              final name = item['name']?.toString() ?? '';
              final score = (item['score'] is num)
                  ? (item['score'] as num).toDouble()
                  : double.tryParse(item['score'].toString()) ?? 0;
              if (!items.any((e) => e.name == name)) {
                items.add(BaiduDishItem(
                  name: name,
                  calorie: 0,
                  probability: score,
                  hasCalorie: false,
                ));
              }
            }
          }
        }
      }

      debugPrint('组合服务返回${items.length}个结果');
      return items;
    } catch (e) {
      debugPrint('组合服务调用失败: $e');
      return [];
    }
  }

  /// 自动裁剪边缘纯色/暗边区域
  imgLib.Image _autoCropBorders(imgLib.Image img) {
    final w = img.width;
    final h = img.height;
    if (w < 50 || h < 50) return img;

    // 获取边缘颜色（四角取平均）
    bool isDark(int r, int g, int b) => r < 40 && g < 40 && b < 40;
    bool isLight(int r, int g, int b) => r > 240 && g > 240 && b > 240;

    // 检查左上角几个像素，判断背景是深色还是浅色
    final topLeftPixels = <List<int>>[];
    for (int y = 0; y < 5; y++) {
      for (int x = 0; x < 5; x++) {
        final p = img.getPixel(x, y);
        topLeftPixels.add([p.r.toInt(), p.g.toInt(), p.b.toInt()]);
      }
    }
    final avgR = topLeftPixels.map((e) => e[0]).reduce((a, b) => a + b) / topLeftPixels.length;
    final avgG = topLeftPixels.map((e) => e[1]).reduce((a, b) => a + b) / topLeftPixels.length;
    final avgB = topLeftPixels.map((e) => e[2]).reduce((a, b) => a + b) / topLeftPixels.length;

    final bgDark = avgR < 50 && avgG < 50 && avgB < 50;
    final bgLight = avgR > 230 && avgG > 230 && avgB > 230;

    if (!bgDark && !bgLight) {
      // 背景不是纯色，不裁剪
      return img;
    }

    // 判断像素是否是背景色
    bool isBg(int r, int g, int b) {
      if (bgDark) return r < 60 && g < 60 && b < 60;
      return r > 220 && g > 220 && b > 220;
    }

    // 从左往右找第一个非背景列
    int left = 0;
    for (; left < w ~/ 2; left++) {
      bool hasContent = false;
      for (int y = 0; y < h; y += 3) {
        final p = img.getPixel(left, y);
        if (!isBg(p.r.toInt(), p.g.toInt(), p.b.toInt())) {
          hasContent = true;
          break;
        }
      }
      if (hasContent) break;
    }

    // 从右往左找
    int right = w - 1;
    for (; right > w ~/ 2; right--) {
      bool hasContent = false;
      for (int y = 0; y < h; y += 3) {
        final p = img.getPixel(right, y);
        if (!isBg(p.r.toInt(), p.g.toInt(), p.b.toInt())) {
          hasContent = true;
          break;
        }
      }
      if (hasContent) break;
    }

    // 从上往下找
    int top = 0;
    for (; top < h ~/ 2; top++) {
      bool hasContent = false;
      for (int x = 0; x < w; x += 3) {
        final p = img.getPixel(x, top);
        if (!isBg(p.r.toInt(), p.g.toInt(), p.b.toInt())) {
          hasContent = true;
          break;
        }
      }
      if (hasContent) break;
    }

    // 从下往上找
    int bottom = h - 1;
    for (; bottom > h ~/ 2; bottom--) {
      bool hasContent = false;
      for (int x = 0; x < w; x += 3) {
        final p = img.getPixel(x, bottom);
        if (!isBg(p.r.toInt(), p.g.toInt(), p.b.toInt())) {
          hasContent = true;
          break;
        }
      }
      if (hasContent) break;
    }

    // 确保裁剪区域不要太小（至少保留80%）
    final cropW = right - left + 1;
    final cropH = bottom - top + 1;
    if (cropW < w * 0.3 || cropH < h * 0.3) {
      return img; // 裁剪太多了，放弃
    }

    return imgLib.copyCrop(img, x: left, y: top, width: cropW, height: cropH);
  }
}

class _PreprocessedImage {
  final Uint8List fullBytes;
  final Uint8List roiBytes;

  _PreprocessedImage({
    required this.fullBytes,
    required this.roiBytes,
  });
}

/// 内部异常：表示 access_token 失效，需要刷新后重试
class _TokenInvalidException implements Exception {
  final String message;
  _TokenInvalidException(this.message);

  @override
  String toString() => '_TokenInvalidException: $message';
}
