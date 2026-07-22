import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// 基于 Google ML Kit Pose Detection 的姿态识别服务
///
/// 使用 MoveNet 模型在端侧实时推理人体 33 个关键点，
/// 通过关键点角度/位置变化检测深蹲、俯卧撑、开合跳等动作。
///
/// 使用后置摄像头，用户需要侧身对着镜头做动作。
class PoseDetectionService {
  // ===== 摄像头相关 =====
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isDetecting = false;

  // ===== 姿态检测器 =====
  late final PoseDetector _poseDetector;
  bool _isBusy = false;

  // ===== 计数与状态 =====
  int _repCount = 0;
  String _currentExercise = '';
  String _motionState = 'up';
  DateTime _lastRepTime = DateTime.now();

  // ===== 帧率/节流控制 =====
  final int _frameSkip = 0;
  int _frameCounter = 0;
  final int _debounceMs = 500;

  // ===== 灵敏度（用户可调，0.0~1.0，1.0 = 最灵敏） =====
  double _sensitivity = 0.7;

  // ===== 关键点平滑（EMA 低通滤波 + 异常值过滤） =====
  // alpha 越小越平滑但延迟越高，0.4 是灵敏度和稳定性的平衡点
  static const double _emaAlpha = 0.4;
  final Map<PoseLandmarkType, Point3D> _smoothedLandmarks = {};
  final Map<PoseLandmarkType, Point3D> _velocity = {};
  static const double _maxJumpRatio = 0.15; // 单帧最大位移比例（防跳变）

  // ===== 运动强度 =====
  double _motionLevel = 0;

  // ===== Combo 连击系统 =====
  int _comboCount = 0;
  double _comboMultiplier = 1.0;
  static const int _comboWindowMs = 3000;
  static const int _comboStep = 5;
  static const double _comboStepMultiplier = 0.2;
  static const double _maxComboMultiplier = 2.0;
  DateTime _lastComboTime = DateTime.now();

  // ===== Stamina 体力系统 =====
  double _stamina = 100.0;
  static const double _staminaRecoverPerFrame = 0.8;
  static const double _staminaCostPerRep = 8.0;

  // ===== Pause 暂停系统 =====
  bool _isPaused = false;
  bool _lastFrameHadPerson = true;
  int _noPersonFrames = 0;
  int _personFrames = 0;
  static const int _pauseThreshold = 15;
  static const int _resumeThreshold = 5;

  // ===== Prepare 准备系统 =====
  bool _isPreparing = false;
  int _prepareFrames = 0;
  static const int _prepareTargetFrames = 60; // ~2秒 @ 30fps

  // ===== Adaptive FPS 自适应帧率 =====
  final List<int> _frameTimestamps = [];
  int _processingLevel = 2; // 2=完整, 1=轻量, 0=跳过
  double _currentFps = 30.0;
  int _adaptiveSkipCounter = 0;

  // ===== 回调 =====
  Function(int count, String exercise)? onRepDetected;
  Function(String feedback)? onFeedback;
  Function(double level)? onMotionUpdate;
  Function(Map<PoseLandmarkType, Point3D>? landmarks)? onPoseUpdate;

  // ===== 新增回调 =====
  Function(int combo, double multiplier)? onComboUpdate;
  Function(double stamina)? onStaminaUpdate;
  Function(int fps)? onFpsUpdate;
  Function(double quality, String grade)? onQualityScore;
  Function(bool paused)? onPauseChanged;
  Function(double progress)? onPrepareProgress;

  // ===== Getters =====
  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isDetecting => _isDetecting;
  int get repCount => _repCount;
  String get currentExercise => _currentExercise;
  double get sensitivity => _sensitivity;
  double get motionLevel => _motionLevel;

  // ===== 新增 Getters =====
  int get comboCount => _comboCount;
  double get comboMultiplier => _comboMultiplier;
  double get stamina => _stamina;
  bool get isPaused => _isPaused;
  bool get isPreparing => _isPreparing;
  double get currentFps => _currentFps;

  /// 初始化摄像头（使用前置摄像头，用户可以看到自己的姿态）
  Future<void> initialize() async {
    if (_isInitialized) return;

    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );

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
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  /// 开始检测指定运动
  Future<void> startDetection(String exerciseType) async {
    if (!_isInitialized || _controller == null) return;

    _currentExercise = exerciseType;
    _repCount = 0;
    _motionState = _isJumpingExercise(exerciseType) ? 'closed' : 'up';
    _smoothedLandmarks.clear();
    _velocity.clear();
    _lastRepTime = DateTime.now();
    _isDetecting = true;
    _isBusy = false;

    // 重置动作特定状态
    _squatHipMaxY = 0;
    _squatHipMinY = 999;
    _pushupShoulderMinY = 999;
    _pushupShoulderMaxY = 0;
    _jackNoseMinY = 999;
    _jackNoseMaxY = 0;
    _lastJackRhythm = 0;

    // 重置新运动状态
    _highKneeState = 'down';
    _plankAccumulatedSeconds = 0;
    _plankStartTime = null;
    _burpeePhase = 'stand';
    _lungeState = 'recovered';
    _mountainClimberState = 'left';

    // 重置系统状态
    _comboCount = 0;
    _comboMultiplier = 1.0;
    _lastComboTime = DateTime.now();
    _stamina = 100.0;
    _isPaused = false;
    _lastFrameHadPerson = true;
    _noPersonFrames = 0;
    _personFrames = 0;
    _adaptiveSkipCounter = 0;
    _frameTimestamps.clear();
    _currentFps = 30.0;
    _processingLevel = 2;

    // 启动准备倒计时
    _startPrepare();

    await _controller!.startImageStream(_processCameraImage);
  }

  bool _isJumpingExercise(String type) {
    return type == 'jumping_jack' || type == 'hiit' || type == 'jumprope';
  }

  /// 停止检测
  Future<void> stopDetection() async {
    _isDetecting = false;
    _isBusy = false;

    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
    _smoothedLandmarks.clear();
  }

  /// 处理每一帧摄像头图像
  void _processCameraImage(CameraImage image) {
    if (!_isDetecting || _isBusy) return;

    // 0. 更新 FPS 统计（每帧都统计以确保准确性）
    _updateFpsStats();

    // 1. 检查/更新暂停状态
    _updatePauseState(_lastFrameHadPerson);
    if (_isPaused) return;

    // 2. 恢复体力
    _recoverStamina();

    // 3. 更新准备状态
    if (_isPreparing) {
      _isPreparing = !_updatePrepareState(_lastFrameHadPerson);
    }

    // 4. 自适应跳帧
    if (_shouldSkipFrame()) return;

    // 5. 原有跳帧逻辑
    _frameCounter++;
    if (_frameCounter < _frameSkip) return;
    _frameCounter = 0;

    final inputImage = _toInputImage(image);
    if (inputImage == null) return;

    _isBusy = true;
    _runDetection(inputImage);
  }

  /// 将 CameraImage 转换为 ML Kit 可识别的 InputImage
  InputImage? _toInputImage(CameraImage image) {
    try {
      final camera = _controller!.description;
      final sensorOrientation = camera.sensorOrientation;
      final isFront = camera.lensDirection == CameraLensDirection.front;

      int rotationInt;
      if (Platform.isAndroid) {
        rotationInt = isFront
            ? (360 - sensorOrientation) % 360
            : sensorOrientation;
      } else {
        rotationInt = isFront ? sensorOrientation : sensorOrientation;
      }

      final rotation = InputImageRotationValue.fromRawValue(rotationInt) ??
          InputImageRotation.rotation0deg;

      final size = Size(image.width.toDouble(), image.height.toDouble());

      if (Platform.isIOS) {
        final plane = image.planes.first;
        return InputImage.fromBytes(
          bytes: plane.bytes,
          metadata: InputImageMetadata(
            size: size,
            rotation: rotation,
            format: InputImageFormat.bgra8888,
            bytesPerRow: plane.bytesPerRow,
          ),
        );
      }

      final nv21 = _yuv420ToNv21(image);
      return InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: size,
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    } catch (e) {
      debugPrint('PoseDetection: InputImage 转换失败: $e');
      return null;
    }
  }

  /// 将 Android CameraImage (YUV_420_888) 转换为 NV21 单缓冲格式
  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final ySize = width * height;
    final nv21 = Uint8List(ySize + ySize ~/ 2);

    // 1. 拷贝 Y 平面（处理行步长 padding）
    final yRowStride = yPlane.bytesPerRow;
    if (yRowStride == width) {
      nv21.setRange(0, ySize, yPlane.bytes);
    } else {
      for (int row = 0; row < height; row++) {
        final srcStart = row * yRowStride;
        final dstStart = row * width;
        nv21.setRange(dstStart, dstStart + width, yPlane.bytes, srcStart);
      }
    }

    // 2. 交错拷贝 V、U（NV21 = VU 对）
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    final halfHeight = height ~/ 2;
    final halfWidth = width ~/ 2;
    int uvIndex = ySize;

    for (int row = 0; row < halfHeight; row++) {
      for (int col = 0; col < halfWidth; col++) {
        final idx = row * uvRowStride + col * uvPixelStride;
        nv21[uvIndex++] = vPlane.bytes[idx];
        nv21[uvIndex++] = uPlane.bytes[idx];
      }
    }

    return nv21;
  }

  /// 执行姿态推理并分析
  Future<void> _runDetection(InputImage inputImage) async {
    try {
      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isEmpty) {
        _lastFrameHadPerson = false;
        onPoseUpdate?.call(null);
        _motionLevel = 0;
        onMotionUpdate?.call(0);
        onFeedback?.call('请将全身入镜');
        _isBusy = false;
        return;
      }

      _lastFrameHadPerson = true;

      final pose = poses.first;
      // EMA 平滑
      final smoothed = _applyEmaSmoothing(pose.landmarks);
      onPoseUpdate?.call(smoothed);

      // 准备阶段跳过动作分析，仅显示姿态
      if (!_isPreparing) {
        _analyzePose(smoothed);
      }
    } catch (e) {
      debugPrint('PoseDetection 推理失败: $e');
    } finally {
      _isBusy = false;
    }
  }

  /// 对关键点应用 EMA 平滑 + 异常值过滤，抑制抖动
  /// 前置摄像头需要镜像翻转 X 坐标
  Map<PoseLandmarkType, Point3D> _applyEmaSmoothing(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final result = <PoseLandmarkType, Point3D>{};
    final isFront = _controller!.description.lensDirection == CameraLensDirection.front;

    landmarks.forEach((type, lm) {
      var x = lm.x;
      if (isFront) {
        x = 1.0 - x;
      }
      final curr = Point3D(x, lm.y, lm.z);
      final prev = _smoothedLandmarks[type];

      if (prev == null) {
        _smoothedLandmarks[type] = curr;
        _velocity[type] = Point3D(0, 0, 0);
        result[type] = curr;
        return;
      }

      // 异常值检测：单帧位移过大说明检测跳变，用预测值替代
      final dx = curr.x - prev.x;
      final dy = curr.y - prev.y;
      final dist = math.sqrt(dx * dx + dy * dy);

      Point3D filtered;
      if (dist > _maxJumpRatio) {
        // 跳变过大，用前一帧 + 速度预测代替当前帧
        final vel = _velocity[type] ?? Point3D(0, 0, 0);
        filtered = Point3D(
          prev.x + vel.x * 0.5,
          prev.y + vel.y * 0.5,
          prev.z + vel.z * 0.5,
        );
      } else {
        // 正常范围，EMA 平滑
        filtered = Point3D(
          prev.x + (curr.x - prev.x) * _emaAlpha,
          prev.y + (curr.y - prev.y) * _emaAlpha,
          prev.z + (curr.z - prev.z) * _emaAlpha,
        );
      }

      // 更新速度估计
      _velocity[type] = Point3D(
        filtered.x - prev.x,
        filtered.y - prev.y,
        filtered.z - prev.z,
      );

      _smoothedLandmarks[type] = filtered;
      result[type] = filtered;
    });
    return result;
  }

  /// 根据当前运动类型分发分析逻辑
  void _analyzePose(Map<PoseLandmarkType, Point3D> lm) {
    switch (_currentExercise) {
      case 'squat':
        _analyzeSquat(lm);
        break;
      case 'pushup':
        _analyzePushup(lm);
        break;
      case 'jumping_jack':
        _analyzeJumpingJack(lm);
        break;
      case 'hiit':
      case 'jumprope':
        _analyzeJumpingJack(lm); // 跳跃类共用
        break;
      case 'highknee':
        _analyzeHighKnee(lm);
        break;
      case 'plank':
        _analyzePlank(lm);
        break;
      case 'burpee':
        _analyzeBurpee(lm);
        break;
      case 'lunge':
        _analyzeLunge(lm);
        break;
      case 'mountainclimber':
        _analyzeMountainClimber(lm);
        break;
      default:
        // 未实现姿态检测的运动，使用通用运动强度
        _analyzeGeneric(lm);
    }
  }

  // ============================================================
  // 深蹲：通过 hip-knee-ankle 角度 + 髋部高度变化双重验证
  // 站立 ≈ 170-180°；标准深蹲 ≈ 90-110°（大腿平行地面）
  // ============================================================
  double _squatHipMaxY = 0;
  double _squatHipMinY = 999;

  void _analyzeSquat(Map<PoseLandmarkType, Point3D> lm) {
    final hip = lm[PoseLandmarkType.leftHip];
    final knee = lm[PoseLandmarkType.leftKnee];
    final ankle = lm[PoseLandmarkType.leftAnkle];
    final hipR = lm[PoseLandmarkType.rightHip];
    final kneeR = lm[PoseLandmarkType.rightKnee];
    final ankleR = lm[PoseLandmarkType.rightAnkle];

    final leftOk = hip != null && knee != null && ankle != null;
    final rightOk = hipR != null && kneeR != null && ankleR != null;
    if (!leftOk && !rightOk) {
      onFeedback?.call('请确保全身入镜（侧身拍摄效果最佳）');
      return;
    }

    final angleL = leftOk ? _angle(hip, knee, ankle) : 180.0;
    final angleR = rightOk ? _angle(hipR, kneeR, ankleR) : 180.0;
    final angle = (angleL + angleR) / 2;

    // 髋部平均 Y 坐标，用于验证下蹲深度
    final hipY = ((hip?.y ?? 0) + (hipR?.y ?? 0)) / 2;
    if (angle > 170) {
      // 站立姿态，更新髋部最高位置参考
      _squatHipMaxY = hipY;
    }

    // 动态阈值：灵敏度越高，需要蹲得越深
    // 默认灵敏度0.7 → 下蹲阈值约110°，站立阈值约150°
    final downThreshold = 90.0 + (1.0 - _sensitivity) * 30.0;
    final upThreshold = downThreshold + 40.0;

    _updateMotionLevelByAngle(180.0 - angle, 90.0);

    String newState = _motionState;
    if (angle < downThreshold) {
      newState = 'down';
      // 记录最低位置
      if (hipY > _squatHipMinY) {
        _squatHipMinY = hipY;
      }
    } else if (angle > upThreshold) {
      newState = 'up';
    }

    if (_motionState == 'down' && newState == 'up' && _debounceOk()) {
      // 双重验证：髋部高度变化 > 站立高度的15%才算有效下蹲
      final hipDrop = _squatHipMaxY > 0
          ? (_squatHipMinY - _squatHipMaxY) / _squatHipMaxY
          : 0.0;
      final validDepth = hipDrop > 0.15;

      if (validDepth || angle < downThreshold + 10) {
        _repCount++;
        _lastRepTime = DateTime.now();
        onRepDetected?.call(_repCount, '深蹲');
        _emitSquatFeedback(angle, hipDrop);
      } else {
        onFeedback?.call('幅度不够哦，再蹲低一点~');
      }
      // 重置
      _squatHipMinY = 999;
    }
    _motionState = newState;
  }

  void _emitSquatFeedback(double angle, double depthRatio) {
    String msg;
    if (angle < 90 && depthRatio > 0.25) {
      msg = '🔥 $_repCount 个！标准深蹲，完美！';
    } else if (angle < 110) {
      msg = '💪 $_repCount 个！不错，继续保持~';
    } else if (angle < 130) {
      msg = '👍 $_repCount 个！可以再蹲深一点';
    } else {
      msg = '😅 $_repCount 个！幅度有点浅哦';
    }
    onFeedback?.call(msg);
  }

  // ============================================================
  // 俯卧撑：通过 shoulder-elbow-wrist 角度 + 身体直线度双重验证
  // 撑起 ≈ 170-180°；标准俯卧撑 ≈ 80-100°（胸部接近地面）
  // ============================================================
  double _pushupShoulderMinY = 999;
  double _pushupShoulderMaxY = 0;

  void _analyzePushup(Map<PoseLandmarkType, Point3D> lm) {
    final shoulder = lm[PoseLandmarkType.leftShoulder];
    final elbow = lm[PoseLandmarkType.leftElbow];
    final wrist = lm[PoseLandmarkType.leftWrist];
    final shoulderR = lm[PoseLandmarkType.rightShoulder];
    final elbowR = lm[PoseLandmarkType.rightElbow];
    final wristR = lm[PoseLandmarkType.rightWrist];
    final lHip = lm[PoseLandmarkType.leftHip];
    final lAnkle = lm[PoseLandmarkType.leftAnkle];

    final leftOk = shoulder != null && elbow != null && wrist != null;
    final rightOk = shoulderR != null && elbowR != null && wristR != null;
    if (!leftOk && !rightOk) {
      onFeedback?.call('请确保上半身入镜（侧身拍摄效果最佳）');
      return;
    }

    final angleL = leftOk ? _angle(shoulder, elbow, wrist) : 180.0;
    final angleR = rightOk ? _angle(shoulderR, elbowR, wristR) : 180.0;
    final angle = (angleL + angleR) / 2;

    // 肩膀 Y 坐标变化 = 身体上下移动幅度（图像Y向下）
    final shoulderY = ((shoulder?.y ?? 0) + (shoulderR?.y ?? 0)) / 2;
    if (angle > 160) {
      _pushupShoulderMaxY = shoulderY; // 撑起位置（较低Y=较高处）
    }

    // 身体直线度：肩-髋-踝的角度，判断腰是否塌了
    double bodyLineScore = 1.0;
    if (shoulder != null && lHip != null && lAnkle != null) {
      final bodyAngle = _angle(shoulder, lHip, lAnkle);
      bodyLineScore = (180 - bodyAngle) / 30; // 越接近180°越好
      bodyLineScore = bodyLineScore.clamp(0.0, 1.0);
    }

    // 动态阈值：灵敏度越高越容易计数
    // 默认灵敏度0.7 → 下蹲阈值约100°
    final downThreshold = 90.0 + (1.0 - _sensitivity) * 40.0;
    final upThreshold = downThreshold + 35.0;

    _updateMotionLevelByAngle(180.0 - angle, 100.0);

    String newState = _motionState;
    if (angle < downThreshold) {
      newState = 'down';
      if (shoulderY < _pushupShoulderMinY) {
        _pushupShoulderMinY = shoulderY;
      }
    } else if (angle > upThreshold) {
      newState = 'up';
    }

    if (_motionState == 'down' && newState == 'up' && _debounceOk()) {
      // 验证：肩膀有明显上下移动（> 肩部高度的10%）
      final dropRatio = _pushupShoulderMaxY > 0
          ? (_pushupShoulderMaxY - _pushupShoulderMinY) / _pushupShoulderMaxY
          : 0.0;

      if (dropRatio > 0.08 || angle < downThreshold + 10) {
        _repCount++;
        _lastRepTime = DateTime.now();
        onRepDetected?.call(_repCount, '俯卧撑');
        _emitPushupFeedback(angle, bodyLineScore);
      } else {
        onFeedback?.call('幅度不够，再往下压一点~');
      }
      _pushupShoulderMinY = 999;
    }
    _motionState = newState;
  }

  void _emitPushupFeedback(double angle, double bodyLine) {
    String msg;
    if (angle < 80 && bodyLine > 0.7) {
      msg = '🔥 $_repCount 个！标准动作，胸肌炸裂！';
    } else if (angle < 100) {
      msg = '💪 $_repCount 个！节奏不错，继续！';
    } else if (angle < 120) {
      msg = '👍 $_repCount 个！再下压一点效果更好';
    } else {
      msg = '😅 $_repCount 个！幅度有点浅哦';
    }
    if (bodyLine < 0.4) {
      msg += '（注意挺直腰）';
    }
    onFeedback?.call(msg);
  }

  // ============================================================
  // 开合跳：手腕高度 + 双脚宽度 + 身体重心变化三重验证
  // 状态：closed（手脚并拢） -> open（手脚张开，跳起） -> closed（落地并拢）
  // 一次完整 open->closed = 1 个
  // ============================================================
  double _jackNoseMinY = 999; // 跳起最高点（Y最小）
  double _jackNoseMaxY = 0; // 站立最低点（Y最大）
  double _lastJackRhythm = 0; // 上次开合跳时间

  void _analyzeJumpingJack(Map<PoseLandmarkType, Point3D> lm) {
    final lWrist = lm[PoseLandmarkType.leftWrist];
    final rWrist = lm[PoseLandmarkType.rightWrist];
    final lShoulder = lm[PoseLandmarkType.leftShoulder];
    final rShoulder = lm[PoseLandmarkType.rightShoulder];
    final nose = lm[PoseLandmarkType.nose];
    final lHip = lm[PoseLandmarkType.leftHip];
    final lAnkle = lm[PoseLandmarkType.leftAnkle];
    final rAnkle = lm[PoseLandmarkType.rightAnkle];

    if (lWrist == null ||
        rWrist == null ||
        lShoulder == null ||
        rShoulder == null) {
      onFeedback?.call('请确保全身入镜');
      return;
    }

    // 手举高判断：手腕超过肩膀一定比例（灵敏度越高越容易触发）
    final shoulderY = (lShoulder.y + rShoulder.y) / 2;
    final wristY = (lWrist.y + rWrist.y) / 2;
    final handUpRatio = (shoulderY - wristY) / (lHip != null ? (lHip.y - nose!.y).abs() : 100);
    final handsUp = wristY < shoulderY - (1.0 - _sensitivity) * 20;

    // 双脚开合判断：脚踝距离 > 髋部宽度 * 1.5 = 张开
    double feetSpread = 0;
    if (lAnkle != null && rAnkle != null && lHip != null) {
      final hipWidth = (lHip.x - lm[PoseLandmarkType.rightHip]!.x).abs();
      final feetWidth = (lAnkle.x - rAnkle.x).abs();
      feetSpread = hipWidth > 0 ? feetWidth / hipWidth : 1.0;
    }
    final feetApart = feetSpread > 1.3;

    // 跳跃检测：鼻子 Y 坐标变化（跳起时Y变小）
    double jumpHeight = 0;
    if (nose != null) {
      if (nose.y < _jackNoseMinY) _jackNoseMinY = nose.y;
      if (nose.y > _jackNoseMaxY) _jackNoseMaxY = nose.y;
      if (_jackNoseMaxY > _jackNoseMinY) {
        jumpHeight = (_jackNoseMaxY - _jackNoseMinY) / _jackNoseMaxY;
      }
    }

    // 综合判断：手张开 AND (脚张开 OR 有跳跃)
    final isOpen = handsUp && (feetApart || jumpHeight > 0.03);

    // 运动强度 = 手的高度 + 脚的张开程度
    final intensity = (handUpRatio * 0.5 + feetSpread * 0.3 + jumpHeight * 10 * 0.2)
        .clamp(0.0, 1.0);
    _updateMotionLevelByAngle(intensity, 1.0);

    final String newState = isOpen ? 'open' : 'closed';

    if (_motionState == 'open' && newState == 'closed' && _debounceOk()) {
      // 节奏稳定性判断
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_lastJackRhythm > 0) {
        final interval = now - _lastJackRhythm;
        // 正常开合跳节奏：0.5-2秒/个
        if (interval < 300) {
          // 太快了，可能是误检，跳过
          _motionState = newState;
          return;
        }
      }
      _lastJackRhythm = now.toDouble();

      _repCount++;
      _lastRepTime = DateTime.now();
      onRepDetected?.call(_repCount, '开合跳');
      _emitJackFeedback(jumpHeight, feetSpread);
      _jackNoseMinY = 999;
    }
    _motionState = newState;
  }

  void _emitJackFeedback(double jumpHeight, double feetSpread) {
    String msg;
    if (jumpHeight > 0.08 && feetSpread > 1.5) {
      msg = '🔥 $_repCount 个！标准开合跳，爆发十足！';
    } else if (jumpHeight > 0.04 || feetSpread > 1.3) {
      msg = '💪 $_repCount 个！节奏不错，继续！';
    } else {
      msg = '👍 $_repCount 个！再跳高一点效果更好';
    }
    onFeedback?.call(msg);
  }

  // ============================================================
  // 高抬腿：检测膝盖抬起高度比例（膝盖Y vs 髋部Y，用躯干长度归一化）
  // 状态机：down -> up -> down 为一次完整动作
  // 使用 LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE
  // ============================================================
  String _highKneeState = 'down';

  void _analyzeHighKnee(Map<PoseLandmarkType, Point3D> lm) {
    final lHip = lm[PoseLandmarkType.leftHip];
    final rHip = lm[PoseLandmarkType.rightHip];
    final lKnee = lm[PoseLandmarkType.leftKnee];
    final rKnee = lm[PoseLandmarkType.rightKnee];
    final lShoulder = lm[PoseLandmarkType.leftShoulder];
    final rShoulder = lm[PoseLandmarkType.rightShoulder];

    if (lHip == null || rHip == null || lKnee == null || rKnee == null) {
      onFeedback?.call('请确保下半身入镜（侧身拍摄效果最佳）');
      return;
    }

    // 计算膝盖高度比例：膝盖相对于髋部的高度，用躯干长度归一化
    final hipMidY = (lHip.y + rHip.y) / 2;
    final kneeMidY = (lKnee.y + rKnee.y) / 2;

    // 躯干长度 = 肩髋Y距离
    double torsoLength = 0.1; // 默认值防止除零
    if (lShoulder != null && rShoulder != null) {
      final shoulderMidY = (lShoulder.y + rShoulder.y) / 2;
      final t = (hipMidY - shoulderMidY).abs();
      if (t > 0.02) torsoLength = t;
    }
    // 注意：图像坐标Y向下，所以 hipMidY - kneeMidY > 0 表示膝盖高于髋部
    final kneeHeightRatio = (hipMidY - kneeMidY) / torsoLength;

    // 运动强度映射
    _updateMotionLevelByAngle(kneeHeightRatio * 5, 1.0);

    // 自适应阈值：灵敏度越高越容易触发
    final upThreshold = 0.2 * (1.0 - _sensitivity * 0.3);
    final downThreshold = 0.05 * (1.0 + (1.0 - _sensitivity) * 0.5);

    // 状态判断：膝盖抬高（上） vs 膝盖落下（下）
    String newState = _highKneeState;
    if (kneeHeightRatio > upThreshold) {
      newState = 'up';
    } else if (kneeHeightRatio < downThreshold) {
      newState = 'down';
    }

    // up -> down 过渡计一次
    if (_highKneeState == 'up' && newState == 'down' && _debounceOk()) {
      if (!_consumeStamina()) {
        onFeedback?.call('体力不足，休息一下吧~');
        _highKneeState = newState;
        return;
      }
      _repCount++;
      _lastRepTime = DateTime.now();
      onRepDetected?.call(_repCount, '高抬腿');
      _handleRepSuccess();
      _emitHighKneeFeedback(kneeHeightRatio);
      _calcQualityScore('highknee', (kneeHeightRatio / 0.3).clamp(0.0, 1.0),
          kneeHeightRatio > 0.2 ? 1.0 : kneeHeightRatio / 0.2, 0.8);
    }

    _highKneeState = newState;
  }

  void _emitHighKneeFeedback(double kneeRatio) {
    String msg;
    if (kneeRatio > 0.35) {
      msg = '🔥 $_repCount 个！膝盖抬得真高，完美！';
    } else if (kneeRatio > 0.25) {
      msg = '💪 $_repCount 个！节奏不错，继续保持~';
    } else if (kneeRatio > 0.2) {
      msg = '👍 $_repCount 个！可以再抬高一点';
    } else {
      msg = '😅 $_repCount 个！膝盖还不够高哦';
    }
    onFeedback?.call(msg);
  }

  // ============================================================
  // 平板支撑：检测肩-髋-踝直线度
  // isPlankForm (shoulderHipDiff < 0.08 && hipAnkleDiff > 0.1) 时累积时间
  // 使用 LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP, LEFT_ANKLE, RIGHT_ANKLE
  // ============================================================
  DateTime? _plankStartTime;
  double _plankAccumulatedSeconds = 0;

  void _analyzePlank(Map<PoseLandmarkType, Point3D> lm) {
    final lShoulder = lm[PoseLandmarkType.leftShoulder];
    final rShoulder = lm[PoseLandmarkType.rightShoulder];
    final lHip = lm[PoseLandmarkType.leftHip];
    final rHip = lm[PoseLandmarkType.rightHip];
    final lAnkle = lm[PoseLandmarkType.leftAnkle];
    final rAnkle = lm[PoseLandmarkType.rightAnkle];

    if (lShoulder == null || rShoulder == null || lHip == null || rHip == null) {
      onFeedback?.call('请确保全身入镜（侧身拍摄效果最佳）');
      _plankStartTime = null;
      return;
    }

    // 肩髋Y轴对齐度：平板支撑时肩和髋应在相近高度
    final shoulderMidY = (lShoulder.y + rShoulder.y) / 2;
    final hipMidY = (lHip.y + rHip.y) / 2;
    final shoulderHipDiff = (shoulderMidY - hipMidY).abs();

    // 髋踝Y轴距离：平板支撑时髋高于踝
    double hipAnkleDiff = 0;
    if (lAnkle != null && rAnkle != null) {
      final ankleMidY = (lAnkle.y + rAnkle.y) / 2;
      hipAnkleDiff = (hipMidY - ankleMidY).abs();
    }

    // 身体直线度评分（肩-髋-踝三点一线）
    double bodyLine = 0.0;
    if (lShoulder != null && lHip != null && lAnkle != null) {
      final bodyAngle = _angle(lShoulder, lHip, lAnkle);
      bodyLine = ((180.0 - (bodyAngle - 180.0).abs()) / 180.0).clamp(0.0, 1.0);
    }

    // 自适应阈值
    final shoulderHipThreshold = 0.08 * (1.0 + (1.0 - _sensitivity) * 0.5);
    final hipAnkleThreshold = 0.1 * (1.0 - (1.0 - _sensitivity) * 0.3);
    final isPlankForm = shoulderHipDiff < shoulderHipThreshold &&
        hipAnkleDiff > hipAnkleThreshold;

    // 运动强度
    _updateMotionLevelByAngle(isPlankForm ? 1.0 : 0.3, 1.0);

    final now = DateTime.now();
    if (isPlankForm) {
      if (_plankStartTime == null) {
        _plankStartTime = now;
      } else {
        _plankAccumulatedSeconds +=
            now.difference(_plankStartTime!).inMilliseconds / 1000.0;
        _plankStartTime = now;
      }
      // 每累计5秒提示一次
      if (_plankAccumulatedSeconds > 0 &&
          _plankAccumulatedSeconds.toInt() % 5 == 0 &&
          _debounceOk()) {
        _emitPlankFeedback(_plankAccumulatedSeconds);
        _calcQualityScore('plank', 0.9, 0.8, bodyLine);
      }
    } else {
      _plankStartTime = null;
      if (shoulderHipDiff >= shoulderHipThreshold) {
        onFeedback?.call('保持身体平直，挺直腰背');
      }
    }

    // 平板支撑不以次数计，而是累计时长
    _repCount = _plankAccumulatedSeconds.toInt();
  }

  void _emitPlankFeedback(double seconds) {
    if (seconds >= 60) {
      onFeedback?.call('🔥 核心力量惊人！已坚持 ${seconds.toInt()} 秒！');
    } else if (seconds >= 30) {
      onFeedback?.call('💪 很棒！已坚持 ${seconds.toInt()} 秒，继续加油！');
    } else {
      onFeedback?.call('👍 保持住！已坚持 ${seconds.toInt()} 秒');
    }
  }

  // ============================================================
  // 波比跳：4阶段状态机 stand -> squat -> plank -> jump -> stand
  // stand: avgKneeAngle > 160
  // squat: avgKneeAngle < 130
  // plank: shoulderHipDiff < 0.1
  // jump: 从 plank 回到 squat-like 状态
  // 计数: jump -> stand 过渡
  // 使用 8 个关键点：双肩、双髋、双膝、双踝
  // ============================================================
  String _burpeePhase = 'stand';

  void _analyzeBurpee(Map<PoseLandmarkType, Point3D> lm) {
    final lShoulder = lm[PoseLandmarkType.leftShoulder];
    final rShoulder = lm[PoseLandmarkType.rightShoulder];
    final lHip = lm[PoseLandmarkType.leftHip];
    final rHip = lm[PoseLandmarkType.rightHip];
    final lKnee = lm[PoseLandmarkType.leftKnee];
    final rKnee = lm[PoseLandmarkType.rightKnee];
    final lAnkle = lm[PoseLandmarkType.leftAnkle];
    final rAnkle = lm[PoseLandmarkType.rightAnkle];

    final shouldersOk = lShoulder != null && rShoulder != null;
    final hipsOk = lHip != null && rHip != null;
    final kneesOk = lKnee != null && rKnee != null;
    final anklesOk = lAnkle != null && rAnkle != null;

    if (!shouldersOk || !hipsOk || !kneesOk) {
      onFeedback?.call('请确保全身入镜（侧身拍摄效果最佳）');
      return;
    }

    // 平均膝盖角度
    final angleL = kneesOk ? _angle(lHip!, lKnee!, lAnkle!) : 180.0;
    final angleR = kneesOk ? _angle(rHip!, rKnee!, rAnkle!) : 180.0;
    final avgKneeAngle = (angleL + angleR) / 2;

    // 肩髋对齐度（判断是否在水平位置）
    final shoulderMidY = (lShoulder!.y + rShoulder!.y) / 2;
    final hipMidY = (lHip!.y + rHip!.y) / 2;
    final shoulderHipDiff = (shoulderMidY - hipMidY).abs();

    // 运动强度
    _updateMotionLevelByAngle(
        ((180.0 - avgKneeAngle) / 90.0).clamp(0.0, 1.0), 1.0);

    // 4阶段状态机
    final standThreshold = 160.0;
    final squatThreshold = 130.0;
    final plankThreshold = 0.1;

    switch (_burpeePhase) {
      case 'stand':
        if (avgKneeAngle < squatThreshold) {
          _burpeePhase = 'squat';
          onFeedback?.call('下蹲了！');
        }
        break;

      case 'squat':
        if (avgKneeAngle > standThreshold) {
          // 回到站立，重置
          _burpeePhase = 'stand';
        } else if (shoulderHipDiff < plankThreshold) {
          _burpeePhase = 'plank';
          onFeedback?.call('进入平板支撑！');
        }
        break;

      case 'plank':
        if (shoulderHipDiff > plankThreshold &&
            avgKneeAngle < squatThreshold) {
          // 从 plank 站起来到 squat 位置 = jump 阶段
          _burpeePhase = 'jump';
          onFeedback?.call('跳起来！');
        } else if (shoulderHipDiff > plankThreshold &&
            avgKneeAngle > standThreshold) {
          // 直接从 plank 站起，可能是检测不准，重置
          _burpeePhase = 'stand';
        }
        break;

      case 'jump':
        if (avgKneeAngle > standThreshold) {
          // 完成跳跃，计数
          if (_debounceOk()) {
            if (!_consumeStamina()) {
              onFeedback?.call('体力不足，休息一下吧~');
              _burpeePhase = 'stand';
              return;
            }
            _repCount++;
            _lastRepTime = DateTime.now();
            onRepDetected?.call(_repCount, '波比跳');
            _handleRepSuccess();
            _emitBurpeeFeedback(avgKneeAngle, shoulderHipDiff);
            _calcQualityScore('burpee',
                (avgKneeAngle > 170 ? 1.0 : (avgKneeAngle - 130) / 40),
                shoulderHipDiff < 0.06 ? 1.0 : (1.0 - shoulderHipDiff / 0.1),
                0.8);
          }
          _burpeePhase = 'stand';
        }
        break;
    }
  }

  void _emitBurpeeFeedback(double kneeAngle, double hipDiff) {
    String msg;
    if (kneeAngle > 170 && hipDiff < 0.06) {
      msg = '🔥 $_repCount 个！标准波比跳，燃脂之王！';
    } else if (kneeAngle > 160) {
      msg = '💪 $_repCount 个！节奏不错，继续燃烧！';
    } else {
      msg = '👍 $_repCount 个！动作幅度可以再大一点';
    }
    onFeedback?.call(msg);
  }

  // ============================================================
  // 弓步蹲：检测左右膝角度差异
  // lunge 条件：angleDiff > 30 AND minKneeAngle < 120
  // recovery 条件：maxKneeAngle > 160 AND angleDiff < 20
  // 使用 hips, knees, ankles
  // ============================================================
  String _lungeState = 'recovered';

  void _analyzeLunge(Map<PoseLandmarkType, Point3D> lm) {
    final lHip = lm[PoseLandmarkType.leftHip];
    final rHip = lm[PoseLandmarkType.rightHip];
    final lKnee = lm[PoseLandmarkType.leftKnee];
    final rKnee = lm[PoseLandmarkType.rightKnee];
    final lAnkle = lm[PoseLandmarkType.leftAnkle];
    final rAnkle = lm[PoseLandmarkType.rightAnkle];

    final leftOk = lHip != null && lKnee != null && lAnkle != null;
    final rightOk = rHip != null && rKnee != null && rAnkle != null;
    if (!leftOk || !rightOk) {
      onFeedback?.call('请确保全身入镜（侧身拍摄效果最佳）');
      return;
    }

    // 左右膝角度
    final angleL = _angle(lHip!, lKnee!, lAnkle!);
    final angleR = _angle(rHip!, rKnee!, rAnkle!);
    final angleDiff = (angleL - angleR).abs();
    final minKneeAngle = math.min(angleL, angleR);
    final maxKneeAngle = math.max(angleL, angleR);

    // 动态阈值：灵敏度越高越容易检测到弓步
    final diffThreshold = 30.0 * (1.0 - _sensitivity * 0.3);
    final minAngleThreshold = 120.0 * (1.0 + (1.0 - _sensitivity) * 0.2);
    final recoveryMaxAngle = 160.0 * (1.0 - (1.0 - _sensitivity) * 0.1);
    final recoveryDiffThreshold = 20.0 * (1.0 + (1.0 - _sensitivity) * 0.3);

    // 运动强度
    final depth = ((180.0 - minKneeAngle) / 90.0).clamp(0.0, 1.0);
    _updateMotionLevelByAngle(depth, 1.0);

    // 检测弓步
    final isLunging = angleDiff > diffThreshold && minKneeAngle < minAngleThreshold;
    final isRecovered = maxKneeAngle > recoveryMaxAngle && angleDiff < recoveryDiffThreshold;

    String newState = _lungeState;
    if (isLunging) {
      newState = 'lunging';
    } else if (isRecovered) {
      newState = 'recovered';
    }

    // lunging -> recovered 计一次
    if (_lungeState == 'lunging' && newState == 'recovered' && _debounceOk()) {
      if (!_consumeStamina()) {
        onFeedback?.call('体力不足，休息一下吧~');
        _lungeState = newState;
        return;
      }
      _repCount++;
      _lastRepTime = DateTime.now();
      onRepDetected?.call(_repCount, '弓步蹲');
      _handleRepSuccess();
      _emitLungeFeedback(angleDiff, minKneeAngle, maxKneeAngle);
      _calcQualityScore('lunge', (minKneeAngle < 90 ? 1.0 : (120 - minKneeAngle) / 30).clamp(0.0, 1.0),
          (angleDiff / 40).clamp(0.0, 1.0), 0.8);
    }

    _lungeState = newState;
  }

  void _emitLungeFeedback(double angleDiff, double minAngle, double maxAngle) {
    String msg;
    if (minAngle < 90 && angleDiff > 35) {
      msg = '🔥 $_repCount 个！标准弓步蹲，腿部力量炸裂！';
    } else if (minAngle < 110 && angleDiff > 25) {
      msg = '💪 $_repCount 个！不错，继续保持~';
    } else if (minAngle < 120) {
      msg = '👍 $_repCount 个！可以再蹲深一点';
    } else {
      msg = '😅 $_repCount 个！幅度有点浅哦';
    }
    onFeedback?.call(msg);
  }

  // ============================================================
  // 登山者：前提是平板支撑形态，检测膝盖 X 轴交替前进
  // leftKneeX > hipMidX + 0.03 -> 左膝在前
  // rightKneeX < hipMidX - 0.03 -> 右膝在前
  // 状态 left/right，left -> right 过渡计数一次
  // ============================================================
  String _mountainClimberState = 'left';

  void _analyzeMountainClimber(Map<PoseLandmarkType, Point3D> lm) {
    final lShoulder = lm[PoseLandmarkType.leftShoulder];
    final rShoulder = lm[PoseLandmarkType.rightShoulder];
    final lHip = lm[PoseLandmarkType.leftHip];
    final rHip = lm[PoseLandmarkType.rightHip];
    final lKnee = lm[PoseLandmarkType.leftKnee];
    final rKnee = lm[PoseLandmarkType.rightKnee];
    final lAnkle = lm[PoseLandmarkType.leftAnkle];
    final rAnkle = lm[PoseLandmarkType.rightAnkle];

    if (lShoulder == null || rShoulder == null || lHip == null || rHip == null ||
        lKnee == null || rKnee == null) {
      onFeedback?.call('请确保全身入镜（侧身拍摄效果最佳）');
      return;
    }

    // 平板支撑前提检查：身体是否保持水平直线
    final shoulderMidY = (lShoulder.y + rShoulder.y) / 2;
    final hipMidY = (lHip.y + rHip.y) / 2;
    final shoulderHipDiff = (shoulderMidY - hipMidY).abs();

    double hipAnkleDiff = 0;
    if (lAnkle != null && rAnkle != null) {
      final ankleMidY = (lAnkle.y + rAnkle.y) / 2;
      hipAnkleDiff = (hipMidY - ankleMidY).abs();
    }

    // 自适应平板形态阈值
    final shThreshold = 0.08 * (1.0 + (1.0 - _sensitivity) * 0.3);
    final haThreshold = 0.1 * (1.0 - (1.0 - _sensitivity) * 0.3);
    final inPlank = shoulderHipDiff < shThreshold && hipAnkleDiff > haThreshold;

    if (!inPlank) {
      onFeedback?.call('请保持平板支撑姿势');
      _updateMotionLevelByAngle(0.1, 1.0);
      return;
    }

    // 计算髋部中心 X 坐标
    final hipMidX = (lHip.x + rHip.x) / 2;

    // 自适应膝盖前移阈值
    final kneeForwardThreshold = 0.03 * (1.0 + (1.0 - _sensitivity) * 0.5);

    // 检测哪条腿在前面
    final leftForward = lKnee.x > hipMidX + kneeForwardThreshold;
    final rightForward = rKnee.x < hipMidX - kneeForwardThreshold;

    // 运动强度
    final motion = (leftForward || rightForward) ? 0.8 : 0.3;
    _updateMotionLevelByAngle(motion, 1.0);

    String newState = _mountainClimberState;
    if (leftForward && !rightForward) {
      newState = 'left';
    } else if (rightForward && !leftForward) {
      newState = 'right';
    }

    // left -> right 过渡计一次
    if (_mountainClimberState == 'left' && newState == 'right' && _debounceOk()) {
      if (!_consumeStamina()) {
        onFeedback?.call('体力不足，休息一下吧~');
        _mountainClimberState = newState;
        return;
      }
      _repCount++;
      _lastRepTime = DateTime.now();
      onRepDetected?.call(_repCount, '登山者');
      _handleRepSuccess();
      _emitMountainClimberFeedback(leftForward, rightForward);
      _calcQualityScore('mountainclimber', inPlank ? 0.9 : 0.5, 0.8, 0.7);
    }

    _mountainClimberState = newState;
  }

  void _emitMountainClimberFeedback(bool leftFwd, bool rightFwd) {
    String msg;
    if ((leftFwd || rightFwd)) {
      msg = '💪 $_repCount 次！节奏真好，继续保持~';
    } else {
      msg = '👍 $_repCount 次！加快速度效果更好';
    }
    onFeedback?.call(msg);
  }

  // 通用运动强度估算（用于不支持关键点检测的运动类型）
  void _analyzeGeneric(Map<PoseLandmarkType, Point3D> lm) {
    // 计算四肢运动幅度
    final points = [
      lm[PoseLandmarkType.leftWrist],
      lm[PoseLandmarkType.rightWrist],
      lm[PoseLandmarkType.leftAnkle],
      lm[PoseLandmarkType.rightAnkle],
    ].whereType<Point3D>().toList();
    if (points.isEmpty) return;

    final avgY = points.map((p) => p.y).reduce((a, b) => a + b) / points.length;
    _updateMotionLevelByAngle(avgY / 100, 1.0);
  }

  // ============================================================
  // 工具方法
  // ============================================================

  /// 计算三个点形成的角度（顶点位于 b）
  /// 返回角度（0~180°）
  double _angle(Point3D a, Point3D b, Point3D c) {
    final v1x = a.x - b.x;
    final v1y = a.y - b.y;
    final v2x = c.x - b.x;
    final v2y = c.y - b.y;
    final dot = v1x * v2x + v1y * v2y;
    final mag1 = math.sqrt(v1x * v1x + v1y * v1y);
    final mag2 = math.sqrt(v2x * v2x + v2y * v2y);
    if (mag1 < 1e-6 || mag2 < 1e-6) return 180.0;
    var cosVal = dot / (mag1 * mag2);
    cosVal = cosVal.clamp(-1.0, 1.0);
    return math.acos(cosVal) * 180 / math.pi;
  }

  bool _debounceOk() {
    return DateTime.now().difference(_lastRepTime).inMilliseconds > _debounceMs;
  }

  /// 将一个原始运动量值映射为 [0,1] 强度并回调
  void _updateMotionLevelByAngle(double raw, double max) {
    final level = (raw / max).clamp(0.0, 1.0);
    _motionLevel = level;
    onMotionUpdate?.call(level);
  }

  // ============================================================
  // Combo 连击系统
  // 3 秒窗口内连续完成动作，每 5 连击 +0.2x 倍率，最大 2.0x
  // ============================================================

  /// 每次完成一个有效动作时调用，更新连击状态
  /// 返回 true 表示连击更新成功
  bool _handleRepSuccess() {
    final now = DateTime.now();
    final msSinceLastCombo = now.difference(_lastComboTime).inMilliseconds;

    if (msSinceLastCombo < _comboWindowMs) {
      // 在 3 秒窗口内，连击继续
      _comboCount++;
    } else {
      // 窗口外，重置连击
      _comboCount = 1;
      _comboMultiplier = 1.0;
    }

    _lastComboTime = now;

    // 每 5 连击增加 0.2x 倍率
    if (_comboCount > 1 && _comboCount % _comboStep == 0) {
      _comboMultiplier = (1.0 + (_comboCount ~/ _comboStep) * _comboStepMultiplier)
          .clamp(1.0, _maxComboMultiplier);
    }

    onComboUpdate?.call(_comboCount, _comboMultiplier);
    return true;
  }

  // ============================================================
  // Stamina 体力系统
  // 每帧恢复 0.8，每次动作消耗 8
  // ============================================================

  /// 每帧体力恢复
  void _recoverStamina() {
    _stamina = (_stamina + _staminaRecoverPerFrame).clamp(0.0, 100.0);
    onStaminaUpdate?.call(_stamina);
  }

  /// 消耗体力，返回 true 表示体力充足，false 表示体力不足
  bool _consumeStamina() {
    if (_stamina < _staminaCostPerRep) {
      onStaminaUpdate?.call(_stamina);
      return false;
    }
    _stamina -= _staminaCostPerRep;
    onStaminaUpdate?.call(_stamina);
    return true;
  }

  // ============================================================
  // Pause 暂停系统
  // 15 帧无人 -> 暂停，5 帧有人 -> 恢复
  // ============================================================

  /// 更新暂停状态
  void _updatePauseState(bool hasPerson) {
    if (hasPerson) {
      _personFrames++;
      _noPersonFrames = 0;

      // 恢复条件：连续 5 帧有人
      if (_isPaused && _personFrames >= _resumeThreshold) {
        _isPaused = false;
        _personFrames = 0;
        onPauseChanged?.call(false);
        onFeedback?.call('检测到用户，继续运动！');
      }
    } else {
      _noPersonFrames++;
      _personFrames = 0;

      // 暂停条件：连续 15 帧无人
      if (!_isPaused && _noPersonFrames >= _pauseThreshold) {
        _isPaused = true;
        _noPersonFrames = 0;
        onPauseChanged?.call(true);
        onFeedback?.call('未检测到人体，运动已暂停');
      }
    }
  }

  // ============================================================
  // Prepare 准备系统
  // 2 秒倒计时后正式开始计时
  // ============================================================

  /// 启动准备倒计时
  void _startPrepare() {
    _isPreparing = true;
    _prepareFrames = 0;
  }

  /// 更新准备状态，返回 true 表示准备完成
  /// hasPerson: 当前帧是否检测到人体
  bool _updatePrepareState(bool hasPerson) {
    if (!hasPerson) {
      // 无人时暂停倒计时但不重置
      onPrepareProgress?.call((_prepareFrames / _prepareTargetFrames).clamp(0.0, 1.0));
      return false;
    }

    _prepareFrames++;
    final progress = (_prepareFrames / _prepareTargetFrames).clamp(0.0, 1.0);
    onPrepareProgress?.call(progress);

    if (_prepareFrames >= _prepareTargetFrames) {
      _isPreparing = false;
      onFeedback?.call('准备完成，开始运动！');
      return true;
    }
    return false;
  }

  // ============================================================
  // Adaptive FPS 自适应帧率
  // FPS < 15 降级处理，FPS > 25 恢复全量处理
  // ============================================================

  /// 更新 FPS 统计
  void _updateFpsStats() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _frameTimestamps.add(now);

    // 保留最近 30 帧时间戳
    while (_frameTimestamps.length > 30) {
      _frameTimestamps.removeAt(0);
    }

    if (_frameTimestamps.length >= 2) {
      final duration = _frameTimestamps.last - _frameTimestamps.first;
      if (duration > 0) {
        _currentFps =
            (_frameTimestamps.length - 1) / (duration / 1000.0);
      }
    }

    // 根据帧率调整处理级别
    if (_currentFps < 15.0) {
      // 帧率过低，降级处理
      if (_processingLevel > 0) _processingLevel--;
    } else if (_currentFps > 25.0) {
      // 帧率恢复，升级处理
      if (_processingLevel < 2) _processingLevel++;
    }

    onFpsUpdate?.call(_currentFps.round());
  }

  /// 判断当前帧是否应跳过处理
  bool _shouldSkipFrame() {
    if (_processingLevel >= 2) return false;
    if (_processingLevel == 0) return true;
    // 级别 1：隔帧处理
    _adaptiveSkipCounter++;
    return _adaptiveSkipCounter % 2 == 1;
  }

  // ============================================================
  // Quality 质量评分系统
  // 综合角度偏差、深度比例、身体直线度评分 0-100
  // 等级：S(>90), A(>75), B(>60), C(>45), D(<=45)
  // ============================================================

  /// 计算动作质量评分
  /// angle: 角度规范度 0-1（1=最标准）
  /// depth: 动作深度 0-1（1=最到位）
  /// bodyLine: 身体直线度 0-1（1=最直）
  double _calcQualityScore(
      String exercise, double angle, double depth, double bodyLine) {
    // 加权计算：角度占 40%，深度占 30%，身体线占 30%
    double score = (angle * 40 + depth * 30 + bodyLine * 30);
    score = score.clamp(0.0, 100.0);

    String grade;
    if (score > 90) {
      grade = 'S';
    } else if (score > 75) {
      grade = 'A';
    } else if (score > 60) {
      grade = 'B';
    } else if (score > 45) {
      grade = 'C';
    } else {
      grade = 'D';
    }

    onQualityScore?.call(score, grade);
    return score;
  }

  // ============================================================
  // 公共控制方法
  // ============================================================

  /// 设置灵敏度（0.0 ~ 1.0，1.0 = 最灵敏）
  void setSensitivity(double value) {
    _sensitivity = value.clamp(0.0, 1.0);
  }

  /// 重置计数（不停止检测）
  void resetCount() {
    _repCount = 0;
    _motionState = _isJumpingExercise(_currentExercise) ? 'closed' : 'up';
    _lastRepTime = DateTime.now();
    _squatHipMaxY = 0;
    _squatHipMinY = 999;
    _pushupShoulderMinY = 999;
    _pushupShoulderMaxY = 0;
    _jackNoseMinY = 999;
    _jackNoseMaxY = 0;
    _lastJackRhythm = 0;

    // 重置新运动状态
    _highKneeState = 'down';
    _plankAccumulatedSeconds = 0;
    _plankStartTime = null;
    _burpeePhase = 'stand';
    _lungeState = 'recovered';
    _mountainClimberState = 'left';

    // 重置连击
    _comboCount = 0;
    _comboMultiplier = 1.0;
    _lastComboTime = DateTime.now();
  }

  /// 释放资源
  Future<void> dispose() async {
    await stopDetection();
    await _poseDetector.close();
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }
}

/// 简化的三维点（用于平滑后的关键点缓存）
class Point3D {
  final double x;
  final double y;
  final double z;
  const Point3D(this.x, this.y, this.z);
}
