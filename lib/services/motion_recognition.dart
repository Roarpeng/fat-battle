import 'dart:async';
import 'dart:math' as math;
import '../models/game_models.dart';
import '../constants/app_constants.dart';

/// 动作识别服务 - 融合摄像头和IMU数据
class MotionRecognitionService {
  // IMU数据缓冲区
  final List<ImuData> _imuBuffer = [];
  final int _bufferSize = 100; // 保存最近100个采样点
  
  // 动作检测状态
  String _currentExercise = '';
  int _repCount = 0;
  String _lastState = 'up';
  bool _isDetecting = false;
  
  // 检测阈值
  final double _accelThreshold = 2.0; // 加速度变化阈值
  final double _gyroThreshold = 100; // 角速度变化阈值
  
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
    _lastState = 'up';
    _isDetecting = true;
    _imuBuffer.clear();
  }
  
  /// 停止检测
  void stopDetection() {
    _isDetecting = false;
    _currentExercise = '';
  }
  
  /// 分析运动
  void _analyzeMotion(ImuData data) {
    switch (_currentExercise) {
      case 'pushup':
        _detectPushup(data);
        break;
      case 'squat':
        _detectSquat(data);
        break;
      case 'jumping_jack':
        _detectJumpingJack(data);
        break;
      case 'running':
        _detectRunning(data);
        break;
      case 'walking':
        _detectWalking(data);
        break;
    }
  }
  
  /// 检测俯卧撑
  /// 腰部IMU检测：身体上下运动，加速度Z轴变化明显
  void _detectPushup(ImuData data) {
    // 俯卧撑时，腰部会有明显的上下运动
    // Z轴加速度会周期性变化
    
    final accelZ = data.az;
    
    // 判断状态：低位置（下）vs 高位置（上）
    String newState = _lastState;
    
    if (accelZ < -1.5) {
      newState = 'down';
    } else if (accelZ > 0.5) {
      newState = 'up';
    }
    
    // 检测完成一次：从下到上
    if (_lastState == 'down' && newState == 'up') {
      _repCount++;
      onRepDetected?.call(_repCount, '俯卧撑');
      onFeedback?.call('${_repCount}个！继续保持~');
    }
    
    _lastState = newState;
    
    // 提供反馈
    if (accelZ.abs() < 0.3 && _lastState == 'up') {
      onFeedback?.call('身体再低一点，效果更好~');
    }
  }
  
  /// 检测深蹲
  /// 腰部IMU检测：身体上下运动，加速度Y轴（垂直方向）变化明显
  void _detectSquat(ImuData data) {
    // 深蹲时，腰部会有明显的上下运动
    // Y轴加速度（垂直方向）会周期性变化
    
    final accelY = data.ay;
    final gyroX = data.gx.abs(); // 膝盖弯曲时会有旋转
    
    String newState = _lastState;
    
    // 判断状态：蹲下（低）vs 站立（高）
    if (accelY < -0.5 || gyroX > 50) {
      newState = 'down';
    } else if (accelY > 0.8) {
      newState = 'up';
    }
    
    // 检测完成一次：从蹲下到站立
    if (_lastState == 'down' && newState == 'up') {
      _repCount++;
      onRepDetected?.call(_repCount, '深蹲');
      onFeedback?.call('${_repCount}个！大腿肌肉在燃烧~');
    }
    
    _lastState = newState;
    
    // 提供反馈
    if (gyroX > 80 && gyroX < 100) {
      onFeedback?.call('膝盖不要超过脚尖~');
    }
  }
  
  /// 检测开合跳
  /// 腰部IMU检测：身体上下跳动，加速度变化剧烈
  void _detectJumpingJack(ImuData data) {
    // 开合跳时，腰部会有明显的上下跳动
    // 加速度幅值会有周期性峰值
    
    final accelMag = data.accelMagnitude;
    final gyroMag = data.gyroMagnitude;
    
    String newState = _lastState;
    
    // 判断状态：跳起（高加速度）vs 落地（低加速度）
    if (accelMag > 2.5) {
      newState = 'jump';
    } else if (accelMag < 1.2) {
      newState = 'land';
    }
    
    // 检测完成一次：从跳起到落地
    if (_lastState == 'jump' && newState == 'land') {
      _repCount++;
      onRepDetected?.call(_repCount, '开合跳');
      onFeedback?.call('${_repCount}个！心跳加速~');
    }
    
    _lastState = newState;
  }
  
  /// 检测跑步
  /// 腰部IMU检测：周期性的上下运动，频率较高
  void _detectRunning(ImuData data) {
    // 跑步时，腰部会有周期性的上下运动
    // 通过检测加速度峰值来计算步数
    
    final accelMag = data.accelMagnitude;
    
    // 检测峰值（每一步）
    if (accelMag > 2.0 && _lastState != 'peak') {
      _repCount++;
      _lastState = 'peak';
      
      if (_repCount % 10 == 0) {
        onRepDetected?.call(_repCount, '跑步');
        onFeedback?.call('${_repCount}步！继续跑~');
      }
    } else if (accelMag < 1.5) {
      _lastState = 'low';
    }
  }
  
  /// 检测快走
  void _detectWalking(ImuData data) {
    final accelMag = data.accelMagnitude;
    
    // 快走时加速度变化较小
    if (accelMag > 1.5 && _lastState != 'peak') {
      _repCount++;
      _lastState = 'peak';
      
      if (_repCount % 20 == 0) {
        onRepDetected?.call(_repCount, '快走');
        onFeedback?.call('${_repCount}步！');
      }
    } else if (accelMag < 1.2) {
      _lastState = 'low';
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
  }
}

/// 摄像头+IMU融合识别
class FusionRecognitionService {
  final MotionRecognitionService _imuService = MotionRecognitionService();
  
  // 摄像头检测结果（来自MediaPipe）
  String? _cameraExerciseType;
  int? _cameraRepCount;
  double? _cameraAccuracy;
  
  // 融合结果
  int _finalRepCount = 0;
  double _finalAccuracy = 0;
  
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
  
  /// 融合摄像头和IMU结果
  void _fuseResults() {
    // 如果只有摄像头结果
    if (_cameraRepCount != null && _imuService.repCount == 0) {
      _finalRepCount = _cameraRepCount!;
      _finalAccuracy = _cameraAccuracy ?? 0.8;
      return;
    }
    
    // 如果只有IMU结果
    if (_imuService.repCount > 0 && _cameraRepCount == null) {
      _finalRepCount = _imuService.repCount;
      _finalAccuracy = 0.7; // IMU单独检测精度较低
      return;
    }
    
    // 融合两者结果
    if (_cameraRepCount != null && _imuService.repCount > 0) {
      // 取两者平均值，摄像头权重更高
      _finalRepCount = ((_cameraRepCount! * 0.6) + (_imuService.repCount * 0.4)).round();
      
      // 融合精度：摄像头精度 + IMU强度验证
      final imuIntensity = _imuService.calculateIntensity();
      final intensityBonus = imuIntensity > 1.0 ? 0.1 : 0;
      _finalAccuracy = (_cameraAccuracy ?? 0.8) + intensityBonus;
      _finalAccuracy = _finalAccuracy.clamp(0, 1);
    }
  }
  
  /// 获取融合后的计数
  int get finalRepCount => _finalRepCount;
  
  /// 获取融合后的精度
  double get finalAccuracy => _finalAccuracy;
  
  /// 开始检测
  void startDetection(String exerciseType) {
    _imuService.startDetection(exerciseType);
    _cameraExerciseType = exerciseType;
    _cameraRepCount = null;
    _finalRepCount = 0;
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