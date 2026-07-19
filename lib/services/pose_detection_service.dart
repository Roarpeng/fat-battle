import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
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

  // ===== 回调 =====
  Function(int count, String exercise)? onRepDetected;
  Function(String feedback)? onFeedback;
  Function(double level)? onMotionUpdate;
  Function(Map<PoseLandmarkType, Point3D>? landmarks)? onPoseUpdate;

  // ===== Getters =====
  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isDetecting => _isDetecting;
  int get repCount => _repCount;
  String get currentExercise => _currentExercise;
  double get sensitivity => _sensitivity;
  double get motionLevel => _motionLevel;

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
        onPoseUpdate?.call(null);
        _motionLevel = 0;
        onMotionUpdate?.call(0);
        onFeedback?.call('请将全身入镜');
        _isBusy = false;
        return;
      }

      final pose = poses.first;
      // EMA 平滑
      final smoothed = _applyEmaSmoothing(pose.landmarks);
      onPoseUpdate?.call(smoothed);

      _analyzePose(smoothed);
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
