import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import '../models/game_models.dart';
import 'imu_peak.dart';
import 'limb_imu.dart';

/// 动作识别服务 - 融合摄像头和IMU数据
class MotionRecognitionService {
  // IMU数据缓冲区
  final List<ImuData> _imuBuffer = [];
  final int _bufferSize = 100; // 保存最近100个采样点
  
  // 动作检测状态
  String _currentExercise = '';
  int _repCount = 0;
  bool _isDetecting = false;
  ImuPeakCounter? _peak;

  // 动作计数回调
  Function(int count, String exercise)? onRepDetected;
  Function(String feedback)? onFeedback;
  
  /// 添加IMU数据
  void addImuData(ImuData data) {
    _imuBuffer.add(data);
    if (_imuBuffer.length > _bufferSize) {
      _imuBuffer.removeAt(0);
    }
    
    if (_isDetecting) {
      _analyzeMotion(data);
    }
  }
  
  /// 开始检测指定运动
  void startDetection(String exerciseType) {
    _currentExercise = exerciseType;
    _repCount = 0;
    _isDetecting = true;
    _imuBuffer.clear();
    _peak = ImuExercisePeaks.forType(exerciseType);
  }
  
  /// 停止检测
  void stopDetection() {
    _isDetecting = false;
    _currentExercise = '';
  }
  
  /// 分析运动：峰值 + 1–2s 不应期，不用单样本阈值。
  void _analyzeMotion(ImuData data) {
    final peak = _peak;
    if (peak == null) return;
    final mag = data.accelMagnitude;
    if (!peak.ingest(mag)) return;

    _repCount = peak.count;
    switch (_currentExercise) {
      case 'pushup':
        onRepDetected?.call(_repCount, '俯卧撑');
        onFeedback?.call('$_repCount个！继续保持');
      case 'squat':
        onRepDetected?.call(_repCount, '深蹲');
        onFeedback?.call('$_repCount个！大腿在发力');
      case 'jumping_jack':
        onRepDetected?.call(_repCount, '开合跳');
        onFeedback?.call('$_repCount个！心跳加速');
      case 'running':
        onRepDetected?.call(_repCount, '跑步');
        if (_repCount % 10 == 0) {
          onFeedback?.call('$_repCount步！继续跑');
        }
      case 'walking':
        onRepDetected?.call(_repCount, '快走');
        if (_repCount % 20 == 0) {
          onFeedback?.call('$_repCount步！');
        }
      default:
        onRepDetected?.call(_repCount, _currentExercise);
    }
  }
  
  /// 计算运动强度（用于卡路里计算）
  double calculateIntensity() {
    if (_imuBuffer.isEmpty) return 0;
    
    // 计算加速度变化率
    double totalAccelChange = 0;
    for (int i = 1; i < _imuBuffer.length; i++) {
      final prev = _imuBuffer[i - 1];
      final curr = _imuBuffer[i];
      
      final change = math.sqrt(
        math.pow(curr.ax - prev.ax, 2) +
        math.pow(curr.ay - prev.ay, 2) +
        math.pow(curr.az - prev.az, 2)
      );
      totalAccelChange += change;
    }
    
    // 平均变化率
    return totalAccelChange / (_imuBuffer.length - 1);
  }
  
  /// 判断运动类型（自动识别）
  String? detectExerciseType() {
    if (_imuBuffer.length < 50) return null;
    
    // 计算特征
    final avgAccelMag = _imuBuffer.fold(0.0, (sum, d) => sum + d.accelMagnitude) / _imuBuffer.length;
    final avgGyroMag = _imuBuffer.fold(0.0, (sum, d) => sum + d.gyroMagnitude) / _imuBuffer.length;
    
    // 计算加速度方差（判断运动剧烈程度）
    final accelVariance = _calculateVariance(_imuBuffer.map((d) => d.accelMagnitude).toList());
    
    // 根据特征判断运动类型
    if (avgAccelMag > 2.5 && accelVariance > 0.5) {
      return 'running';
    } else if (avgAccelMag > 1.8 && avgGyroMag > 50) {
      return 'jumping_jack';
    } else if (avgGyroMag > 30 && avgAccelMag < 1.5) {
      return 'squat';
    } else if (avgAccelMag > 1.2 && avgAccelMag < 1.8) {
      return 'walking';
    }
    
    return null;
  }
  
  /// 计算方差
  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.fold(0.0, (sum, v) => sum + math.pow(v - mean, 2)) / values.length;
    return variance;
  }
  
  /// 获取当前计数
  int get repCount => _repCount;
  
  /// 获取当前运动类型
  String get currentExercise => _currentExercise;
  
  /// 是否正在检测
  bool get isDetecting => _isDetecting;
  
  /// 清空缓冲区
  void clearBuffer() {
    _imuBuffer.clear();
    _repCount = 0;
    _peak?.reset();
  }
}

/// 摄像头+IMU融合识别
class FusionRecognitionService {
  final MotionRecognitionService _imuService = MotionRecognitionService();
  LimbImuFusion? _limbFusion;
  bool limbConfirmEnabled = false;
  
  // 摄像头检测结果（来自MediaPipe）
  String? _cameraExerciseType;
  int? _cameraRepCount;
  double? _cameraAccuracy;
  
  // 融合结果
  int _finalRepCount = 0;
  double _finalAccuracy = 0;
  bool _lowConfidence = false;
  int _lastEmittedCount = -1;

  /// 融合结果回调
  Function(int count, String exercise)? onRepDetected;
  Function(String feedback)? onFeedback;

  bool get lowConfidence => _lowConfidence;

  /// 更新摄像头检测结果
  void updateCameraResult({
    String? exerciseType,
    int? repCount,
    double? accuracy,
  }) {
    _cameraExerciseType = exerciseType;
    _cameraRepCount = repCount;
    _cameraAccuracy = accuracy;
    
    _fuseResults();
  }
  
  /// 更新IMU检测结果
  void updateImuData(ImuData data) {
    _imuService.addImuData(data);
    _fuseResults();
  }

  /// 腰+四肢聚合帧：腰部仍走原峰值；四肢仅确认票。
  void updateAggregatedImu(AggregatedImuFrame frame) {
    _limbFusion?.ingest(frame);
    final waist = frame.waist;
    if (waist != null) {
      _imuService.addImuData(waist);
    }
    _fuseResults();
  }
  
  /// 融合摄像头和IMU结果。摄像头为计次主源；IMU 为第二票。
  /// 不一致时不以整数平均，标低置信并以摄像头为准。
  void _fuseResults() {
    final exercise = _cameraExerciseType ?? _imuService.currentExercise;
    final camera = _cameraRepCount;
    final imu = _imuService.repCount;

    int next;
    if (camera != null && imu > 0) {
      final delta = (camera - imu).abs();
      _lowConfidence = delta > 1;
      next = camera;
      _finalAccuracy = _lowConfidence ? 0.55 : 0.9;
    } else if (camera != null) {
      next = camera;
      _lowConfidence = imu == 0;
      _finalAccuracy = _cameraAccuracy ?? 0.8;
    } else if (imu > 0) {
      next = imu;
      _lowConfidence = true;
      _finalAccuracy = 0.7;
    } else {
      return;
    }

    if (next == _lastEmittedCount) return;
    _finalRepCount = next;
    _lastEmittedCount = next;
    onRepDetected?.call(_finalRepCount, exercise);
    if (camera != null && imu > 0 && _lowConfidence) {
      onFeedback?.call('摄像头与 IMU 不完全一致，以摄像头为准');
    }
  }
  
  /// 获取融合后的计数
  int get finalRepCount => _finalRepCount;
  
  /// 获取融合后的精度
  double get finalAccuracy => _finalAccuracy;
  
  /// 开始检测
  void startDetection(String exerciseType) {
    _imuService.onRepDetected = (count, exercise) {
      _fuseResults();
    };
    _imuService.onFeedback = onFeedback;
    _imuService.startDetection(exerciseType);
    _limbFusion = LimbImuFusion(
      exerciseType: exerciseType,
      limbConfirmEnabled: limbConfirmEnabled,
    );
    _cameraExerciseType = exerciseType;
    _cameraRepCount = null;
    _finalRepCount = 0;
    _lastEmittedCount = -1;
    _lowConfidence = false;
  }
  
  /// 停止检测
  void stopDetection() {
    _imuService.stopDetection();
    _cameraRepCount = null;
    _cameraExerciseType = null;
  }
  
  /// 获取IMU服务
  MotionRecognitionService get imuService => _imuService;
}

/// 摄像头运动检测器 - 基于帧差分的轻量级运动检测
class CameraMotionDetector {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isDetecting = false;
  bool _isInitialized = false;
  
  int _repCount = 0;
  String _currentExercise = '';
  
  List<int>? _previousFrameLuminance;
  DateTime _lastRepTime = DateTime.now();
  String _motionState = 'idle';
  
  final int _frameSkip = 2;
  int _frameCounter = 0;
  
  double _motionThreshold = 15.0;
  final int _debounceMs = 800;

  // 自动校准
  bool _isCalibrating = false;
  final List<double> _calibrationSamples = [];

  // 滑动窗口峰值检测
  final List<double> _motionHistory = [];
  final int _historySize = 20;
  DateTime _lastPeakTime = DateTime.now();
  DateTime _lastValleyTime = DateTime.now();
  bool _hadPeak = false;

  // 运动时长验证
  final int _minRepMs = 300;
  final int _maxRepMs = 5000;

  Function(int count, String exercise)? onRepDetected;
  Function(String feedback)? onFeedback;
  Function(double motionLevel)? onMotionUpdate;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isDetecting => _isDetecting;
  int get repCount => _repCount;
  bool get isCalibrating => _isCalibrating;
  double get motionThreshold => _motionThreshold;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('没有找到摄像头');
      }
      
      final frontCamera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );
      
      _controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );
      
      await _controller!.initialize();
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }
  
  Future<void> startDetection(String exerciseType) async {
    if (!_isInitialized || _controller == null) return;
    
    _currentExercise = exerciseType;
    _repCount = 0;
    _previousFrameLuminance = null;
    _lastRepTime = DateTime.now();
    _motionState = 'idle';
    _motionHistory.clear();
    _hadPeak = false;
    _isDetecting = true;
    
    _controller!.startImageStream(_processCameraImage);
  }
  
  Future<void> stopDetection() async {
    _isDetecting = false;
    
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
    
    _previousFrameLuminance = null;
  }
  
  void _processCameraImage(CameraImage image) {
    if (!_isDetecting) return;
    
    _frameCounter++;
    if (_frameCounter < _frameSkip) return;
    _frameCounter = 0;
    
    final luminance = _extractLuminance(image);
    if (luminance == null) return;
    
    if (_previousFrameLuminance != null) {
      final motionLevel = _calculateMotionLevel(_previousFrameLuminance!, luminance);
      onMotionUpdate?.call(motionLevel);

      if (_isCalibrating) {
        _calibrationSamples.add(motionLevel);
      } else {
        _analyzeMotion(motionLevel);
      }
    }
    
    _previousFrameLuminance = luminance;
  }
  
  List<int>? _extractLuminance(CameraImage image) {
    try {
      final plane = image.planes[0];
      final bytes = plane.bytes;
      final width = image.width;
      final height = image.height;

      final sampleSize = 8;
      // 只采样中心 60% 区域
      final startX = (width * 0.2).toInt();
      final endX = (width * 0.8).toInt();
      final startY = (height * 0.2).toInt();
      final endY = (height * 0.8).toInt();

      final sampleWidth = (endX - startX) ~/ sampleSize;
      final sampleHeight = (endY - startY) ~/ sampleSize;
      final result = <int>[];

      for (int y = 0; y < sampleHeight; y++) {
        for (int x = 0; x < sampleWidth; x++) {
          final px = startX + x * sampleSize;
          final py = startY + y * sampleSize;
          final index = py * plane.bytesPerRow + px;
          if (index < bytes.length) {
            result.add(bytes[index]);
          }
        }
      }
      return result;
    } catch (e) {
      return null;
    }
  }
  
  double _calculateMotionLevel(List<int> prev, List<int> curr) {
    if (prev.length != curr.length || prev.isEmpty) return 0;
    
    int totalDiff = 0;
    for (int i = 0; i < prev.length; i++) {
      totalDiff += (curr[i] - prev[i]).abs();
    }
    
    return totalDiff / prev.length;
  }
  
  void _analyzeMotion(double motionLevel) {
    final now = DateTime.now();
    final debounceOK = now.difference(_lastRepTime).inMilliseconds > _debounceMs;

    // 将 motionLevel 加入滑动窗口历史
    _motionHistory.add(motionLevel);
    if (_motionHistory.length > _historySize) {
      _motionHistory.removeAt(0);
    }

    // 历史长度不足，返回
    if (_motionHistory.length < _historySize) return;

    // 滑动窗口中点
    final midIndex = _historySize ~/ 2;
    final midValue = _motionHistory[midIndex];

    // 检测峰值：中间值大于两侧邻居且超过阈值
    final isPeak = midValue > _motionHistory[midIndex - 1] &&
        midValue > _motionHistory[midIndex + 1] &&
        midValue > _motionThreshold;

    // 检测谷值：中间值小于阈值 * 0.5
    final isValley = midValue < _motionThreshold * 0.5;

    // 时长验证
    final timeSinceLast = now.difference(_lastRepTime).inMilliseconds;
    final durationOK = timeSinceLast >= _minRepMs && timeSinceLast <= _maxRepMs;

    switch (_currentExercise) {
      case 'running':
      case 'walking':
      case 'cycling':
        // 每个峰值算1步（使用滑动窗口平滑后的值）
        if (isPeak) {
          if (durationOK && debounceOK) {
            _repCount++;
            _lastRepTime = now;
            if (_repCount % 10 == 0) {
              onRepDetected?.call(_repCount, _getExerciseName());
              onFeedback?.call(_getFeedbackMessage());
            }
          } else {
            // 超出范围，重置峰值状态但不计数
            _lastRepTime = now;
          }
        }
        break;
      case 'pushup':
      case 'squat':
      case 'jumping_jack':
      case 'hiit':
      case 'jumprope':
      default:
        // 完整周期：峰值 -> 谷值 = 1次计数
        if (isPeak && !_hadPeak) {
          _hadPeak = true;
          _lastPeakTime = now;
        } else if (isValley && _hadPeak) {
          _hadPeak = false;
          _lastValleyTime = now;
          if (durationOK && debounceOK) {
            _repCount++;
            _lastRepTime = now;
            onRepDetected?.call(_repCount, _getExerciseName());
            onFeedback?.call(_getFeedbackMessage());
          } else {
            // 超出范围，重置峰值状态但不计数
            _lastRepTime = now;
          }
        }
        break;
    }

    if (motionLevel > _motionThreshold * 0.3 && motionLevel < _motionThreshold * 0.7) {
      onFeedback?.call('动作幅度再大一点！');
    }
  }
  
  String _getExerciseName() {
    switch (_currentExercise) {
      case 'pushup': return '俯卧撑';
      case 'squat': return '深蹲';
      case 'jumping_jack': return '开合跳';
      case 'running': return '跑步';
      case 'walking': return '快走';
      case 'cycling': return '骑行';
      case 'swimming': return '游泳';
      case 'yoga': return '瑜伽';
      case 'hiit': return 'HIIT';
      case 'jumprope': return '跳绳';
      case 'strength': return '力量训练';
      default: return '运动';
    }
  }
  
  String _getFeedbackMessage() {
    final messages = [
      '继续加油！',
      '做得很好！',
      '坚持住！',
      '燃烧吧！',
      '太棒了！',
      '再快一点！',
      '你可以的！',
    ];
    return '${_repCount}个！${messages[_repCount % messages.length]}';
  }
  
  void setSensitivity(double threshold) {
    _motionThreshold = threshold.clamp(5.0, 50.0);
  }

  Future<double> calibrate() async {
    _isCalibrating = true;
    _calibrationSamples.clear();
    onFeedback?.call('正在校准，请保持静止...');

    // 采集 2 秒的数据（_processCameraImage 中会自动收集）
    await Future.delayed(const Duration(seconds: 2));

    _isCalibrating = false;

    if (_calibrationSamples.isEmpty) {
      onFeedback?.call('校准失败，使用默认阈值');
      return _motionThreshold;
    }

    // 计算平均静息运动水平
    final avgRest = _calibrationSamples.reduce((a, b) => a + b) / _calibrationSamples.length;
    // 设置阈值为静息水平的 2.5 倍，但不低于 8.0
    _motionThreshold = (avgRest * 2.5).clamp(8.0, 50.0);

    onFeedback?.call('校准完成！阈值: ${_motionThreshold.toStringAsFixed(1)}');
    return _motionThreshold;
  }

  Future<void> dispose() async {
    await stopDetection();
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }
}