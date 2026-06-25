import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../models/game_models.dart';
import '../providers/game_provider.dart';

/// 饮食记录页面
class FoodPage extends ConsumerStatefulWidget {
  const FoodPage({super.key});
  
  @override
  ConsumerState<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends ConsumerState<FoodPage> {
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
            // 拍照识别区域（可扩展）
            _buildCameraArea(),
            const SizedBox(height: 16),
            
            // 各餐记录
            ...MealType.values.map((meal) => 
              _buildMealSection(meal, gameState, gameNotifier),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 拍照识别区域
  Widget _buildCameraArea() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📷 拍照识别食物',
                  style: TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: 打开摄像头拍照识别
                  },
                  child: const Text('展开'),
                ),
              ],
            ),
            // TODO: 摄像头预览和识别结果
          ],
        ),
      ),
    );
  }
  
  /// 餐区
  Widget _buildMealSection(MealType meal, GameState gameState, GameStateNotifier gameNotifier) {
    final foods = gameState.meals[meal] ?? [];
    final mealCal = foods.fold(0, (sum, f) => sum + f.totalCal);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // 餐头
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '$mealCal 千卡',
                  style: TextStyle(color: AppColors.gold),
                ),
              ],
            ),
          ),
          
          // 食物列表
          Padding(
            padding: const EdgeInsets.all(12),
            child: foods.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        '📭 还没有记录',
                        style: TextStyle(color: AppColors.text2),
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
          
          // 输入行
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildFoodInput(meal, gameNotifier),
          ),
          
          // 快捷标签
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildQuickTags(meal, gameNotifier),
          ),
        ],
      ),
    );
  }
  
  /// 食物条目
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
  
  /// 食物输入
  Widget _buildFoodInput(MealType meal, GameStateNotifier gameNotifier) {
    final nameController = TextEditingController();
    final calController = TextEditingController();
    String selectedSize = 'medium';
    
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: nameController,
            decoration: InputDecoration(
              hintText: '食物名称',
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: calController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '千卡',
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
          onChanged: (v) => selectedSize = v ?? 'medium',
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
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          child: const Text('添加'),
        ),
      ],
    );
  }
  
  /// 快捷标签
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