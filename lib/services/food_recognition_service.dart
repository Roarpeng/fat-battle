import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/game_models.dart';

class RecognizedFood {
  final String name;
  final int calories;
  final String source;
  final String? code;
  final String? thumbUrl;
  final double? protein;
  final double? fat;
  final double? carb;
  final double? amountGram;

  const RecognizedFood({
    required this.name,
    required this.calories,
    required this.source,
    this.code,
    this.thumbUrl,
    this.protein,
    this.fat,
    this.carb,
    this.amountGram,
  });

  FoodItem toFoodItem(MealType meal, {FoodSize size = FoodSize.medium}) {
    return FoodItem(
      name: name,
      baseCal: calories,
      size: size,
      totalCal: (calories * size.multiplier).toInt(),
      meal: meal,
      photoUrl: thumbUrl,
    );
  }
}

class FoodRecognitionService {
  static final FoodRecognitionService _instance = FoodRecognitionService._internal();
  factory FoodRecognitionService() => _instance;
  FoodRecognitionService._internal();

  // 薄荷健康 API 配置
  static const String _booheeBaseUrl = 'https://api.boohee.com';
  static const String _booheeAppId = 'nwkbeuvbdb';
  static const String _booheeAppKey = '4rwwjrns5jyhbyptcdswsb5fyhavqa9b';
  String? _booheeAccessToken;
  DateTime? _booheeTokenExpire;

  // FatSecret API 配置
  static const String _fatsecretBaseUrl = 'https://platform.fatsecret.com/rest/server.api';
  static const String _fatsecretTokenUrl = 'https://oauth.fatsecret.com/connect/token';
  static const String _fatsecretClientId = '7f138fe9fc194ed9a41e71ac2390abac';
  static const String _fatsecretClientSecret = '6424bd4ca42444e7b495557c569b6deb';
  String? _fatsecretToken;
  DateTime? _fatsecretTokenExpire;

  // Open Food Facts
  static const String _offBaseUrl = 'https://world.openfoodfacts.org/api/v2';

  String _generateSign(Map<String, dynamic> params) {
    final sortedKeys = params.keys.toList()..sort();
    final buffer = StringBuffer();
    for (final key in sortedKeys) {
      buffer.write('$key${params[key]}');
    }
    final toSign = '$_booheeAppKey${buffer.toString()}$_booheeAppKey';
    final bytes = utf8.encode(toSign);
    return md5.convert(bytes).toString();
  }

  Future<String> _getBooheeToken() async {
    if (_booheeAccessToken != null &&
        _booheeTokenExpire != null &&
        DateTime.now().isBefore(_booheeTokenExpire!.subtract(const Duration(minutes: 5)))) {
      return _booheeAccessToken!;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final params = {
      'app_id': _booheeAppId,
      'timestamp': timestamp.toString(),
    };
    final sign = _generateSign(params);
    params['sign'] = sign;

    try {
      final response = await http.post(
        Uri.parse('$_booheeBaseUrl/api/v2/access_tokens'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: params,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _booheeAccessToken = data['access_token'];
        if (data['expired_at'] != null) {
          _booheeTokenExpire = DateTime.tryParse(data['expired_at']) ??
              DateTime.now().add(const Duration(days: 25));
        } else {
          _booheeTokenExpire = DateTime.now().add(const Duration(days: 25));
        }
        return _booheeAccessToken!;
      }
      throw Exception('薄荷健康 token 获取失败: ${response.statusCode} ${response.body}');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _booheeGet(String path, Map<String, dynamic> params) async {
    try {
      final token = await _getBooheeToken();
      final uri = Uri.parse('$_booheeBaseUrl$path').replace(queryParameters: params);
      final response = await http.get(
        uri,
        headers: {'AccessToken': token},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _booheePost(String path, Map<String, dynamic> body) async {
    try {
      final token = await _getBooheeToken();
      final response = await http.post(
        Uri.parse('$_booheeBaseUrl$path'),
        headers: {
          'AccessToken': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String> _getFatSecretToken() async {
    if (_fatsecretToken != null &&
        _fatsecretTokenExpire != null &&
        DateTime.now().isBefore(_fatsecretTokenExpire!.subtract(const Duration(minutes: 1)))) {
      return _fatsecretToken!;
    }
    try {
      final credentials = base64.encode(
        utf8.encode('$_fatsecretClientId:$_fatsecretClientSecret'),
      );
      final response = await http.post(
        Uri.parse(_fatsecretTokenUrl),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=client_credentials&scope=basic',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _fatsecretToken = data['access_token'];
        final expiresIn = data['expires_in'] ?? 86400;
        _fatsecretTokenExpire = DateTime.now().add(Duration(seconds: expiresIn));
        return _fatsecretToken!;
      }
      throw Exception('FatSecret token 获取失败');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<RecognizedFood>> searchByText(String query) async {
    if (query.trim().isEmpty) return [];

    // 1. 薄荷健康搜索
    try {
      final result = await _booheeGet('/api/v1/foods/search', {'q': query, 'page': '1'});
      if (result != null && result['foods'] != null && result['foods'].isNotEmpty) {
        final List<RecognizedFood> foods = [];
        for (final f in result['foods'].take(10)) {
          final cal = int.tryParse(f['calory']?.toString() ?? '0') ?? 0;
          foods.add(RecognizedFood(
            name: f['name'] ?? '',
            calories: cal,
            source: '薄荷健康',
            code: f['code'],
            thumbUrl: f['thumb_image_url'],
          ));
        }
        if (foods.isNotEmpty) return foods;
      }
    } catch (_) {}

    // 2. FatSecret 搜索
    try {
      final token = await _getFatSecretToken();
      final uri = Uri.parse(_fatsecretBaseUrl).replace(queryParameters: {
        'method': 'foods.search',
        'search_expression': query,
        'format': 'json',
        'max_results': '10',
      });
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final foodsResult = data['foods']?['food'];
        if (foodsResult != null && foodsResult is List) {
          final List<RecognizedFood> foods = [];
          for (final f in foodsResult.take(10)) {
            final desc = f['food_description'] ?? '';
            final calMatch = RegExp(r'(\d+)\s*kcal').firstMatch(desc);
            final cal = calMatch != null ? int.tryParse(calMatch.group(1) ?? '0') ?? 0 : 0;
            foods.add(RecognizedFood(
              name: f['food_name'] ?? '',
              calories: cal,
              source: 'FatSecret',
            ));
          }
          if (foods.isNotEmpty) return foods;
        }
      }
    } catch (_) {}

    // 3. 本地兜底
    return _searchLocal(query);
  }

  Future<List<RecognizedFood>> lookupByBarcode(String barcode) async {
    // 1. 薄荷健康条码查询
    try {
      final result = await _booheeGet('/api/v1/foods/barcode', {'barcode': barcode});
      if (result != null && result['success'] == 1 && result['foods'] != null && result['foods'].isNotEmpty) {
        final List<RecognizedFood> foods = [];
        for (final f in result['foods']) {
          foods.add(RecognizedFood(
            name: f['name'] ?? '',
            calories: (f['calory'] ?? 0).toInt(),
            source: '薄荷健康',
            code: f['code'],
            thumbUrl: f['thumb_image_url'],
          ));
        }
        if (foods.isNotEmpty) return foods;
      }
    } catch (_) {}

    // 2. FatSecret 条码查询
    try {
      final token = await _getFatSecretToken();
      final uri = Uri.parse(_fatsecretBaseUrl).replace(queryParameters: {
        'method': 'food.find_id_for_barcode',
        'barcode': barcode,
        'format': 'json',
      });
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final foodId = data['food_id']?.toString();
        if (foodId != null && foodId.isNotEmpty && foodId != '0') {
          final detailUri = Uri.parse(_fatsecretBaseUrl).replace(queryParameters: {
            'method': 'food.get',
            'food_id': foodId,
            'format': 'json',
          });
          final detailResp = await http.get(
            detailUri,
            headers: {'Authorization': 'Bearer $token'},
          );
          if (detailResp.statusCode == 200) {
            final detail = jsonDecode(detailResp.body);
            final food = detail['food'];
            if (food != null) {
              final servings = food['servings']?['serving'];
              int cal = 0;
              if (servings is List && servings.isNotEmpty) {
                cal = int.tryParse(servings.first['calories']?.toString() ?? '0') ?? 0;
              } else if (servings is Map) {
                cal = int.tryParse(servings['calories']?.toString() ?? '0') ?? 0;
              }
              return [
                RecognizedFood(
                  name: food['food_name'] ?? '',
                  calories: cal,
                  source: 'FatSecret',
                )
              ];
            }
          }
        }
      }
    } catch (_) {}

    // 3. Open Food Facts
    try {
      final response = await http.get(
        Uri.parse('$_offBaseUrl/product/$barcode.json'),
        headers: {'User-Agent': 'FatBattle/1.0'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final product = data['product'];
        if (product != null) {
          final name = product['product_name_zh'] ??
              product['product_name'] ??
              '未知食品';
          var kcal = product['nutriments']?['energy-kcal_100g'] ?? 0;
          if (kcal == 0) {
            final kj = product['nutriments']?['energy_100g'] ?? 0;
            kcal = (kj / 4.184).round();
          }
          return [
            RecognizedFood(
              name: name,
              calories: kcal.toInt(),
              source: 'OpenFoodFacts',
            )
          ];
        }
      }
    } catch (_) {}

    return [];
  }

  Future<List<RecognizedFood>> recognizeByImage(List<int> imageBytes) async {
    // 1. 薄荷健康图片识别（需要先上传到公网，这里先用占位方案）
    // 由于图片识别需要公网图片URL，我们暂时返回本地模拟+搜索
    try {
      // 如果有图床服务，可以在这里上传
      // 目前暂时使用本地随机识别
    } catch (_) {}

    // 2. 本地兜底（模拟识别）
    final allFoods = [
      ...QuickFoods.breakfast,
      ...QuickFoods.lunch,
      ...QuickFoods.dinner,
      ...QuickFoods.snack,
    ];
    allFoods.shuffle();
    final count = 2 + (allFoods.length % 3);
    return allFoods.take(count).map((f) => RecognizedFood(
      name: f.name,
      calories: f.cal,
      source: '本地模拟',
    )).toList();
  }

  List<RecognizedFood> _searchLocal(String query) {
    final allFoods = [
      ...QuickFoods.breakfast,
      ...QuickFoods.lunch,
      ...QuickFoods.dinner,
      ...QuickFoods.snack,
    ];
    final lower = query.toLowerCase();
    return allFoods
        .where((f) =>
            f.name.toLowerCase().contains(lower) ||
            lower.contains(f.name.toLowerCase()))
        .take(10)
        .map((f) => RecognizedFood(name: f.name, calories: f.cal, source: '本地'))
        .toList();
  }
}

final foodRecognitionProvider = Provider<FoodRecognitionService>((ref) {
  return FoodRecognitionService();
});
