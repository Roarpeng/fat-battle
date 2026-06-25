import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../models/game_models.dart';
import '../providers/game_provider.dart';
import '../services/game_algorithm.dart';
import '../services/ble_service.dart';
import '../services/motion_recognition.dart';

/// 锻炼页面
class ExercisePage extends ConsumerStatefulWidget {
  const ExercisePage({super.key});
  
  @override
  ConsumerState<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends ConsumerState<ExercisePage> {
  int? _selectedExercise;
  int? _selectedDuration;
  String _exerciseMode = 'manual'; // 'manual' | 'camera' | 'imu'
  
  final MotionRecognitionService _motionService = MotionRecognitionService();
  
  @override
  void initState() {
    super.initState();
    _motionService.onRepDetected = (count, exercise) {
      _showToast('${count}个${exercise}！');
    };
    _motionService.onFeedback = (feedback) {
      _showToast(feedback);
    };
  }
  
  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);
    final bleService = ref.watch(bleServiceProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏋️ 锻炼攻击'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 模式切换
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => setState(() => _exerciseMode = 'manual'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _exerciseMode == 'manual' ? AppColors.green : AppColors.bg2,
                  ),
                  child: const Text('手动模式'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => setState(() => _exerciseMode = 'imu'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _exerciseMode == 'imu' ? AppColors.green : AppColors.bg2,
                  ),
                  child: const Text('IMU识别'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => setState(() => _exerciseMode = 'camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _exerciseMode == 'camera' ? AppColors.green : AppColors.bg2,
                  ),
                  child: const Text('摄像头'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // IMU模式显示BLE连接状态
            if (_exerciseMode == 'imu')
              _buildBleStatus(bleService),
            
            // 运动选择
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('选择运动', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.5,
                      children: Exercises.all.asMap().entries.map((entry) {
                        final index = entry.key;
                        final exercise = entry.value;
                        final isSelected = _selectedExercise == index;
                        
                        return GestureDetector(
                          onTap: () => setState(() => _selectedExercise = index),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.green.withOpacity(0.1) : AppColors.bg2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.green : AppColors.border,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(exercise.emoji, style: const TextStyle(fontSize: 32)),
                                Text(exercise.name, style: const TextStyle(fontSize: 14)),
                                Text(
                                  '${exercise.calPerMin}千卡/分钟',
                                  style: TextStyle(color: AppColors.gold, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 时长选择
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('选择时长', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: durations.map((d) {
                        final isSelected = _selectedDuration == d;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedDuration = d),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.green.withOpacity(0.1) : AppColors.bg2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? AppColors.green : AppColors.border,
                              ),
                            ),
                            child: Text(
                              '$d分钟',
                              style: TextStyle(
                                color: isSelected ? AppColors.green : AppColors.text,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 预览
            if (_selectedExercise != null && _selectedDuration != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '${_calcPreviewCal()}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.green,
                        ),
                      ),
                      const Text('预计消耗千卡'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${_calcPreviewDamage()}',
                            style: TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(' 点伤害', style: TextStyle(color: AppColors.text2)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            
            // 发动攻击按钮
            ElevatedButton(
              onPressed: () => _executeExercise(gameNotifier, gameState),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('⚔️ 发动攻击'),
            ),
            const SizedBox(height: 16),
            
            // 今日锻炼记录
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📋 今日锻炼', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (gameState.exercises.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text('今天还没有锻炼', style: TextStyle(color: AppColors.text2)),
                        ),
                      )
                    else
                      Column(
                        children: gameState.exercises.map((ex) => 
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.bg2,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Text('${ex.emoji} ${ex.name}'),
                                const Spacer(),
                                Text('${ex.duration}分钟 / ${ex.cal}千卡', style: TextStyle(color: AppColors.text2)),
                                const SizedBox(width: 8),
                                Text('-${ex.damage}', style: TextStyle(color: AppColors.green)),
                              ],
                            ),
                          ),
                        ).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// BLE状态
  Widget _buildBleStatus(BleService bleService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('BLE设备状态'),
                ElevatedButton(
                  onPressed: () => bleService.startScan(),
                  child: const Text('扫描设备'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // TODO: 显示连接状态和实时IMU数据
          ],
        ),
      ),
    );
  }
  
  /// 计算预览卡路里
  int _calcPreviewCal() {
    if (_selectedExercise == null || _selectedDuration == null) return 0;
    final exercise = Exercises.all[_selectedExercise!];
    return GameAlgorithm.calcExerciseCal(exercise, _selectedDuration!);
  }
  
  /// 计算预览伤害
  int _calcPreviewDamage() {
    final cal = _calcPreviewCal();
    final result = GameAlgorithm.exerciseImpactOnMonster(cal, _exerciseMode, 100, 100);
    return result.damage;
  }
  
  /// 执行锻炼
  void _executeExercise(GameStateNotifier gameNotifier, GameState gameState) {
    if (_selectedExercise == null) {
      _showToast('请选择运动类型');
      return;
    }
    if (_selectedDuration == null) {
      _showToast('请选择运动时长');
      return;
    }
    if (gameState.status != GameStatus.playing) {
      _showToast('今天的战斗已结束');
      return;
    }
    
    final exercise = Exercises.all[_selectedExercise!];
    final cal = GameAlgorithm.calcExerciseCal(exercise, _selectedDuration!);
    
    final record = ExerciseRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now().toDateString(),
      name: exercise.name,
      emoji: exercise.emoji,
      duration: _selectedDuration!,
      cal: cal,
      damage: _calcPreviewDamage(),
      mode: _exerciseMode,
    );
    
    gameNotifier.addExercise(record);
    _showToast('${exercise.emoji} ${exercise.name}完成！造成${_calcPreviewDamage()}点伤害！');
  }
  
  /// 显示提示
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}