import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/forge_theme.dart';
import '../theme/tokens.dart';
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
import '../widgets/forge_pressable.dart';
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
  TextStyle get _displayStyle => AppFonts.display(
        color: AppColors.text,
        fontWeight: FontWeight.w600,
      );

  TextStyle get _bodyStyle => AppFonts.body(color: AppColors.text);

  TextStyle get _mutedStyle =>
      AppFonts.body(color: AppColors.text2, fontSize: 13);

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
            '未找到「$query」，请换个名称试试',
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
            '在线识别不可用，已展示本地推荐候选',
            isError: false,
            duration: const Duration(seconds: 4),
          );
        }

        _showFoodConfirmDialog(
          recogResult.items.take(8).toList(),
          '拍照识别结果',
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
              borderRadius: AppRadii.mdAll,
              side: const BorderSide(color: AppColors.border),
            ),
            title: Text('未连接食物识别服务器', style: _displayStyle.copyWith(fontSize: 18)),
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
    final buffer = StringBuffer('未能识别出食物。\n\n');
    buffer.writeln('\n请尝试：');
    buffer.writeln('1. 拍一盘做好的菜，确保食物占画面主体');
    buffer.writeln('2. 使用「搜索食物」输入名称');
    buffer.writeln('3. 包装食品可拍配料表照片，自动读取卡路里');
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
          borderRadius: AppRadii.mdAll,
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
                            '未找到相关食物，请换个名称试试',
                            style: _bodyStyle,
                          ),
                          backgroundColor: AppColors.bg3,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadii.smAll,
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
                          borderRadius: AppRadii.smAll,
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
                borderRadius: AppRadii.mdAll,
                side: const BorderSide(color: AppColors.border),
              ),
              title: Row(
                children: [
                  Icon(Icons.search, color: AppColors.copper, size: 20),
                  const SizedBox(width: AppSpace.sm),
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
                                padding: const EdgeInsets.all(AppSpace.md),
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
                                '${food.calories} kcal',
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
    MealType? initialMeal,
  }) {
    final selected = <String, RecognizedFood>{};
    final portions = <String, FoodSize>{};
    for (final f in foods) {
      portions[f.name] = FoodSize.medium;
    }
    if (foods.isNotEmpty) {
      selected[foods.first.name] = foods.first;
    }
    // 默认餐次：调用方指定（如在某餐内搜索）优先，否则按时间段推断
    MealType meal = initialMeal ?? _getCurrentMeal();
    bool expanded = false;
    // 今日卡路里预算（目标/已摄入/剩余），打开弹窗时快照
    final budget = ref.read(gameStateProvider);

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
              borderRadius: AppRadii.mdAll,
              side: const BorderSide(color: AppColors.border),
            ),
            title: Row(
              children: [
                Icon(Icons.restaurant_outlined, color: AppColors.copper, size: 20),
                const SizedBox(width: AppSpace.sm),
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
                    // 今日卡路里预算提醒：建议摄入 / 已摄入 / 剩余
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
                      decoration: BoxDecoration(
                        color: AppColors.bg2,
                        borderRadius: AppRadii.smAll,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('今日建议摄入', style: _bodyStyle.copyWith(fontSize: 12, color: AppColors.text2)),
                              Text('${budget.targetCal} kcal', style: _bodyStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text)),
                            ],
                          ),
                          const SizedBox(height: AppSpace.xs),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '已摄入 ${budget.todayCalIn} kcal${budget.todayCalExercise > 0 ? ' · 运动消耗 ${budget.todayCalExercise} kcal' : ''}',
                                style: _bodyStyle.copyWith(fontSize: 12, color: AppColors.text2),
                              ),
                              Text('还可摄入 ${budget.remainingCal} kcal', style: _bodyStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    // 餐次选择器：默认跟随入口（某餐内搜索即默认该餐）
                    Row(
                      children: [
                        Text('记到', style: _mutedStyle.copyWith(fontSize: 12)),
                        const SizedBox(width: AppSpace.sm),
                        ...MealType.values.map((m) => ForgePressable(
                          onTap: () => sb(() => meal = m),
                          borderRadius: AppRadii.smAll,
                          child: Container(
                            margin: const EdgeInsets.only(right: AppSpace.xs + 2),
                            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
                            decoration: BoxDecoration(
                              color: meal == m
                                  ? AppColors.copper.withValues(alpha: 0.18)
                                  : Colors.transparent,
                              borderRadius: AppRadii.smAll,
                              border: Border.all(color: meal == m ? AppColors.copper : AppColors.border),
                            ),
                            child: Text(
                              m.name,
                              style: _bodyStyle.copyWith(fontSize: 12, color: meal == m ? AppColors.copper : AppColors.text),
                            ),
                          ),
                        )),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    Text(
                      '请确认并勾选要记录的食物：',
                      style: _mutedStyle,
                    ),
                    const SizedBox(height: AppSpace.md),
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
                        margin: const EdgeInsets.only(bottom: AppSpace.sm),
                        padding: const EdgeInsets.all(AppSpace.sm),
                        decoration: BoxDecoration(
                          color: AppColors.bg2,
                          borderRadius: AppRadii.smAll,
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
                                  const SizedBox(height: AppSpace.xs),
                                  Text(
                                    '${food.calories} kcal/份',
                                    style: _mutedStyle.copyWith(fontSize: 12),
                                  ),
                                  if (probability != null) ...[
                                    const SizedBox(height: AppSpace.xs + 2),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(AppSpace.xs - 1),
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
                                        const SizedBox(width: AppSpace.sm),
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
                                    const SizedBox(width: AppSpace.sm),
                                    ...FoodSize.values.map((s) {
                                      final isSel = size == s;
                                      return ForgePressable(
                                        onTap: () {
                                          portions[food.name] = s;
                                          sb(() {});
                                        },
                                        borderRadius: AppRadii.smAll,
                                        child: Container(
                                          margin: const EdgeInsets.only(right: AppSpace.xs + 2),
                                          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isSel
                                                ? AppColors.copper.withValues(alpha: 0.15)
                                                : Colors.transparent,
                                            borderRadius: AppRadii.smAll,
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
                    const SizedBox(height: AppSpace.sm),
                    Builder(builder: (_) {
                      final leftAfter = budget.remainingCal - totalCal;
                      return Container(
                        padding: const EdgeInsets.all(AppSpace.md),
                        decoration: BoxDecoration(
                          color: AppColors.copper.withValues(alpha: 0.1),
                          borderRadius: AppRadii.smAll,
                          border: Border.all(
                            color: AppColors.copper.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
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
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  leftAfter >= 0 ? '记录后今日还可摄入' : '记录后将超出建议摄入',
                                  style: _bodyStyle.copyWith(
                                    fontSize: 12,
                                    color: leftAfter >= 0 ? AppColors.text2 : AppColors.red,
                                  ),
                                ),
                                Text(
                                  '${leftAfter.abs()} kcal',
                                  style: _bodyStyle.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: leftAfter >= 0 ? AppColors.green : AppColors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
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
                        final leftAfterAdd = budget.remainingCal - totalCal;
                        _showSnack(leftAfterAdd >= 0
                            ? '已记录${selected.length}种食物到${meal.name}，今日还可摄入 $leftAfterAdd kcal'
                            : '已记录${selected.length}种食物到${meal.name}，今日已超出建议摄入 ${-leftAfterAdd} kcal');
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
        shape: RoundedRectangleBorder(borderRadius: AppRadii.smAll),
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
        padding: AppSpace.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRecognitionArea(),
            const SizedBox(height: AppSpace.lg),
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
    return ForgeSurface(
      color: AppColors.card,
      borderColor: AppColors.copper.withValues(alpha: 0.55),
      borderRadius: AppRadii.lgAll,
      boxShadow: [
        BoxShadow(
          color: AppColors.ember.withValues(alpha: 0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ForgeSectionHeader(
            title: '智能识别',
            subtitle: '拍照或搜索，快速记录今日饮食',
            trailing: Icon(Icons.restaurant_menu_outlined, color: AppColors.copper, size: 20),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Expanded(
                child: _buildRecogButton(
                  icon: Icons.photo_camera_outlined,
                  label: '拍照识别',
                  sub: '菜肴/配料表',
                  accent: AppColors.ember,
                  onTap: _startImageRecognition,
                ),
              ),
              const SizedBox(width: AppSpace.md),
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
    );
  }

  Widget _buildRecogButton({
    required IconData icon,
    required String label,
    required String sub,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return ForgePressable(
      onTap: onTap,
      borderRadius: AppRadii.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.md + 2, horizontal: AppSpace.xs + 2),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: AppRadii.mdAll,
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(height: AppSpace.sm),
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
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.md + 2),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.md)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(_mealIcon(meal), color: AppColors.copper, size: 18),
                    const SizedBox(width: AppSpace.sm),
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
            padding: const EdgeInsets.all(AppSpace.md),
            child: foods.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, color: AppColors.text2, size: 28),
                          const SizedBox(height: AppSpace.xs + 2),
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
            padding: const EdgeInsets.all(AppSpace.md),
            child: _buildFoodInput(meal, gameNotifier),
          ),
          if (_searchResults[meal] != null && _searchResults[meal]!.isNotEmpty)
            _buildSearchResults(meal, gameNotifier),
          if ((_searching[meal] ?? false) == false &&
              _foodNameControllers[meal]!.text.trim().isNotEmpty &&
              (_searchResults[meal]?.isEmpty ?? true))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              child: Text(
                '未找到「${_foodNameControllers[meal]!.text.trim()}」，可手动输入千卡后添加',
                style: _mutedStyle.copyWith(fontSize: 12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: _buildQuickTags(meal, gameNotifier),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(MealType meal, GameStateNotifier gameNotifier) {
    final results = _searchResults[meal]!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.copper.withValues(alpha: 0.06),
        borderRadius: AppRadii.smAll,
        border: Border.all(color: AppColors.copper.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpace.xs, bottom: AppSpace.xs),
            child: Row(
              children: [
                Icon(Icons.search, size: 14, color: AppColors.copper),
                const SizedBox(width: AppSpace.xs),
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
            return ForgePressable(
              onTap: () {
                _foodNameControllers[meal]!.clear();
                setState(() {
                  _searchResults[meal] = [];
                });
                // 餐内搜索：确认弹窗默认记录到当前餐次
                _showFoodConfirmDialog([food], '搜索结果', initialMeal: meal);
              },
              borderRadius: BorderRadius.circular(AppSpace.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs + 2),
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(AppSpace.sm),
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
      margin: const EdgeInsets.only(bottom: AppSpace.xs + 2),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs + 3),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: AppRadii.smAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // 餐次色点：快速区分记录归属
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.copper.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(food.name, style: _bodyStyle.copyWith(fontSize: 13))),
          Text(food.size.name, style: _mutedStyle.copyWith(fontSize: 11)),
          const SizedBox(width: AppSpace.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.copper.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '${food.totalCal} kcal',
              style: _bodyStyle.copyWith(
                color: AppColors.copper,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 2),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.md),
                  suffixIcon: isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(AppSpace.md),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                ),
                onChanged: (v) => _onSearchChanged(v, meal),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: TextField(
                controller: calController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '千卡',
                  contentPadding: EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.md),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
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
            const SizedBox(width: AppSpace.sm),
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
                final leftAfter = ref.read(gameStateProvider).remainingCal;
                _showSnack(leftAfter >= 0
                    ? '已添加 $name，今日还可摄入 $leftAfter kcal'
                    : '已添加 $name，今日已超出建议摄入 ${-leftAfter} kcal');
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.md),
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
        _foodPrefService.recordFoodAdded(food.name);
        final leftAfter = ref.read(gameStateProvider).remainingCal;
        _showSnack(leftAfter >= 0
            ? '已添加 ${food.name} 到${meal.name}，今日还可摄入 $leftAfter kcal'
            : '已添加 ${food.name} 到${meal.name}，今日已超出建议摄入 ${-leftAfter} kcal');
      },
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
            content: Text('拍照失败: $e', style: AppFonts.body(color: AppColors.text)),
            backgroundColor: AppColors.ember,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadii.smAll),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('拍摄食物', style: AppFonts.display(fontWeight: FontWeight.w600)),
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
                    child: ForgePressable(
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
