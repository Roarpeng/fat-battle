import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_constants.dart';
import '../models/game_models.dart';
import '../providers/game_provider.dart';
import '../services/game_algorithm.dart';
import '../services/ble_service.dart';
import '../services/motion_recognition.dart';
import '../services/pose_detection_service.dart';
import '../services/tflite_motion_service.dart';
import '../services/exercise_game_logic.dart';
import '../widgets/exercise/pose_overlay.dart';
import '../widgets/home/forge_background.dart';
import '../widgets/home/mini_monster_header.dart';

/// 锻炼页面
class ExercisePage extends ConsumerStatefulWidget {
  /// 从舞台 push 进入时显示迷你怪血条
  final bool showMonsterHeader;

  const ExercisePage({super.key, this.showMonsterHeader = false});
  
  @override
  ConsumerState<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends ConsumerState<ExercisePage> {
  int? _selectedExercise;
  int? _selectedDuration;
  String _exerciseMode = 'manual'; // 'manual' | 'camera' | 'imu'
  String _cameraEngine = 'mlkit'; // 'mlkit' | 'tflite'
  bool _cameraBleFusion = false;
  
  final MotionRecognitionService _motionService = MotionRecognitionService();
  final FusionRecognitionService _fusionService = FusionRecognitionService();
  final PoseDetectionService _cameraDetector = PoseDetectionService();
  final TfliteMotionService _tfliteDetector = TfliteMotionService();
  final ExerciseGameLogic _gameLogic = ExerciseGameLogic();
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
  double _sensitivity = 0.5;
  DateTime? _cameraStartTime;
  Map<String, Map<String, double>>? _currentLandmarks;
  bool _cameraSettling = false;

  TextStyle get _displayStyle => GoogleFonts.fraunces(
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      );

  TextStyle get _bodyStyle => GoogleFonts.figtree(color: AppColors.text);

  TextStyle get _mutedStyle =>
      GoogleFonts.figtree(color: AppColors.text2, fontSize: 13);
  
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
    
    _wireCameraCallbacks(_cameraDetector);
    _wireCameraCallbacks(_tfliteDetector);

    _fusionService.onRepDetected = (count, exercise) {
      if (_cameraBleFusion && mounted) {
        setState(() {
          _cameraRepCount = count;
        });
      }
    };
    _fusionService.onFeedback = (feedback) {
      if (_cameraBleFusion && mounted) {
        setState(() {
          _cameraFeedback = feedback;
        });
      }
    };

    // 游戏逻辑回调
    _gameLogic.onComboChanged = (combo, multiplier) {
      if (mounted) setState(() {});
    };
    _gameLogic.onStaminaChanged = (stamina, depleted) {
      if (mounted) setState(() {});
    };
    _gameLogic.onPauseChanged = (paused) {
      if (mounted) setState(() {});
    };
    _gameLogic.onPrepareProgress = (progress) {
      if (mounted) setState(() {});
    };
    _gameLogic.onQualityScored = (quality, grade) {
      if (mounted) {
        setState(() {
          _cameraFeedback = '⭐ $grade (${quality}分) $_cameraFeedback';
        });
      }
    };
  }

  void _wireCameraCallbacks(dynamic detector) {
    detector.onRepDetected = (count, exercise) {
      if (!mounted || !_isActiveCamera(detector)) return;
      if (_cameraBleFusion) {
        _fusionService.updateCameraResult(
          exerciseType: exercise,
          repCount: count,
          accuracy: 0.85,
        );
      } else {
        setState(() {
          _cameraRepCount = count;
        });
      }
      _gameLogic.handleRepSuccess();
    };
    detector.onFeedback = (feedback) {
      if (mounted && _isActiveCamera(detector)) {
        setState(() {
          _cameraFeedback = feedback;
        });
      }
    };
    detector.onMotionUpdate = (level) {
      if (mounted && _isActiveCamera(detector)) {
        setState(() {
          _motionLevel = level;
        });
      }
    };

    if (detector is PoseDetectionService) {
      detector.onPoseUpdate = (landmarks) {
        if (!_isActiveCamera(detector) || !mounted) return;
        if (landmarks == null) {
          setState(() => _currentLandmarks = null);
          return;
        }
        final converted = <String, Map<String, double>>{};
        landmarks.forEach((type, pt) {
          converted[type.name] = {'x': pt.x, 'y': pt.y, 'z': pt.z};
        });
        setState(() {
          _currentLandmarks = converted;
        });
      };
    } else if (detector is TfliteMotionService) {
      detector.onPoseUpdate = (landmarks) {
        if (!_isActiveCamera(detector) || !mounted) return;
        setState(() {
          _currentLandmarks = landmarks;
        });
      };
    }
  }

  bool _isActiveCamera(dynamic detector) {
    if (_cameraEngine == 'mlkit') return detector is PoseDetectionService;
    return detector is TfliteMotionService;
  }

  dynamic get _activeCameraDetector =>
      _cameraEngine == 'mlkit' ? _cameraDetector : _tfliteDetector;

  String get _cameraEngineLabel =>
      _cameraEngine == 'mlkit' ? 'ML Kit' : 'TFLite';
  
  @override
  void dispose() {
    _logScrollController.dispose();
    _cameraDetector.dispose();
    _tfliteDetector.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);
    final bleService = ref.watch(bleServiceProvider);
    final connectionState = ref.watch(bleConnectionStateProvider);
    final imuDataAsync = ref.watch(imuDataStreamProvider);
    
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

    ref.listen(bleStatusProvider, (previous, next) {
      next.whenData((event) {
        if (event.isError) {
          _showToast(event.message);
        }
      });
    });
    
    ref.listen(imuDataStreamProvider, (previous, next) {
      next.whenData((imuData) {
        if (_isDetecting) {
          _motionService.addImuData(imuData);
        }
        if (_cameraDetecting && _cameraBleFusion) {
          _fusionService.updateImuData(imuData);
        }
      });
    });
    
    final isConnected = connectionState.value?.isConnected ?? false;
    
    return PopScope(
      canPop: !_cameraDetecting && !_isDetecting && !_cameraSettling,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_cameraDetecting) {
          _stopCameraDetection();
        }
        if (_isDetecting) {
          _stopDetection();
        }
      },
      child: ForgeBackground(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('锤炼', style: _displayStyle.copyWith(fontSize: 20)),
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
            _buildModeSelector(),
            const SizedBox(height: 16),
            
            // IMU模式显示BLE连接状态和检测界面
            if (_exerciseMode == 'imu') ...[
              _buildBleStatus(bleService, isConnected, imuDataAsync),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '💡 当前为纯 IMU（BLE）识别。摄像头+IMU 融合为可选功能，'
                  '可在「摄像头」模式中连接 BLE 后开启「IMU 融合」。',
                  style: _mutedStyle.copyWith(fontSize: 12),
                ),
              ),
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
            _sectionCard(
              icon: Icons.fitness_center_outlined,
              title: '选择运动',
              child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
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
                              color: isSelected
                                  ? AppColors.copper.withValues(alpha: 0.1)
                                  : AppColors.bg2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.copper : AppColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(exercise.emoji, style: const TextStyle(fontSize: 32)),
                                Text(
                                  exercise.name,
                                  style: _bodyStyle.copyWith(fontSize: 14),
                                ),
                                Text(
                                  '${exercise.calPerMin}千卡/分钟',
                                  style: _mutedStyle.copyWith(
                                    color: AppColors.copper,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 16),
            
            // 时长选择
            _sectionCard(
              icon: Icons.timer_outlined,
              title: '选择时长',
              child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: durations.map((d) {
                        final isSelected = _selectedDuration == d;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedDuration = d),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.copper.withValues(alpha: 0.12)
                                  : AppColors.bg2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? AppColors.copper : AppColors.border,
                              ),
                            ),
                            child: Text(
                              '$d分钟',
                              style: GoogleFonts.figtree(
                                color: isSelected ? AppColors.copper : AppColors.text,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 16),
            
            // 预览
            if (_selectedExercise != null && _selectedDuration != null)
              _sectionCard(
                icon: Icons.local_fire_department_outlined,
                title: '预计效果',
                child: Column(
                    children: [
                      Text(
                        '${_calcPreviewCal()}',
                        style: _displayStyle.copyWith(
                          fontSize: 28,
                          color: AppColors.copper,
                        ),
                      ),
                      Text('预计消耗千卡', style: _mutedStyle),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${_calcPreviewDamage()}',
                            style: _displayStyle.copyWith(
                              fontSize: 18,
                              color: AppColors.ember,
                            ),
                          ),
                          Text(' 点伤害', style: _mutedStyle),
                        ],
                      ),
                    ],
                  ),
              ),
            const SizedBox(height: 16),
            
            // 发动攻击按钮
            ElevatedButton(
              onPressed: () => _executeExercise(gameNotifier, gameState),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ember,
                foregroundColor: const Color(0xFFFFF8F5),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                '⚔️ 发动攻击',
                style: GoogleFonts.figtree(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            const SizedBox(height: 16),
            
            // 今日锻炼记录
            _sectionCard(
              icon: Icons.history_outlined,
              title: '今日锻炼',
              child: gameState.exercises.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text('今天还没有锻炼', style: _mutedStyle),
                          ),
                        )
                      : Column(
                          children: gameState.exercises.map((ex) => 
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Text('${ex.emoji} ${ex.name}', style: _bodyStyle.copyWith(fontSize: 13)),
                                  const Spacer(),
                                  Text(
                                    '${ex.duration}分钟 / ${ex.cal}千卡',
                                    style: _mutedStyle.copyWith(fontSize: 12),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '-${ex.damage}',
                                    style: GoogleFonts.figtree(
                                      color: AppColors.ember,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ).toList(),
                        ),
            ),
          ],
        ),
      ),
    ),
    ),
    );
  }
  
  /// BLE状态
  Widget _buildBleStatus(BleService bleService, bool isConnected, AsyncValue<ImuData> imuDataAsync) {
    return _sectionCard(
      icon: Icons.bluetooth_outlined,
      title: 'BLE 设备',
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected ? AppColors.copper : AppColors.ember,
                        boxShadow: isConnected
                            ? [
                                BoxShadow(
                                  color: AppColors.copper.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isConnected ? '已连接' : '未连接',
                      style: _bodyStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isConnected ? AppColors.copper : AppColors.ember,
                      ),
                    ),
                  ],
                ),
                isConnected
                    ? OutlinedButton(
                        onPressed: _isDetecting ? null : () => _disconnectDevice(bleService),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ember,
                          side: BorderSide(color: AppColors.ember.withValues(alpha: 0.5)),
                        ),
                        child: Text('断开', style: GoogleFonts.figtree(fontSize: 13)),
                      )
                    : OutlinedButton(
                        onPressed: bleService.isScanning
                            ? null
                            : () => _startScan(bleService),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.copper,
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Text(
                          bleService.isScanning ? '扫描中...' : '扫描设备',
                          style: GoogleFonts.figtree(fontSize: 13),
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 16),
            if (isConnected) ...[
              Text(
                '实时 IMU 数据',
                style: _mutedStyle.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildImuDataDisplay(imuDataAsync),
              const SizedBox(height: 16),
            ],
            Text(
              'BLE 日志',
              style: _mutedStyle.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              height: 100,
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: _bleLogs.isEmpty
                  ? Center(
                      child: Text(
                        '暂无日志',
                        style: _mutedStyle.copyWith(fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      controller: _logScrollController,
                      itemCount: _bleLogs.length,
                      itemBuilder: (context, index) {
                        return Text(
                          _bleLogs[index],
                          style: GoogleFonts.figtree(
                            color: AppColors.text2,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        );
                      },
                    ),
            ),
          ],
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
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(label, style: _mutedStyle.copyWith(fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.figtree(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          Text(unit, style: _mutedStyle.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
  
  /// 开始检测按钮
  Widget _buildStartDetectionButton() {
    final exercise = Exercises.all[_selectedExercise!];
    return _sectionCard(
      icon: Icons.play_circle_outline,
      title: '准备检测',
      child: Column(
          children: [
            Text(
              '${exercise.emoji} ${exercise.name}',
              style: _bodyStyle.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '💡 请将手机后置摄像头对准身体侧面',
              style: _mutedStyle.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '保持全身入镜，距离手机 2-3 米',
              style: _mutedStyle.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _startDetection,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ember,
                foregroundColor: const Color(0xFFFFF8F5),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                '▶️ 开始检测',
                style: GoogleFonts.figtree(fontWeight: FontWeight.w700),
              ),
            ),
          ],
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
    
    return _sectionCard(
      icon: Icons.sensors_outlined,
      title: '${exercise?.emoji ?? ''} ${exercise?.name ?? ''} 检测中',
      child: Column(
          children: [
            Text(
              _formatDuration(elapsed),
              style: _mutedStyle,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '$_repCount',
                      style: _displayStyle.copyWith(
                        fontSize: 36,
                        color: AppColors.ember,
                      ),
                    ),
                    Text(
                      _getCountUnit(exercise?.type),
                      style: _mutedStyle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '$estimatedCal',
                      style: _displayStyle.copyWith(
                        fontSize: 36,
                        color: AppColors.copper,
                      ),
                    ),
                    Text('千卡', style: _mutedStyle.copyWith(fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_feedback.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.copper.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.copper.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💬 ', style: TextStyle(fontSize: 16)),
                    Text(
                      _feedback,
                      style: _bodyStyle.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _stopDetection,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ember,
                side: BorderSide(color: AppColors.ember.withValues(alpha: 0.6)),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                '⏹️ 结束检测',
                style: GoogleFonts.figtree(fontWeight: FontWeight.w600),
              ),
            ),
          ],
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
    final calPerMin = exercise?.calPerMin ?? 0;
    final calPerRep = calPerMin / 30.0;
    final estimatedCal = exercise != null
        ? ((calPerMin * elapsedMinutes * 0.3) + (calPerRep * _cameraRepCount)).round()
        : 0;
    
    return _sectionCard(
      icon: Icons.videocam_outlined,
      title: '摄像头动作识别',
      trailing: (!_cameraDetecting)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _cameraEngineLabel,
                style: _mutedStyle.copyWith(fontSize: 11),
              ),
            )
          : null,
      child: Column(
          children: [
            if (!_cameraDetecting) ...[
              _buildCameraAdvancedOptions(),
              const SizedBox(height: 12),
            ],
            Container(
              height: 240,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: _cameraReady && _activeCameraDetector.controller != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Transform.scale(
                            scaleX: -1.0,
                            child: CameraPreview(_activeCameraDetector.controller!),
                          ),
                          if (_cameraDetecting && _currentLandmarks != null)
                            Positioned.fill(
                              child: PoseOverlay(
                                landmarks: _currentLandmarks,
                                size: const Size(double.infinity, 240),
                              ),
                            ),
                          _buildActionGuideOverlay(),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_off_outlined,
                            size: 48,
                            color: AppColors.text2.withValues(alpha: 0.7),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _cameraReady ? '摄像头未就绪' : '点击下方按钮启动摄像头',
                            style: _mutedStyle.copyWith(fontSize: 13),
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
            // 游戏HUD：连击 + 体力
            if (_cameraDetecting) ...[
              if (_gameLogic.comboCount >= 2)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.copper.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.copper.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    '🔥 ${_gameLogic.comboCount}连击 · x${_gameLogic.comboMultiplier.toStringAsFixed(1)}',
                    style: GoogleFonts.figtree(
                      color: AppColors.copper,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (_gameLogic.isPreparing)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      Text('🎬 准备中...', style: _mutedStyle.copyWith(color: AppColors.shield)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _gameLogic.prepareProgress,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.shield),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_gameLogic.isPaused)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.ember.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.ember.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    '⏸️ 已暂停',
                    style: GoogleFonts.figtree(
                      color: AppColors.ember,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: _gameLogic.stamina / ExerciseGameLogic.maxStamina,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _gameLogic.staminaDepleted ? AppColors.ember : AppColors.copper,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_gameLogic.stamina.toInt()}',
                      style: _mutedStyle.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],

            if (_cameraDetecting || _cameraRepCount > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$_cameraRepCount',
                        style: _displayStyle.copyWith(
                          fontSize: 32,
                          color: AppColors.ember,
                        ),
                      ),
                      Text(
                        _getCountUnit(exercise?.type),
                        style: _mutedStyle.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '$estimatedCal',
                        style: _displayStyle.copyWith(
                          fontSize: 32,
                          color: AppColors.copper,
                        ),
                      ),
                      Text('千卡', style: _mutedStyle.copyWith(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_cameraFeedback.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.copper.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.copper.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💬 ', style: TextStyle(fontSize: 16)),
                      Flexible(
                        child: Text(
                          _cameraFeedback,
                          style: _bodyStyle.copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              if (_cameraStartTime != null)
                Text(
                  '已运动 ${_formatDuration(elapsed)}',
                  style: _mutedStyle.copyWith(fontSize: 12),
                ),
              const SizedBox(height: 12),
            ],
            if (!_cameraReady && !_cameraDetecting)
              OutlinedButton.icon(
                onPressed: _initCamera,
                icon: const Icon(Icons.videocam_outlined, size: 18),
                label: Text(
                  '启动摄像头',
                  style: GoogleFonts.figtree(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.copper,
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size(double.infinity, 44),
                ),
              )
            else if (_cameraReady && !_cameraDetecting) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('检测灵敏度', style: _mutedStyle.copyWith(fontSize: 12)),
                      Text(
                        _sensitivity.toStringAsFixed(2),
                        style: _mutedStyle.copyWith(fontSize: 12, color: AppColors.copper),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.copper,
                      inactiveTrackColor: AppColors.border,
                      thumbColor: AppColors.ember,
                      overlayColor: AppColors.ember.withValues(alpha: 0.15),
                    ),
                    child: Slider(
                      value: _sensitivity,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      label: _sensitivity.toStringAsFixed(2),
                      onChanged: (value) {
                        setState(() {
                          _sensitivity = value;
                        });
                        _cameraDetector.setSensitivity(value);
                        _tfliteDetector.setSensitivity(value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_selectedExercise == null)
                Text(
                  '请先选择运动类型',
                  style: _mutedStyle.copyWith(fontSize: 13),
                )
              else
                ElevatedButton(
                  onPressed: _startCameraDetection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ember,
                    foregroundColor: const Color(0xFFFFF8F5),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: Text(
                    '▶️ 开始检测',
                    style: GoogleFonts.figtree(fontWeight: FontWeight.w700),
                  ),
                ),
            ]
            else if (_cameraDetecting)
              OutlinedButton(
                onPressed: _stopCameraDetection,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ember,
                  side: BorderSide(color: AppColors.ember.withValues(alpha: 0.6)),
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: Text(
                  '⏹️ 结束检测',
                  style: GoogleFonts.figtree(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
    );
  }

  /// 摄像头高级选项（引擎 / IMU 融合）
  Widget _buildCameraAdvancedOptions() {
    final bleConnected =
        ref.watch(bleConnectionStateProvider).value?.isConnected == true;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          iconColor: AppColors.copper,
          collapsedIconColor: AppColors.text2,
          title: Text(
            '高级选项',
            style: _mutedStyle.copyWith(fontWeight: FontWeight.w600, color: AppColors.text),
          ),
          subtitle: Text(
            '识别引擎 · IMU 融合',
            style: _mutedStyle.copyWith(fontSize: 11),
          ),
          children: [
            if (!_cameraReady) ...[
              Text('识别引擎', style: _mutedStyle.copyWith(fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _copperChip(
                      label: 'ML Kit',
                      selected: _cameraEngine == 'mlkit',
                      onTap: () => _switchCameraEngine('mlkit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _copperChip(
                      label: 'TFLite',
                      selected: _cameraEngine == 'tflite',
                      onTap: () => _switchCameraEngine('tflite'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (bleConnected && _cameraReady) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('IMU 融合（可选）', style: _bodyStyle.copyWith(fontSize: 13)),
                subtitle: Text(
                  '连接 BLE 后与摄像头计数融合，提升稳定性',
                  style: _mutedStyle.copyWith(fontSize: 11),
                ),
                value: _cameraBleFusion,
                activeTrackColor: AppColors.copper.withValues(alpha: 0.4),
                activeThumbColor: AppColors.copper,
                onChanged: (value) {
                  setState(() => _cameraBleFusion = value);
                  if (value && _selectedExercise != null) {
                    _fusionService.startDetection(
                      Exercises.all[_selectedExercise!].type,
                    );
                    _showToast('已启用摄像头+IMU 融合（实验性）');
                  } else {
                    _fusionService.stopDetection();
                  }
                },
              ),
            ] else if (!bleConnected)
              Text(
                '连接 BLE 设备后可启用 IMU 融合',
                style: _mutedStyle.copyWith(fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
  
  /// 运动强度指示器
  Widget _buildMotionIndicator() {
    final normalizedLevel = _motionLevel.clamp(0.0, 1.0);
    final isAboveThreshold = _motionLevel > 0.3;
    final levelColor = isAboveThreshold ? AppColors.copper : AppColors.text2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '灵敏度: ${_sensitivity.toStringAsFixed(2)}',
              style: _mutedStyle.copyWith(fontSize: 12),
            ),
            Text(
              _motionLevel.toStringAsFixed(2),
              style: _mutedStyle.copyWith(fontSize: 12, color: levelColor),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.border),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: normalizedLevel,
            child: Container(
              decoration: BoxDecoration(
                color: isAboveThreshold
                    ? AppColors.copper
                    : normalizedLevel > 0.5
                        ? AppColors.forgeGlow
                        : AppColors.ember,
                borderRadius: BorderRadius.circular(3),
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
      if (status.isPermanentlyDenied) {
        _showToast('摄像头权限被永久拒绝，请在系统设置中开启');
        await _showPermissionDialog(
          '需要摄像头权限',
          '请在系统设置中允许本应用使用摄像头，以进行姿态识别。',
        );
      } else {
        _showToast('请授予摄像头权限');
      }
      return;
    }

    setState(() => _cameraSettling = true);
    try {
      final ready = await _initializeActiveCameraEngine();
      if (!ready) return;

      setState(() {
        _cameraReady = true;
      });
      _showToast('摄像头已就绪（$_cameraEngineLabel）');
    } catch (e) {
      if (_cameraEngine == 'tflite') {
        final fallback = await _fallbackToMlKit(reason: '$e');
        if (fallback) {
          _showToast('TFLite 初始化失败，已回退 ML Kit');
          return;
        }
      }
      _showToast('摄像头初始化失败: $e');
    } finally {
      if (mounted) {
        setState(() => _cameraSettling = false);
      }
    }
  }

  Future<bool> _initializeActiveCameraEngine() async {
    if (_cameraEngine == 'mlkit') {
      await _cameraDetector.initialize();
      return true;
    }

    final ok = await _tfliteDetector.initialize();
    if (!ok || !_tfliteDetector.modelLoaded) {
      final reason = _tfliteDetector.modelLoadError ?? 'TFLite 模型不可用';
      final fallback = await _fallbackToMlKit(reason: reason);
      if (fallback) {
        _showToast('TFLite 模型未加载，已回退 ML Kit');
      } else {
        _showToast(reason);
      }
      return fallback;
    }
    return true;
  }

  Future<bool> _fallbackToMlKit({required String reason}) async {
    await _tfliteDetector.dispose();
    setState(() => _cameraEngine = 'mlkit');
    try {
      await _cameraDetector.initialize();
      setState(() => _cameraReady = true);
      return true;
    } catch (_) {
      setState(() => _cameraReady = false);
      return false;
    }
  }

  Future<void> _switchCameraEngine(String engine) async {
    if (_cameraEngine == engine || _cameraDetecting) return;

    if (_cameraReady) {
      await _cameraDetector.dispose();
      await _tfliteDetector.dispose();
      setState(() {
        _cameraReady = false;
        _currentLandmarks = null;
        _cameraEngine = engine;
      });
    } else {
      setState(() => _cameraEngine = engine);
    }
  }

  Future<void> _showPermissionDialog(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
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
    
    _gameLogic.reset();
    _gameLogic.startPrepare();
    if (_cameraBleFusion) {
      _fusionService.startDetection(exercise.type);
    }
    _activeCameraDetector.startDetection(exercise.type);
    _showToast('开始检测 ${exercise.name}（$_cameraEngineLabel）');
    _startCameraTimer();
  }
  
  /// 停止摄像头检测
  Future<void> _stopCameraDetection() async {
    if (!_cameraDetecting && _cameraStartTime == null) return;

    setState(() {
      _cameraDetecting = false;
      _cameraSettling = true;
    });

    await _activeCameraDetector.stopDetection();
    if (_cameraBleFusion) {
      _fusionService.stopDetection();
    }

    if (!mounted) return;
    final gameNotifier = ref.read(gameStateProvider.notifier);
    await _finishCameraDetection(gameNotifier);

    if (mounted) {
      setState(() => _cameraSettling = false);
    }
  }
  
  /// 完成摄像头检测并保存记录
  Future<void> _finishCameraDetection(GameStateNotifier gameNotifier) async {
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
    
    final elapsedMinutes = elapsed.inSeconds / 60.0;
    final calPerMin = exercise.calPerMin;
    final calPerRep = calPerMin / 30.0;
    final repCount = _cameraBleFusion
        ? _fusionService.finalRepCount
        : _cameraRepCount;
    final cal = ((calPerMin * elapsedMinutes * 0.3) + (calPerRep * repCount)).round();
    final modeLabel = _cameraEngine == 'tflite' ? 'camera_tflite' : 'camera';
    final damageResult = GameAlgorithm.exerciseImpactOnMonster(
      cal,
      modeLabel,
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
      mode: modeLabel,
    );
    
    gameNotifier.addExercise(record);
    _showToast(
      '${exercise.emoji} ${exercise.name}完成！'
      '${durationMinutes}分钟，$repCount次，消耗${cal}千卡，'
      '造成${damageResult.damage}点伤害！',
    );
    
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
  Future<void> _startScan(BleService bleService) async {
    final started = await bleService.startScan();
    if (!started && mounted) {
      _showToast('BLE 扫描未能启动，请检查蓝牙权限与开关');
    }
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
      _detectStartTime = null;
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
      setState(() {
        _detectStartTime = null;
        _repCount = 0;
        _feedback = '';
      });
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

  /// 动作引导框覆盖层
  Widget _buildActionGuideOverlay() {
    final exercise = _selectedExercise != null ? Exercises.all[_selectedExercise!] : null;
    if (exercise == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 顶部提示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bg.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            ),
            child: Text(
              _getActionTip(exercise.type),
              style: GoogleFonts.figtree(color: AppColors.text, fontSize: 12),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.bg.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _getActionEmoji(exercise.type),
                const SizedBox(width: 8),
                Text(
                  '${exercise.emoji} ${exercise.name}',
                  style: GoogleFonts.figtree(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getActionTip(String exerciseType) {
    switch (exerciseType) {
      case 'pushup':
        return '💡 侧身入镜，保持手肘与肩膀成三角形';
      case 'squat':
        return '💡 正面入镜，下蹲时膝盖不超过脚尖';
      case 'jumping_jack':
        return '💡 正面入镜，手臂上举过头，双脚开合';
      case 'hiit':
      case 'jumprope':
        return '💡 正面入镜，快速跳跃，手脚配合';
      default:
        return '💡 保持全身入镜，距离手机 2-3 米';
    }
  }

  Widget _getActionEmoji(String exerciseType) {
    switch (exerciseType) {
      case 'pushup':
        return const Text('🏋️', style: TextStyle(fontSize: 24));
      case 'squat':
        return const Text('🦵', style: TextStyle(fontSize: 24));
      case 'jumping_jack':
        return const Text('⏭️', style: TextStyle(fontSize: 24));
      case 'hiit':
        return const Text('🔥', style: TextStyle(fontSize: 24));
      case 'jumprope':
        return const Text('🪢', style: TextStyle(fontSize: 24));
      default:
        return const Text('🏃', style: TextStyle(fontSize: 24));
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
  
  /// 模式切换
  Widget _buildModeSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'manual',
            label: Text('手动'),
            icon: Icon(Icons.touch_app_outlined, size: 16),
          ),
          ButtonSegment(
            value: 'imu',
            label: Text('IMU'),
            icon: Icon(Icons.sensors_outlined, size: 16),
          ),
          ButtonSegment(
            value: 'camera',
            label: Text('摄像头'),
            icon: Icon(Icons.videocam_outlined, size: 16),
          ),
        ],
        selected: {_exerciseMode},
        onSelectionChanged: (selected) {
          setState(() => _exerciseMode = selected.first);
        },
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFFFF8F5);
            }
            return AppColors.text2;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.copper;
            }
            return AppColors.bg2;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.border),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          textStyle: WidgetStateProperty.all(
            GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.copper, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: _displayStyle.copyWith(fontSize: 17),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _copperChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.copper.withValues(alpha: 0.15)
              : AppColors.bg2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.copper : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.figtree(
            color: selected ? AppColors.copper : AppColors.text2,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  /// 显示提示
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.figtree()),
        backgroundColor: AppColors.bg3,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}