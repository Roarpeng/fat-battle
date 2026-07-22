import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../constants/app_constants.dart';
import '../models/game_models.dart';
import '../providers/game_provider.dart';
import '../services/food_recognition_service_v2.dart';
import '../services/baidu_food_service.dart';
import '../services/food_preference_service.dart';
import '../widgets/city_food_recommend_bar.dart';

class FoodPage extends ConsumerStatefulWidget {
  const FoodPage({super.key});

  @override
  ConsumerState<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends ConsumerState<FoodPage> {
  late final Map<MealType, TextEditingController> _foodNameControllers;
  late final Map<MealType, TextEditingController> _foodCalControllers;
  final Map<MealType, List<RecognizedFood>> _searchResults = {};
  final Map<MealType, Timer?> _searchTimers = {};
  final Map<MealType, bool> _searching = {};
  late final FoodPreferenceService _foodPrefService;

  @override
  void initState() {
    super.initState();
    _foodNameControllers = {
      for (var meal in MealType.values) meal: TextEditingController()
    };
    _foodCalControllers = {
      for (var meal in MealType.values) meal: TextEditingController()
    };
    for (var meal in MealType.values) {
      _searchResults[meal] = [];
      _searching[meal] = false;
    }
    _foodPrefService = FoodPreferenceService();
  }

  @override
  void dispose() {
    for (var controller in _foodNameControllers.values) {
      controller.dispose();
    }
    for (var controller in _foodCalControllers.values) {
      controller.dispose();
    }
    for (var timer in _searchTimers.values) {
      timer?.cancel();
    }
    super.dispose();
  }

  MealType _getCurrentMeal() {
    final hour = DateTime.now().hour;
    if (hour < 10) return MealType.breakfast;
    if (hour < 14) return MealType.lunch;
    if (hour < 20) return MealType.dinner;
    return MealType.snack;
  }

  void _onSearchChanged(String query, MealType meal) {
    _searchTimers[meal]?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults[meal] = [];
        _searching[meal] = false;
      });
      return;
    }
    _searchTimers[meal] = Timer(const Duration(milliseconds: 500), () {
      _doSearch(query, meal);
    });
  }

  Future<void> _doSearch(String query, MealType meal) async {
    setState(() => _searching[meal] = true);
    try {
      final results = await FoodRecognitionServiceV2().searchByText(query);
      if (mounted) {
        setState(() {
          _searchResults[meal] = results;
          _searching[meal] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searching[meal] = false);
      }
    }
  }

  Future<void> _startBarcodeScan() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _showToast('请授予摄像头权限');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _BarcodeScannerPage(
          onDetected: (barcode) async {
            Navigator.of(ctx).pop();
            _showLoading('正在查询食物信息...');
            final results = await FoodRecognitionServiceV2().lookupByBarcode(barcode);
            if (mounted) {
              Navigator.of(context).pop();
              if (results.isEmpty) {
                _showToast('未找到该条形码对应的食物');
                return;
              }
              _showFoodConfirmDialog(results, '扫码识别结果');
            }
          },
        ),
      ),
    );
  }

  Future<void> _startImageRecognition() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _showToast('请授予摄像头权限');
      return;
    }
    final cameras = await availableCameras();
    if (!mounted) return;
    final result = await Navigator.of(context).push<XFile>(
      MaterialPageRoute(
        builder: (ctx) => _TakePicturePage(cameras: cameras),
      ),
    );
    if (result == null) return;
    _showLoading('正在识别食物...');
    try {
      final bytes = await result.readAsBytes();
      final compressed = await _compressImage(bytes);

      // 调试信息
      final debugInfo = StringBuffer();
      debugInfo.writeln('=== 调试信息 ===');
      debugInfo.writeln('原始图片: ${bytes.length} 字节');
      debugInfo.writeln('压缩后: ${compressed.length} 字节');
      final isJpg = compressed.length >= 2 &&
          compressed[0] == 0xFF && compressed[1] == 0xD8;
      debugInfo.writeln('JPG格式: $isJpg');
      debugInfo.writeln('百度已配置: ${BaiduFoodService().isConfigured()}');

      // 保存图片到Download目录便于调试
      try {
        final savePath = '/sdcard/Download/fatbattle_test.jpg';
        final savedFile = File(savePath);
        await savedFile.writeAsBytes(compressed, flush: true);
        debugInfo.writeln('图片已保存: $savePath');
      } catch (e) {
        debugInfo.writeln('保存失败: $e');
      }

      // 使用 V2 服务（GLM-4.6V-Flash 优先，百度兜底）
      try {
        final tmpFile = File('${Directory.systemTemp.path}/fatbattle_photo_${DateTime.now().microsecondsSinceEpoch}.jpg');
        await tmpFile.writeAsBytes(compressed, flush: true);

        final recogResult = await FoodRecognitionServiceV2().recognize(tmpFile);
        debugInfo.writeln('\n=== 识别结果 ===');
        debugInfo.writeln('识别源: ${recogResult.source}');
        debugInfo.writeln('结果数量: ${recogResult.items.length}');
        for (var i = 0; i < recogResult.items.length; i++) {
          final item = recogResult.items[i];
          debugInfo.writeln('${i + 1}. ${item.name} '
              '(卡路里:${item.calories} kcal/100g, 来源:${item.source})');
        }

        try {
          await tmpFile.delete();
        } catch (_) {}

        if (mounted) {
          Navigator.of(context).pop();
          if (recogResult.items.isEmpty) {
            _showDebugDialog(
              '未识别到食物',
              '所有识别服务均未识别出食物。\n\n'
              '请尝试：\n'
              '1. 拍一盘做好的菜（如炒菜、米饭）\n'
              '2. 拍水果（如苹果、香蕉）\n'
              '3. 确保食物占画面主体，对焦清晰\n'
              '4. 或点「搜索」按钮，输入食物名称\n\n'
              '$debugInfo'
            );
            return;
          }
          final displayItems = recogResult.items.take(8).toList();
          _showFoodConfirmDialog(
            displayItems,
            '拍照识别结果',
          );
        }
      } catch (e) {
        debugInfo.writeln('\n=== 识别错误 ===');
        debugInfo.writeln('错误: $e');
        if (mounted) {
          Navigator.of(context).pop();
          _showDebugDialog('识别失败', debugInfo.toString());
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showToast('识别失败: $e');
      }
    }
  }

  void _showDebugDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              Navigator.of(ctx).pop();
            },
            child: const Text('复制'),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    const maxSize = 3 * 1024 * 1024;
    final isJpg = bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;

    if (isJpg && bytes.length <= maxSize) return bytes;

    try {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 70,
        minHeight: 1024,
        minWidth: 1024,
        format: CompressFormat.jpeg,
      );
      return compressed.length > maxSize
          ? await FlutterImageCompress.compressWithList(
              bytes,
              quality: 50,
              minHeight: 720,
              minWidth: 720,
              format: CompressFormat.jpeg,
            )
          : compressed;
    } catch (_) {
      return bytes;
    }
  }

  void _showSearchDialog() {
    final meal = _getCurrentMeal();
    final searchController = TextEditingController();
    List<RecognizedFood> results = [];
    bool searching = false;
    Timer? debounce;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, sb) {
            void doSearch(String query) {
              debounce?.cancel();
              if (query.trim().isEmpty) {
                sb(() {
                  results = [];
                  searching = false;
                });
                return;
              }
              debounce = Timer(const Duration(milliseconds: 400), () async {
                sb(() => searching = true);
                try {
                  final list = await FoodRecognitionServiceV2().searchByText(query);
                  if (context.mounted) {
                    sb(() {
                      results = list;
                      searching = false;
                    });
                  }
                } catch (e) {
                  debugPrint('搜索失败: $e');
                  if (context.mounted) {
                    sb(() {
                      results = [];
                      searching = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('搜索失败: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              });
            }

            return AlertDialog(
              title: const Text('🔍 搜索食物'),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '输入食物名称',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                      onChanged: doSearch,
                    ),
                    const SizedBox(height: 12),
                    if (results.isEmpty && !searching && searchController.text.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('未找到相关食物', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final food = results[i];
                            return ListTile(
                              dense: true,
                              title: Text(food.name, style: const TextStyle(fontSize: 14)),
                              subtitle: Text(
                                '${food.calories} kcal · ${food.source}',
                                style: TextStyle(fontSize: 11, color: AppColors.text2),
                              ),
                              trailing: Text('${food.calories}', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _showFoodConfirmDialog([food], '搜索结果');
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      debounce?.cancel();
      searchController.dispose();
    });
  }

  void _showFoodConfirmDialog(
    List<RecognizedFood> foods,
    String title, {
    List<dynamic>? topDishes,
  }) {
    final selected = <String, RecognizedFood>{};
    final portions = <String, FoodSize>{};
    for (final f in foods) {
      portions[f.name] = FoodSize.medium;
    }
    if (foods.isNotEmpty) {
      selected[foods.first.name] = foods.first;
    }
    final meal = _getCurrentMeal();
    bool expanded = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, sb) {
          int totalCal = 0;
          for (final entry in selected.entries) {
            final size = portions[entry.key] ?? FoodSize.medium;
            totalCal += (entry.value.calories * size.multiplier).round();
          }

          final showCount = expanded ? foods.length : (foods.length > 1 ? 1 : foods.length);
          final hasMore = foods.length > 1;

          return AlertDialog(
            title: Text('🍽️ $title'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 450),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '请确认并勾选要记录的食物：',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    ...foods.asMap().entries.take(showCount).map((entry) {
                      final idx = entry.key;
                      final food = entry.value;
                      final checked = selected.containsKey(food.name);
                      final size = portions[food.name] ?? FoodSize.medium;
                      final cal = (food.calories * size.multiplier).round();
                      double? probability;
                      if (topDishes != null && idx < topDishes.length) {
                        probability = topDishes[idx].probability as double;
                      }
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.bg2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CheckboxListTile(
                              title: Text(food.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    '${food.calories} kcal/份',
                                    style: TextStyle(fontSize: 12, color: AppColors.text2),
                                  ),
                                  if (probability != null) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(3),
                                            child: LinearProgressIndicator(
                                              value: probability.clamp(0.0, 1.0),
                                              backgroundColor: AppColors.border,
                                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
                                              minHeight: 6,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${(probability * 100).toStringAsFixed(1)}%',
                                          style: TextStyle(fontSize: 11, color: AppColors.green, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              value: checked,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (v) {
                                if (v == true) {
                                  selected[food.name] = food;
                                } else {
                                  selected.remove(food.name);
                                }
                                sb(() {});
                              },
                            ),
                            if (checked)
                              Padding(
                                padding: const EdgeInsets.only(left: 48),
                                child: Row(
                                  children: [
                                    Text('份量:', style: TextStyle(fontSize: 12, color: AppColors.text2)),
                                    const SizedBox(width: 8),
                                    ...FoodSize.values.map((s) {
                                      final isSel = size == s;
                                      return GestureDetector(
                                        onTap: () {
                                          portions[food.name] = s;
                                          sb(() {});
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isSel ? AppColors.green.withOpacity(0.15) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSel ? AppColors.green : AppColors.border,
                                            ),
                                          ),
                                          child: Text(
                                            s.name,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isSel ? AppColors.green : AppColors.text,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                    const Spacer(),
                                    Text('$cal kcal', style: TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    if (hasMore)
                      Center(
                        child: TextButton(
                          onPressed: () {
                            expanded = !expanded;
                            sb(() {});
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                expanded ? '收起' : '展开更多 (${foods.length - 1}个)',
                                style: const TextStyle(fontSize: 13),
                              ),
                              Icon(
                                expanded ? Icons.expand_less : Icons.expand_more,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('总计:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('$totalCal 千卡', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: selected.isEmpty
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        final gameNotifier = ref.read(gameStateProvider.notifier);
                        for (final entry in selected.entries) {
                          final size = portions[entry.key] ?? FoodSize.medium;
                          gameNotifier.addFood(entry.value.toFoodItem(meal, size: size));
                          // 同步到快捷选择栏的近期食物
                          _foodPrefService.recordFoodAdded(entry.key);
                        }
                        _showToast('已记录${selected.length}种食物到${meal.name}');
                      },
                child: const Text('确认记录'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLoading(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🍽️ 饮食记录'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRecognitionArea(),
            const SizedBox(height: 16),
            ...MealType.values.map((meal) =>
              _buildMealSection(meal, gameState, gameNotifier),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecognitionArea() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📷 智能识别',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildRecogButton(
                    icon: '🔍',
                    label: '扫码识别',
                    sub: '包装食品',
                    color: AppColors.purple,
                    onTap: _startBarcodeScan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildRecogButton(
                    icon: '📷',
                    label: '拍照识别',
                    sub: '菜肴/水果',
                    color: AppColors.red,
                    onTap: _startImageRecognition,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildRecogButton(
                    icon: '🔤',
                    label: '搜索食物',
                    sub: '名称查询',
                    color: AppColors.green,
                    onTap: _showSearchDialog,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecogButton({
    required String icon,
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
            Text(sub, style: TextStyle(fontSize: 11, color: AppColors.text2)),
          ],
        ),
      ),
    );
  }

  Widget _buildMealSection(MealType meal, GameState gameState, GameStateNotifier gameNotifier) {
    final foods = gameState.meals[meal] ?? [];
    final mealCal = foods.fold(0, (sum, f) => sum + f.totalCal);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${meal.emoji} ${meal.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  '$mealCal 千卡',
                  style: TextStyle(color: AppColors.gold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: foods.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text('📭 还没有记录', style: TextStyle(color: AppColors.text2)),
                    ),
                  )
                : Column(
                    children: foods.asMap().entries.map((entry) {
                      final index = entry.key;
                      final food = entry.value;
                      return _buildFoodItem(food, meal, index, gameNotifier);
                    }).toList(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildFoodInput(meal, gameNotifier),
          ),
          if (_searchResults[meal] != null && _searchResults[meal]!.isNotEmpty)
            _buildSearchResults(meal, gameNotifier),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildQuickTags(meal, gameNotifier),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(MealType meal, GameStateNotifier gameNotifier) {
    final results = _searchResults[meal]!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.green.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              '🔍 搜索结果（点击确认）',
              style: TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.bold),
            ),
          ),
          ...results.take(5).map((food) {
            return GestureDetector(
              onTap: () {
                _foodNameControllers[meal]!.clear();
                setState(() {
                  _searchResults[meal] = [];
                });
                _showFoodConfirmDialog([food], '搜索结果');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Text(food.name, style: const TextStyle(fontSize: 13)),
                    const Spacer(),
                    Text('${food.calories} kcal', style: TextStyle(color: AppColors.gold, fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(food.source, style: TextStyle(fontSize: 10, color: AppColors.text2)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFoodItem(FoodItem food, MealType meal, int index, GameStateNotifier gameNotifier) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: Text(food.name)),
          Text(food.size.name, style: TextStyle(color: AppColors.text2)),
          const SizedBox(width: 8),
          Text('${food.totalCal}千卡', style: TextStyle(color: AppColors.gold)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => gameNotifier.removeFood(meal, index),
            child: const Text('✕', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodInput(MealType meal, GameStateNotifier gameNotifier) {
    final nameController = _foodNameControllers[meal]!;
    final calController = _foodCalControllers[meal]!;
    final isSearching = _searching[meal] ?? false;
    String selectedSize = 'medium';

    return StatefulBuilder(
      builder: (context, sb) {
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: '食物名称（可搜索）',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  suffixIcon: isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                ),
                onChanged: (v) => _onSearchChanged(v, meal),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: calController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '千卡',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: selectedSize,
              items: ['small', 'medium', 'large'].map((s) =>
                DropdownMenuItem(
                  value: s,
                  child: Text(FoodSize.values.firstWhere((f) => f.index == ['small', 'medium', 'large'].indexOf(s)).name),
                ),
              ).toList(),
              onChanged: (v) => sb(() => selectedSize = v ?? 'medium'),
              underline: Container(),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final cal = int.tryParse(calController.text);
                if (name.isEmpty || cal == null) return;
                final size = FoodSize.values.firstWhere(
                  (s) => s.index == ['small', 'medium', 'large'].indexOf(selectedSize),
                );
                final food = FoodItem(
                  name: name,
                  baseCal: cal,
                  size: size,
                  totalCal: (cal * size.multiplier).toInt(),
                  meal: meal,
                );
                gameNotifier.addFood(food);
                // 同步到快捷选择栏
                _foodPrefService.recordFoodAdded(name);
                nameController.clear();
                calController.clear();
                setState(() => _searchResults[meal] = []);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickTags(MealType meal, GameStateNotifier gameNotifier) {
    return CityFoodRecommendBar(
      meal: meal,
      onSelect: (food) {
        gameNotifier.addFood(FoodItem(
          name: food.name,
          baseCal: food.cal,
          size: FoodSize.medium,
          totalCal: food.cal,
          meal: meal,
        ));
      },
    );
  }
}

class _BarcodeScannerPage extends StatefulWidget {
  final Function(String) onDetected;
  const _BarcodeScannerPage({required this.onDetected});

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  bool _detected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📷 扫描条形码'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_detected) return;
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final code = barcode.rawValue;
                if (code != null && code.isNotEmpty) {
                  _detected = true;
                  widget.onDetected(code);
                  break;
                }
              }
            },
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '将条形码对准扫描框',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TakePicturePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const _TakePicturePage({required this.cameras});

  @override
  State<_TakePicturePage> createState() => _TakePicturePageState();
}

class _TakePicturePageState extends State<_TakePicturePage> {
  CameraController? _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) return;
    final cam = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );
    _controller = CameraController(cam, ResolutionPreset.high, enableAudio: false);
    await _controller!.initialize();
    if (mounted) {
      setState(() => _isReady = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final image = await _controller!.takePicture();
      if (mounted) {
        Navigator.of(context).pop(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📷 拍摄食物'),
        centerTitle: true,
      ),
      body: _isReady && _controller != null
          ? Stack(
              children: [
                CameraPreview(_controller!),
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _takePicture,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: AppColors.green, width: 4),
                        ),
                        child: const Icon(Icons.camera_alt, color: AppColors.green, size: 32),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
