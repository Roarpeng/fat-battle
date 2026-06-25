import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
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
  final CameraMotionDetector _cameraDetector = CameraMotionDetector();
  final ScrollController _logScrollController = ScrollController();
  
  bool _isDetecting = false;
  int _repCount = 0;
  String _feedback = '';
  DateTime? _detectStartTime;
  List<String> _bleLogs = [];
  
  bool _cameraReady = false;
  bool _cameraDetecting = false;
  int _cameraRepCount = 0;
  String _cameraFeedback = '准备开始';
  double _motionLevel = 0;
  DateTime? _cameraStartTime;
  
  @override
  void initState() {
    super.initState();
    _motionService.onRepDetected = (count, exercise) {
      setState(() {
        _repCount = count;
      });
    };
    _motionService.onFeedback = (feedback) {
      setState(() {
        _feedback = feedback;
      });
    };
    
    _cameraDetector.onRepDetected = (count, exercise) {
      if (mounted) {
        setState(() {
          _cameraRepCount = count;
        });
      }
    };
    _cameraDetector.onFeedback = (feedback) {
      if (mounted) {
        setState(() {
          _cameraFeedback = feedback;
        });
      }
    };
    _cameraDetector.onMotionUpdate = (level) {
      if (mounted) {
        setState(() {
          _motionLevel = level;
        });
      }
    };
  }
  
  @override
  void dispose() {
    _logScrollController.dispose();
    _cameraDetector.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);
    final bleService = ref.watch(bleServiceProvider);
    final connectionState = ref.watch(bleConnectionStateProvider);
    final imuDataAsync = ref.watch(imuDataStreamProvider);
    final bleLogAsync = ref.watch(bleLogProvider);
    
    ref.listen(bleLogProvider, (previous, next) {
      next.whenData((log) {
        setState(() {
          _bleLogs.add(log);
          if (_bleLogs.length > 50) {
            _bleLogs.removeAt(0);
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_logScrollController.hasClients) {
            _logScrollController.animateTo(
              _logScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      });
    });
    
    ref.listen(imuDataStreamProvider, (previous, next) {
      next.whenData((imuData) {
        if (_isDetecting) {
          _motionService.addImuData(imuData);
        }
      });
    });
    
    final isConnected = connectionState.value?.isConnected ?? false;
    
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
            
            // IMU模式显示BLE连接状态和检测界面
            if (_exerciseMode == 'imu') ...[
              _buildBleStatus(bleService, isConnected, imuDataAsync),
              const SizedBox(height: 16),
              if (_isDetecting)
                _buildDetectionPanel(isConnected)
              else if (isConnected && _selectedExercise != null)
                _buildStartDetectionButton(),
            ],
            
            // 摄像头模式
            if (_exerciseMode == 'camera') ...[
              _buildCameraPanel(),
              const SizedBox(height: 16),
            ],
            
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
  Widget _buildBleStatus(BleService bleService, bool isConnected, AsyncValue<ImuData> imuDataAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected ? AppColors.green : AppColors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isConnected ? '已连接' : '未连接',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isConnected ? AppColors.green : AppColors.red,
                      ),
                    ),
                  ],
                ),
                isConnected
                    ? ElevatedButton(
                        onPressed: _isDetecting ? null : () => _disconnectDevice(bleService),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                        child: const Text('断开'),
                      )
                    : ElevatedButton(
                        onPressed: () => _startScan(bleService),
                        child: const Text('扫描设备'),
                      ),
              ],
            ),
            const SizedBox(height: 16),
            if (isConnected) ...[
              const Text(
                '实时IMU数据',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              _buildImuDataDisplay(imuDataAsync),
              const SizedBox(height: 16),
            ],
            const Text(
              'BLE日志',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              height: 100,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: _bleLogs.isEmpty
                  ? Center(
                      child: Text(
                        '暂无日志',
                        style: TextStyle(color: AppColors.text2, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      controller: _logScrollController,
                      itemCount: _bleLogs.length,
                      itemBuilder: (context, index) {
                        return Text(
                          _bleLogs[index],
                          style: TextStyle(color: AppColors.text2, fontSize: 11),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// IMU数据显示
  Widget _buildImuDataDisplay(AsyncValue<ImuData> imuDataAsync) {
    return imuDataAsync.when(
      data: (imuData) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildImuItem('ax', imuData.ax.toStringAsFixed(2), 'g')),
                const SizedBox(width: 8),
                Expanded(child: _buildImuItem('ay', imuData.ay.toStringAsFixed(2), 'g')),
                const SizedBox(width: 8),
                Expanded(child: _buildImuItem('az', imuData.az.toStringAsFixed(2), 'g')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildImuItem('gx', imuData.gx.toStringAsFixed(1), '°/s')),
                const SizedBox(width: 8),
                Expanded(child: _buildImuItem('gy', imuData.gy.toStringAsFixed(1), '°/s')),
                const SizedBox(width: 8),
                Expanded(child: _buildImuItem('gz', imuData.gz.toStringAsFixed(1), '°/s')),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: Text('等待数据...')),
      error: (error, stack) => Center(child: Text('数据错误: $error')),
    );
  }
  
  /// IMU数据项
  Widget _buildImuItem(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: AppColors.text2, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(unit, style: TextStyle(color: AppColors.text2, fontSize: 10)),
        ],
      ),
    );
  }
  
  /// 开始检测按钮
  Widget _buildStartDetectionButton() {
    final exercise = Exercises.all[_selectedExercise!];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '已选择: ${exercise.emoji} ${exercise.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _startDetection,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('▶️ 开始检测'),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 检测面板
  Widget _buildDetectionPanel(bool isConnected) {
    final exercise = _selectedExercise != null ? Exercises.all[_selectedExercise!] : null;
    final elapsed = _detectStartTime != null
        ? DateTime.now().difference(_detectStartTime!)
        : Duration.zero;
    final elapsedMinutes = elapsed.inSeconds / 60.0;
    final estimatedCal = exercise != null
        ? (exercise.calPerMin * elapsedMinutes).round()
        : 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              '${exercise?.emoji ?? ''} ${exercise?.name ?? ''} 检测中',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDuration(elapsed),
              style: TextStyle(color: AppColors.text2, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '$_repCount',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.green,
                      ),
                    ),
                    Text(
                      _getCountUnit(exercise?.type),
                      style: TextStyle(color: AppColors.text2, fontSize: 12),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '$estimatedCal',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                      ),
                    ),
                    const Text(
                      '千卡',
                      style: TextStyle(color: AppColors.text2, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_feedback.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.green.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💬 ', style: TextStyle(fontSize: 16)),
                    Text(
                      _feedback,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _stopDetection,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('⏹️ 结束检测'),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 摄像头面板
  Widget _buildCameraPanel() {
    final exercise = _selectedExercise != null ? Exercises.all[_selectedExercise!] : null;
    final elapsed = _cameraStartTime != null
        ? DateTime.now().difference(_cameraStartTime!)
        : Duration.zero;
    final elapsedMinutes = elapsed.inSeconds / 60.0;
    final estimatedCal = exercise != null
        ? (exercise.calPerMin * elapsedMinutes).round()
        : 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              '📷 摄像头动作识别',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              height: 240,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: _cameraReady && _cameraDetector.controller != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CameraPreview(_cameraDetector.controller!),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_off,
                            size: 48,
                            color: AppColors.text2,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _cameraReady ? '摄像头未就绪' : '点击下方按钮启动摄像头',
                            style: TextStyle(color: AppColors.text2, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            if (_cameraDetecting) ...[
              _buildMotionIndicator(),
              const SizedBox(height: 12),
            ],
            if (_cameraDetecting || _cameraRepCount > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$_cameraRepCount',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.green,
                        ),
                      ),
                      Text(
                        _getCountUnit(exercise?.type),
                        style: TextStyle(color: AppColors.text2, fontSize: 12),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '$estimatedCal',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gold,
                        ),
                      ),
                      const Text(
                        '千卡',
                        style: TextStyle(color: AppColors.text2, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_cameraFeedback.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💬 ', style: TextStyle(fontSize: 16)),
                      Text(
                        _cameraFeedback,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              if (_cameraStartTime != null)
                Text(
                  '已运动 ${_formatDuration(elapsed)}',
                  style: TextStyle(color: AppColors.text2, fontSize: 12),
                ),
              const SizedBox(height: 12),
            ],
            if (!_cameraReady && !_cameraDetecting)
              ElevatedButton(
                onPressed: _initCamera,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: const Text('📷 启动摄像头'),
              )
            else if (_cameraReady && !_cameraDetecting) ...[
              if (_selectedExercise == null)
                Text(
                  '请先选择运动类型',
                  style: TextStyle(color: AppColors.text2, fontSize: 13),
                )
              else
                ElevatedButton(
                  onPressed: _startCameraDetection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text('▶️ 开始检测'),
                ),
            ]
            else if (_cameraDetecting)
              ElevatedButton(
                onPressed: _stopCameraDetection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: const Text('⏹️ 结束检测'),
              ),
          ],
        ),
      ),
    );
  }
  
  /// 运动强度指示器
  Widget _buildMotionIndicator() {
    final maxLevel = 30.0;
    final normalizedLevel = (_motionLevel / maxLevel).clamp(0.0, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '运动强度',
              style: TextStyle(color: AppColors.text2, fontSize: 12),
            ),
            Text(
              _motionLevel.toStringAsFixed(1),
              style: TextStyle(color: AppColors.text2, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: normalizedLevel,
            child: Container(
              decoration: BoxDecoration(
                color: normalizedLevel > 0.7
                    ? AppColors.green
                    : normalizedLevel > 0.3
                        ? AppColors.gold
                        : AppColors.red,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  /// 启动摄像头
  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _showToast('请授予摄像头权限');
      return;
    }
    
    try {
      await _cameraDetector.initialize();
      setState(() {
        _cameraReady = true;
      });
      _showToast('摄像头已就绪');
    } catch (e) {
      _showToast('摄像头初始化失败: $e');
    }
  }
  
  /// 开始摄像头检测
  void _startCameraDetection() {
    if (_selectedExercise == null) {
      _showToast('请先选择运动类型');
      return;
    }
    
    final exercise = Exercises.all[_selectedExercise!];
    
    setState(() {
      _cameraDetecting = true;
      _cameraRepCount = 0;
      _cameraFeedback = '开始运动吧！';
      _cameraStartTime = DateTime.now();
    });
    
    _cameraDetector.startDetection(exercise.type);
    _showToast('开始检测 ${exercise.name}');
    _startCameraTimer();
  }
  
  /// 停止摄像头检测
  void _stopCameraDetection() {
    _cameraDetector.stopDetection();
    
    final gameNotifier = ref.read(gameStateProvider.notifier);
    _finishCameraDetection(gameNotifier);
    
    setState(() {
      _cameraDetecting = false;
    });
  }
  
  /// 完成摄像头检测并保存记录
  void _finishCameraDetection(GameStateNotifier gameNotifier) {
    if (_selectedExercise == null || _cameraStartTime == null) return;
    
    final exercise = Exercises.all[_selectedExercise!];
    final elapsed = DateTime.now().difference(_cameraStartTime!);
    final durationMinutes = (elapsed.inSeconds / 60).ceil();
    if (durationMinutes < 1) {
      _showToast('运动时间太短，未记录');
      setState(() {
        _cameraStartTime = null;
        _cameraRepCount = 0;
        _cameraFeedback = '准备开始';
      });
      return;
    }
    
    final cal = GameAlgorithm.calcExerciseCal(exercise, durationMinutes);
    final damageResult = GameAlgorithm.exerciseImpactOnMonster(
      cal,
      'camera',
      gameNotifier.state.monster.hp,
      gameNotifier.state.monster.maxHp,
      gameNotifier.state.monster.shield,
    );
    
    final record = ExerciseRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now().toDateString(),
      name: exercise.name,
      emoji: exercise.emoji,
      duration: durationMinutes,
      cal: cal,
      damage: damageResult.damage,
      mode: 'camera',
    );
    
    gameNotifier.addExercise(record);
    _showToast('${exercise.emoji} ${exercise.name}完成！${durationMinutes}分钟，消耗${cal}千卡，造成${damageResult.damage}点伤害！');
    
    setState(() {
      _cameraStartTime = null;
      _cameraRepCount = 0;
      _cameraFeedback = '准备开始';
    });
  }
  
  /// 摄像头计时器
  void _startCameraTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_cameraDetecting) {
        timer.cancel();
        return;
      }
      setState(() {});
    });
  }
  
  /// 开始扫描
  void _startScan(BleService bleService) {
    bleService.startScan();
  }
  
  /// 断开设备
  void _disconnectDevice(BleService bleService) {
    if (_isDetecting) {
      _stopDetection();
    }
    bleService.disconnect();
  }
  
  /// 开始检测
  void _startDetection() {
    if (_selectedExercise == null) {
      _showToast('请先选择运动类型');
      return;
    }
    
    final exercise = Exercises.all[_selectedExercise!];
    
    setState(() {
      _isDetecting = true;
      _repCount = 0;
      _feedback = '';
      _detectStartTime = DateTime.now();
    });
    
    _motionService.startDetection(exercise.type);
    _showToast('开始检测 ${exercise.name}');
    
    _startTimer();
  }
  
  /// 停止检测
  void _stopDetection() {
    _motionService.stopDetection();
    
    final gameNotifier = ref.read(gameStateProvider.notifier);
    _finishDetection(gameNotifier);
    
    setState(() {
      _isDetecting = false;
    });
  }
  
  /// 完成检测并保存记录
  void _finishDetection(GameStateNotifier gameNotifier) {
    if (_selectedExercise == null || _detectStartTime == null) return;
    
    final exercise = Exercises.all[_selectedExercise!];
    final elapsed = DateTime.now().difference(_detectStartTime!);
    final durationMinutes = (elapsed.inSeconds / 60).ceil();
    if (durationMinutes < 1) {
      _showToast('运动时间太短，未记录');
      return;
    }
    
    final cal = GameAlgorithm.calcExerciseCal(exercise, durationMinutes);
    final damageResult = GameAlgorithm.exerciseImpactOnMonster(
      cal,
      'imu',
      gameNotifier.state.monster.hp,
      gameNotifier.state.monster.maxHp,
      gameNotifier.state.monster.shield,
    );
    
    final record = ExerciseRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now().toDateString(),
      name: exercise.name,
      emoji: exercise.emoji,
      duration: durationMinutes,
      cal: cal,
      damage: damageResult.damage,
      mode: 'imu',
    );
    
    gameNotifier.addExercise(record);
    _showToast('${exercise.emoji} ${exercise.name}完成！${durationMinutes}分钟，消耗${cal}千卡，造成${damageResult.damage}点伤害！');
    
    setState(() {
      _detectStartTime = null;
      _repCount = 0;
      _feedback = '';
    });
  }
  
  /// 计时器 - 用于更新UI显示
  void _startTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isDetecting) {
        timer.cancel();
        return;
      }
      setState(() {});
    });
  }
  
  /// 格式化时长
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
  
  /// 获取计数单位
  String _getCountUnit(String? exerciseType) {
    switch (exerciseType) {
      case 'running':
      case 'walking':
        return '步';
      case 'pushup':
        return '个俯卧撑';
      case 'squat':
        return '个深蹲';
      case 'jumping_jack':
        return '个开合跳';
      default:
        return '次';
    }
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
    final result = GameAlgorithm.exerciseImpactOnMonster(cal, _exerciseMode, 100, 100, 0);
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