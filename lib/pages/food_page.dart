import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../constants/app_constants.dart';
import '../config/api_config.dart';
import '../models/game_models.dart';
import '../providers/game_provider.dart';
import '../services/food_recognition_service_v2.dart';
import '../services/food_preference_service.dart';
import '../widgets/city_food_recommend_bar.dart';
import '../widgets/home/forge_background.dart';
import '../widgets/home/mini_monster_header.dart';

class FoodPage extends ConsumerStatefulWidget {
  /// 从舞台 push 进入时显示迷你怪血条
  final bool showMonsterHeader;

  const FoodPage({super.key, this.showMonsterHeader = false});

  @override
  ConsumerState<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends ConsumerState<FoodPage> {
  TextStyle get _displayStyle => GoogleFonts.fraunces(
        color: AppColors.text,
        fontWeight: FontWeight.w600,
      );

  TextStyle get _bodyStyle => GoogleFonts.figtree(color: AppColors.text);

  TextStyle get _mutedStyle =>
      GoogleFonts.figtree(color: AppColors.text2, fontSize: 13);

  late final Map<MealType, TextEditingController> _foodNameControllers;
  late final Map<MealType, TextEditingController> _foodCalControllers;
  final Map<MealType, List<RecognizedFood>> _searchResults = {};
  final Map<MealType, Timer?> _searchTimers = {};
  final Map<MealType, bool> _searching = {};
  late final FoodPreferenceService _foodPrefService;
  final FoodRecognitionServiceV2 _foodService = FoodRecognitionServiceV2();
  final Map<MealType, GlobalKey<CityFoodRecommendBarState>> _recommendBarKeys = {
    for (final meal in MealType.values) meal: GlobalKey<CityFoodRecommendBarState>(),
  };

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

  IconData _mealIcon(MealType meal) {
    return switch (meal) {
      MealType.breakfast => Icons.wb_sunny_outlined,
      MealType.lunch => Icons.lunch_dining_outlined,
      MealType.dinner => Icons.nights_stay_outlined,
      MealType.snack => Icons.cookie_outlined,
    };
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
      final result = await _foodService.searchByTextDetailed(query);
      if (mounted) {
        setState(() {
          _searchResults[meal] = result.items;
          _searching[meal] = false;
        });
        if (result.isEmpty) {
          _showSnack(
            result.emptyMessage.isNotEmpty
                ? '未找到「$query」\n${result.emptyMessage}'
                : '未找到「$query」',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searching[meal] = false);
        _showSnack('搜索失败: $e', isError: true);
      }
    }
  }

  void _notifyRecommendBarRefresh(MealType meal) {
    _recommendBarKeys[meal]?.currentState?.refreshRecent();
  }

  Future<void> _startBarcodeScan() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _showSnack('请授予摄像头权限', isError: true);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _BarcodeScannerPage(
          onDetected: (barcode) async {
            Navigator.of(ctx).pop();
            _showLoading('正在查询食物信息...');
            try {
              final result = await _foodService.lookupByBarcodeDetailed(barcode);
              if (!mounted) return;
              Navigator.of(context).pop();
              if (result.isEmpty) {
                _showSnack(
                  '未找到条形码 $barcode 对应的食物\n${result.emptyMessage}',
                  isError: true,
                  duration: const Duration(seconds: 5),
                );
                return;
              }
              _showFoodConfirmDialog(result.items, '扫码识别结果');
            } catch (e) {
              if (mounted) {
                Navigator.of(context).pop();
                _showSnack('条码查询失败: $e', isError: true);
              }
            }
          },
          onScanError: (message) {
            if (mounted) {
              _showSnack(message, isError: true);
            }
          },
        ),
      ),
    );
  }

  Future<void> _startImageRecognition() async {
    if (!_foodService.hasAnyVisionConfig) {
      final proceed = await _confirmProceedWithoutVision();
      if (!proceed || !mounted) return;
    }

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _showSnack('请授予摄像头权限', isError: true);
      return;
    }
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      _showSnack('未检测到可用摄像头', isError: true);
      return;
    }
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
      final tmpFile = File(
        '${Directory.systemTemp.path}/fatbattle_photo_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await tmpFile.writeAsBytes(compressed, flush: true);

      try {
        final recogResult = await _foodService.recognize(tmpFile);
        try {
          await tmpFile.delete();
        } catch (_) {}

        if (!mounted) return;
        Navigator.of(context).pop();

        if (recogResult.items.isEmpty) {
          _showRecognitionFailureDialog(
            title: '未识别到食物',
            message: _buildRecognitionFailureMessage(recogResult),
          );
          return;
        }

        if (recogResult.source == 'local') {
          _showSnack(
            '在线识别不可用，已展示本地推荐候选（${recogResult.sourceLabel}）',
            isError: false,
            duration: const Duration(seconds: 4),
          );
        } else {
          _showSnack('识别来源：${recogResult.sourceLabel}', duration: const Duration(seconds: 2));
        }

        _showFoodConfirmDialog(
          recogResult.items.take(8).toList(),
          '拍照识别结果 · ${recogResult.sourceLabel}',
        );
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
          _showRecognitionFailureDialog(
            title: '识别失败',
            message: '拍照识别出错：$e',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showSnack('识别失败: $e', isError: true);
      }
    }
  }

  Future<bool> _confirmProceedWithoutVision() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            title: Text('在线识别未配置', style: _displayStyle.copyWith(fontSize: 18)),
            content: Text(ApiConfig.foodVisionConfigHint, style: _bodyStyle),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('取消', style: _bodyStyle.copyWith(color: AppColors.text2)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('继续（本地推荐）'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _buildRecognitionFailureMessage(FoodRecognitionResult result) {
    final buffer = StringBuffer('所有识别源均未识别出食物。\n\n');
    if (result.attemptedSources.isNotEmpty) {
      buffer.writeln('已尝试：${result.attemptedSources.join(' → ')}');
    }
    if (result.failures.isNotEmpty) {
      buffer.writeln(result.failures.join('\n'));
    }
    buffer.writeln('\n请尝试：');
    buffer.writeln('1. 拍一盘做好的菜，确保食物占画面主体');
    buffer.writeln('2. 使用「搜索食物」输入名称');
    buffer.writeln('3. 包装食品可使用「扫码识别」');
    if (!ApiConfig.hasAnyFoodVisionConfig) {
      buffer.writeln('\n${ApiConfig.foodVisionConfigHint}');
    }
    return buffer.toString();
  }

  void _showRecognitionFailureDialog({
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(title, style: _displayStyle.copyWith(fontSize: 18)),
        content: SingleChildScrollView(
          child: Text(message, style: _bodyStyle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('关闭', style: _bodyStyle.copyWith(color: AppColors.text2)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showSearchDialog();
            },
            child: Text('去搜索', style: _bodyStyle.copyWith(color: AppColors.copper)),
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
                  final queryResult = await _foodService.searchByTextDetailed(query);
                  if (context.mounted) {
                    sb(() {
                      results = queryResult.items;
                      searching = false;
                    });
                    if (queryResult.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            queryResult.emptyMessage.isNotEmpty
                                ? '未找到相关食物\n${queryResult.emptyMessage}'
                                : '未找到相关食物',
                            style: _bodyStyle,
                          ),
                          backgroundColor: AppColors.bg3,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
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
                        content: Text('搜索失败: $e', style: _bodyStyle),
                        backgroundColor: AppColors.ember,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              });
            }

            return AlertDialog(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              title: Row(
                children: [
                  Icon(Icons.search, color: AppColors.copper, size: 20),
                  const SizedBox(width: 8),
                  Text('搜索食物', style: _displayStyle.copyWith(fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      style: _bodyStyle,
                      decoration: InputDecoration(
                        hintText: '输入食物名称',
                        hintStyle: _mutedStyle,
                        prefixIcon: Icon(Icons.search, color: AppColors.copper),
                        suffixIcon: searching
                            ? Padding(
                                padding: const EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.copper,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      onChanged: doSearch,
                    ),
                    const SizedBox(height: 12),
                    if (results.isEmpty && !searching && searchController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('未找到相关食物', style: _mutedStyle),
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
                              title: Text(
                                food.name,
                                style: _bodyStyle.copyWith(fontSize: 14),
                              ),
                              subtitle: Text(
                                '${food.calories} kcal · ${food.source}',
                                style: _mutedStyle.copyWith(fontSize: 11),
                              ),
                              trailing: Text(
                                '${food.calories}',
                                style: _bodyStyle.copyWith(
                                  color: AppColors.copper,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                  child: Text('关闭', style: _bodyStyle.copyWith(color: AppColors.text2)),
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
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            title: Row(
              children: [
                Icon(Icons.restaurant_outlined, color: AppColors.copper, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: _displayStyle.copyWith(fontSize: 17)),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 450),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '请确认并勾选要记录的食物：',
                      style: _mutedStyle,
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
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CheckboxListTile(
                              title: Text(
                                food.name,
                                style: _bodyStyle.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    '${food.calories} kcal/份',
                                    style: _mutedStyle.copyWith(fontSize: 12),
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
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                AppColors.copper.withValues(alpha: 0.85),
                                              ),
                                              minHeight: 6,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${(probability * 100).toStringAsFixed(1)}%',
                                          style: _bodyStyle.copyWith(
                                            fontSize: 11,
                                            color: AppColors.copper,
                                            fontWeight: FontWeight.bold,
                                          ),
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
                                    Text('份量:', style: _mutedStyle.copyWith(fontSize: 12)),
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
                                            color: isSel
                                                ? AppColors.copper.withValues(alpha: 0.15)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSel ? AppColors.copper : AppColors.border,
                                            ),
                                          ),
                                          child: Text(
                                            s.name,
                                            style: _bodyStyle.copyWith(
                                              fontSize: 12,
                                              color: isSel ? AppColors.copper : AppColors.text,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                    const Spacer(),
                                    Text(
                                      '$cal kcal',
                                      style: _bodyStyle.copyWith(
                                        color: AppColors.copper,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
                                style: _bodyStyle.copyWith(
                                  fontSize: 13,
                                  color: AppColors.copper,
                                ),
                              ),
                              Icon(
                                expanded ? Icons.expand_less : Icons.expand_more,
                                size: 18,
                                color: AppColors.copper,
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.copper.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.copper.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('总计:', style: _displayStyle.copyWith(fontSize: 15)),
                          Text(
                            '$totalCal 千卡',
                            style: _displayStyle.copyWith(
                              color: AppColors.copper,
                              fontSize: 16,
                            ),
                          ),
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
                child: Text('取消', style: _bodyStyle.copyWith(color: AppColors.text2)),
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
                          _foodPrefService.recordFoodAdded(entry.key);
                        }
                        _notifyRecommendBarRefresh(meal);
                        _showSnack('已记录${selected.length}种食物到${meal.name}');
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
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        content: Row(
          children: [
            CircularProgressIndicator(color: AppColors.copper, strokeWidth: 2.5),
            const SizedBox(width: 16),
            Expanded(child: Text(message, style: _bodyStyle)),
          ],
        ),
      ),
    );
  }

  void _showSnack(
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: _bodyStyle),
        backgroundColor: isError ? AppColors.ember : AppColors.bg3,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: duration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);

    return ForgeBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('饮食'),
        centerTitle: true,
        bottom: widget.showMonsterHeader
            ? const PreferredSize(
                preferredSize: Size.fromHeight(72),
                child: MiniMonsterHeader(),
              )
            : null,
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
      ),
    );
  }

  Widget _buildRecognitionArea() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.copper.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ember.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu_outlined, color: AppColors.copper, size: 20),
                const SizedBox(width: 8),
                Text('智能识别', style: _displayStyle.copyWith(fontSize: 17)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '扫码、拍照或搜索，快速记录今日饮食',
              style: _mutedStyle.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildRecogButton(
                    icon: Icons.qr_code_scanner_outlined,
                    label: '扫码识别',
                    sub: '包装食品',
                    accent: AppColors.copper,
                    onTap: _startBarcodeScan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildRecogButton(
                    icon: Icons.photo_camera_outlined,
                    label: '拍照识别',
                    sub: '菜肴/水果',
                    accent: AppColors.ember,
                    onTap: _startImageRecognition,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildRecogButton(
                    icon: Icons.search_outlined,
                    label: '搜索食物',
                    sub: '名称查询',
                    accent: AppColors.green,
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
    required IconData icon,
    required String label,
    required String sub,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: _bodyStyle.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: accent,
              ),
              textAlign: TextAlign.center,
            ),
            Text(sub, style: _mutedStyle.copyWith(fontSize: 11), textAlign: TextAlign.center),
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
                Row(
                  children: [
                    Icon(_mealIcon(meal), color: AppColors.copper, size: 18),
                    const SizedBox(width: 8),
                    Text(meal.name, style: _displayStyle.copyWith(fontSize: 15)),
                  ],
                ),
                Text(
                  '$mealCal 千卡',
                  style: _bodyStyle.copyWith(
                    color: AppColors.copper,
                    fontWeight: FontWeight.w600,
                  ),
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
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, color: AppColors.text2, size: 28),
                          const SizedBox(height: 6),
                          Text('还没有记录', style: _mutedStyle),
                        ],
                      ),
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
          if ((_searching[meal] ?? false) == false &&
              _foodNameControllers[meal]!.text.trim().isNotEmpty &&
              (_searchResults[meal]?.isEmpty ?? true))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '未找到「${_foodNameControllers[meal]!.text.trim()}」，可手动输入千卡后添加',
                style: _mutedStyle.copyWith(fontSize: 12),
              ),
            ),
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
        color: AppColors.copper.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.copper.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              children: [
                Icon(Icons.search, size: 14, color: AppColors.copper),
                const SizedBox(width: 4),
                Text(
                  '搜索结果（点击确认）',
                  style: _bodyStyle.copyWith(
                    fontSize: 12,
                    color: AppColors.copper,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(food.name, style: _bodyStyle.copyWith(fontSize: 13)),
                    ),
                    Text(
                      '${food.calories} kcal',
                      style: _bodyStyle.copyWith(color: AppColors.copper, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Text(food.source, style: _mutedStyle.copyWith(fontSize: 10)),
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: Text(food.name, style: _bodyStyle)),
          Text(food.size.name, style: _mutedStyle),
          const SizedBox(width: 8),
          Text(
            '${food.totalCal}千卡',
            style: _bodyStyle.copyWith(color: AppColors.copper, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => gameNotifier.removeFood(meal, index),
            icon: Icon(Icons.close, color: AppColors.ember, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            visualDensity: VisualDensity.compact,
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
                _foodPrefService.recordFoodAdded(name);
                _notifyRecommendBarRefresh(meal);
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
      key: _recommendBarKeys[meal],
      meal: meal,
      onSelect: (food) {
        gameNotifier.addFood(FoodItem(
          name: food.name,
          baseCal: food.cal,
          size: FoodSize.medium,
          totalCal: food.cal,
          meal: meal,
        ));
        _showSnack('已添加 ${food.name} 到${meal.name}');
      },
    );
  }
}

class _BarcodeScannerPage extends StatefulWidget {
  final Future<void> Function(String) onDetected;
  final void Function(String message)? onScanError;

  const _BarcodeScannerPage({
    required this.onDetected,
    this.onScanError,
  });

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  bool _detected = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('扫描条形码', style: GoogleFonts.fraunces(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          MobileScanner(
            errorBuilder: (context, error, child) {
              final msg = '摄像头不可用：${error.errorCode.name}';
              widget.onScanError?.call(msg);
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(msg, textAlign: TextAlign.center),
                ),
              );
            },
            onDetect: (capture) {
              if (_detected) return;
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;

              String? code;
              for (final barcode in barcodes) {
                final raw = barcode.rawValue?.trim();
                if (raw != null && raw.isNotEmpty) {
                  code = raw;
                  break;
                }
              }

              if (code == null) {
                setState(() {
                  _errorMessage = '无法读取条形码，请对准包装条码重试';
                });
                return;
              }

              _detected = true;
              widget.onDetected(code).catchError((Object e) {
                _detected = false;
                widget.onScanError?.call('扫码处理失败: $e');
              });
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
                  color: AppColors.bg3.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.copper.withValues(alpha: 0.35)),
                ),
                child: Text(
                  _errorMessage ?? '将条形码对准扫描框',
                  style: GoogleFonts.figtree(color: AppColors.text, fontSize: 14),
                  textAlign: TextAlign.center,
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
          SnackBar(
            content: Text('拍照失败: $e', style: GoogleFonts.figtree(color: AppColors.text)),
            backgroundColor: AppColors.ember,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('拍摄食物', style: GoogleFonts.fraunces(fontWeight: FontWeight.w600)),
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
                          color: AppColors.text,
                          border: Border.all(color: AppColors.copper, width: 4),
                        ),
                        child: Icon(Icons.camera_alt, color: AppColors.ember, size: 32),
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
