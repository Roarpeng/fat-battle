import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_constants.dart';
import '../models/game_models.dart';
import '../providers/game_provider.dart';
import '../services/food_recognition_service.dart';

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

  static final List<QuickFood> _allFoods = [
    ...QuickFoods.breakfast,
    ...QuickFoods.lunch,
    ...QuickFoods.dinner,
    ...QuickFoods.snack,
  ];

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
      final results = await FoodRecognitionService().searchByText(query);
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

  void _startBarcodeScan() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _BarcodeScannerPage(
          onDetected: (barcode) async {
            Navigator.of(ctx).pop();
            _showLoading('正在查询食物信息...');
            final results = await FoodRecognitionService().lookupByBarcode(barcode);
            Navigator.of(context).pop();
            if (results.isEmpty) {
              _showToast('未找到该条形码对应的食物');
              return;
            }
            _showFoodConfirmDialog(results, '扫码识别结果');
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
      final recogResults = await FoodRecognitionService().recognizeByImage(bytes);
      if (mounted) {
        Navigator.of(context).pop();
        if (recogResults.isEmpty) {
          _showToast('未识别到食物');
          return;
        }
        _showFoodConfirmDialog(recogResults, '拍照识别结果');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showToast('识别失败: $e');
      }
    }
  }

  void _showFoodConfirmDialog(List<RecognizedFood> foods, String title) {
    final selected = <String, RecognizedFood>{};
    final portions = <String, FoodSize>{};
    for (final f in foods) {
      selected[f.name] = f;
      portions[f.name] = FoodSize.medium;
    }
    final meal = _getCurrentMeal();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, sb) {
          int totalCal = 0;
          for (final entry in selected.entries) {
            final size = portions[entry.key] ?? FoodSize.medium;
            totalCal += (entry.value.calories * size.multiplier).round();
          }
          return AlertDialog(
            title: Text('🍽️ $title'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
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
                    ...foods.map((food) {
                      final checked = selected.containsKey(food.name);
                      final size = portions[food.name] ?? FoodSize.medium;
                      final cal = (food.calories * size.multiplier).round();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.bg2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              title: Text(food.name, style: const TextStyle(fontSize: 14)),
                              subtitle: Text(
                                '${food.calories} kcal/份 · ${food.source}',
                                style: TextStyle(fontSize: 11, color: AppColors.text2),
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
                    onTap: () {
                      final meal = _getCurrentMeal();
                      Scrollable.ensureVisible(
                        context.findRenderObject()!,
                        duration: const Duration(milliseconds: 300),
                      );
                    },
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
              '🔍 搜索结果（点击添加）',
              style: TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.bold),
            ),
          ),
          ...results.take(5).map((food) {
            return GestureDetector(
              onTap: () {
                gameNotifier.addFood(food.toFoodItem(meal));
                _foodNameControllers[meal]!.clear();
                setState(() {
                  _searchResults[meal] = [];
                });
                _showToast('已添加 ${food.name}');
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
    final quickFoods = meal == MealType.breakfast
        ? QuickFoods.breakfast
        : meal == MealType.lunch
            ? QuickFoods.lunch
            : meal == MealType.dinner
                ? QuickFoods.dinner
                : QuickFoods.snack;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: quickFoods.map((food) {
        return GestureDetector(
          onTap: () {
            gameNotifier.addFood(FoodItem(
              name: food.name,
              baseCal: food.cal,
              size: FoodSize.medium,
              totalCal: food.cal,
              meal: meal,
            ));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '${food.name} ${food.cal}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      }).toList(),
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
    _controller = CameraController(cam, ResolutionPreset.medium, enableAudio: false);
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
