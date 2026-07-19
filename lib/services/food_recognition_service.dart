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
  final String? description;
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
    this.description,
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

  static const Map<String, Map<String, dynamic>> _localBarcodeDb = {
    '6901028180009': {'name': '可口可乐 经典原味', 'calories': 43, 'category': '饮品'},
    '6901236349125': {'name': '康师傅红烧牛肉面', 'calories': 473, 'category': '快餐'},
    '6920202888883': {'name': '农夫山泉 天然饮用水', 'calories': 0, 'category': '饮品'},
    '6901028089885': {'name': '百事可乐', 'calories': 41, 'category': '饮品'},
    '6901668002525': {'name': '雪碧 柠檬味汽水', 'calories': 49, 'category': '饮品'},
    '6902083881038': {'name': '统一老坛酸菜牛肉面', 'calories': 450, 'category': '快餐'},
    '6901028223187': {'name': '红牛维生素功能饮料', 'calories': 56, 'category': '饮品'},
    '6907992510012': {'name': '怡宝纯净水', 'calories': 0, 'category': '饮品'},
    '6901236347126': {'name': '康师傅冰红茶', 'calories': 37, 'category': '饮品'},
    '6920459950080': {'name': '旺仔牛奶', 'calories': 58, 'category': '蛋奶'},
    '6902083887238': {'name': '统一阿萨姆奶茶', 'calories': 54, 'category': '饮品'},
    '6903148030024': {'name': '香飘飘奶茶', 'calories': 380, 'category': '饮品'},
    '6901028182943': {'name': '可口可乐 零度', 'calories': 0, 'category': '饮品'},
    '6901668002549': {'name': '芬达 橙味汽水', 'calories': 48, 'category': '饮品'},
    '6901028075000': {'name': '美年达 橙味', 'calories': 50, 'category': '饮品'},
    '6902083880024': {'name': '统一鲜橙多', 'calories': 45, 'category': '饮品'},
    '6901236341711': {'name': '康师傅茉莉蜜茶', 'calories': 30, 'category': '饮品'},
    '6920152485652': {'name': '蒙牛纯牛奶', 'calories': 54, 'category': '蛋奶'},
    '6907878016626': {'name': '伊利纯牛奶', 'calories': 54, 'category': '蛋奶'},
    '6902083886972': {'name': '统一冰红茶', 'calories': 37, 'category': '饮品'},
    '3017620422003': {'name': 'Nutella 能多益榛果可可酱', 'calories': 539, 'category': '零食'},
    '5449000000996': {'name': '可口可乐 经典原味', 'calories': 42, 'category': '饮品'},
    '0011110035156': {'name': 'Coca-Cola 可口可乐', 'calories': 42, 'category': '饮品'},
    '0722252130529': {'name': 'Lays 乐事薯片', 'calories': 536, 'category': '零食'},
  };

  Future<List<RecognizedFood>> lookupByBarcode(String barcode) async {
    final cleanBarcode = barcode.trim();

    // 1. Open Food Facts 条码查询（国际商品覆盖好，API可用）
    try {
      final response = await http.get(
        Uri.parse('$_offBaseUrl/product/$cleanBarcode.json'),
        headers: {'User-Agent': 'FatBattle/1.0 (https://github.com/fat-battle; contact@fatbattle.app)'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1) {
          final product = data['product'];
          if (product != null) {
            final name = product['product_name_zh'] ??
                product['product_name'] ??
                product['brands'] ??
                '未知食品';
            var kcal = 0;
            final kcalRaw = product['nutriments']?['energy-kcal_100g'];
            if (kcalRaw != null) {
              kcal = (kcalRaw is num) ? kcalRaw.toInt() : int.tryParse(kcalRaw.toString()) ?? 0;
            }
            if (kcal == 0) {
              final kj = product['nutriments']?['energy_100g'];
              if (kj != null) {
                final kjVal = (kj is num) ? kj.toDouble() : double.tryParse(kj.toString()) ?? 0;
                kcal = (kjVal / 4.184).round();
              }
            }
            if (name.toString().isNotEmpty && name != '未知食品') {
              return [
                RecognizedFood(
                  name: name.toString(),
                  calories: kcal,
                  source: 'OpenFoodFacts',
                  code: cleanBarcode,
                  description: product['generic_name_zh']?.toString() ?? product['generic_name']?.toString(),
                )
              ];
            }
          }
        }
      }
    } catch (_) {}

    // 2. 薄荷健康条码查询
    try {
      final result = await _booheeGet('/api/v1/foods/barcode', {'barcode': cleanBarcode});
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

    // 3. FatSecret 条码查询
    try {
      final token = await _getFatSecretToken();
      final uri = Uri.parse(_fatsecretBaseUrl).replace(queryParameters: {
        'method': 'food.find_id_for_barcode',
        'barcode': cleanBarcode,
        'format': 'json',
      });
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
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
          ).timeout(const Duration(seconds: 10));
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
                  code: cleanBarcode,
                )
              ];
            }
          }
        }
      }
    } catch (_) {}

    // 4. 本地常见条码库兜底
    final localMatch = _localBarcodeDb[cleanBarcode];
    if (localMatch != null) {
      return [
        RecognizedFood(
          name: localMatch['name'] as String,
          calories: localMatch['calories'] as int,
          source: '本地条码库',
          code: cleanBarcode,
          description: '常见商品参考值',
        )
      ];
    }

    // 5. 文本搜索兜底（用条码号尝试搜索）
    try {
      final textResults = await searchByText(cleanBarcode);
      if (textResults.isNotEmpty) {
        return textResults.map((f) => RecognizedFood(
          name: f.name,
          calories: f.calories,
          source: '${f.source}(条码搜索)',
          code: cleanBarcode,
        )).toList();
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
