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

  // ===== 关键点平滑（EMA 低通滤波） =====
  static const double _emaAlpha = 0.5;
  final Map<PoseLandmarkType, Point3D> _smoothedLandmarks = {};

  // ===== 运动强度 =====
  double _motionLevel = 0;
  DateTime _lastFrameTime = DateTime.now();

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
    _motionState = 'up';
    _smoothedLandmarks.clear();
    _lastRepTime = DateTime.now();
    _isDetecting = true;
    _isBusy = false;

    await _controller!.startImageStream(_processCameraImage);
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
      _lastFrameTime = DateTime.now();
      _isBusy = false;
    }
  }

  /// 对关键点应用 EMA 平滑，抑制抖动
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
      final smoothed = prev == null
          ? curr
          : Point3D(
              prev.x + (curr.x - prev.x) * _emaAlpha,
              prev.y + (curr.y - prev.y) * _emaAlpha,
              prev.z + (curr.z - prev.z) * _emaAlpha,
            );
      _smoothedLandmarks[type] = smoothed;
      result[type] = smoothed;
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
  // 深蹲：通过 hip-knee-ankle 角度判断
  // 站立 ≈ 170-180°；蹲下 ≈ 90-110°
  // ============================================================
  void _analyzeSquat(Map<PoseLandmarkType, Point3D> lm) {
    final hip = lm[PoseLandmarkType.leftHip];
    final knee = lm[PoseLandmarkType.leftKnee];
    final ankle = lm[PoseLandmarkType.leftAnkle];
    final hipR = lm[PoseLandmarkType.rightHip];
    final kneeR = lm[PoseLandmarkType.rightKnee];
    final ankleR = lm[PoseLandmarkType.rightAnkle];

    // 取左右腿中较可信的一侧
    final leftOk = hip != null && knee != null && ankle != null;
    final rightOk = hipR != null && kneeR != null && ankleR != null;
    if (!leftOk && !rightOk) {
      onFeedback?.call('请确保全身入镜（侧身拍摄效果最佳）');
      return;
    }

    final angleL = leftOk ? _angle(hip, knee, ankle) : 180.0;
    final angleR = rightOk ? _angle(hipR, kneeR, ankleR) : 180.0;
    final angle = (angleL + angleR) / 2;

    final downThreshold = 100.0 + _sensitivity * 50.0;
    final upThreshold = downThreshold + 30.0;

    _updateMotionLevelByAngle(180.0 - angle, 90.0);

    String newState = _motionState;
    if (angle < downThreshold) {
      newState = 'down';
    } else if (angle > upThreshold) {
      newState = 'up';
    }

    if (_motionState == 'down' && newState == 'up' && _debounceOk()) {
      _repCount++;
      _lastRepTime = DateTime.now();
      onRepDetected?.call(_repCount, '深蹲');
      _emitSquatFeedback(angle);
    }
    _motionState = newState;
  }

  void _emitSquatFeedback(double angle) {
    String msg;
    if (angle < 80) {
      msg = '$_repCount 个！蹲得够深，完美！';
    } else if (angle < 110) {
      msg = '$_repCount 个！标准深蹲，继续~';
    } else {
      msg = '$_repCount 个！可以再蹲低一点哦';
    }
    onFeedback?.call(msg);
  }

  // ============================================================
  // 俯卧撑：通过 shoulder-elbow-wrist 角度判断
  // 撑起 ≈ 170-180°；趴下 ≈ 70-90°
  // ============================================================
  void _analyzePushup(Map<PoseLandmarkType, Point3D> lm) {
    final shoulder = lm[PoseLandmarkType.leftShoulder];
    final elbow = lm[PoseLandmarkType.leftElbow];
    final wrist = lm[PoseLandmarkType.leftWrist];
    final shoulderR = lm[PoseLandmarkType.rightShoulder];
    final elbowR = lm[PoseLandmarkType.rightElbow];
    final wristR = lm[PoseLandmarkType.rightWrist];

    final leftOk = shoulder != null && elbow != null && wrist != null;
    final rightOk = shoulderR != null && elbowR != null && wristR != null;
    if (!leftOk && !rightOk) {
      onFeedback?.call('请确保上半身入镜（侧身拍摄效果最佳）');
      return;
    }

    final angleL = leftOk ? _angle(shoulder, elbow, wrist) : 180.0;
    final angleR = rightOk ? _angle(shoulderR, elbowR, wristR) : 180.0;
    final angle = (angleL + angleR) / 2;

    final downThreshold = 80.0 + _sensitivity * 50.0;
    final upThreshold = downThreshold + 30.0;

    _updateMotionLevelByAngle(180.0 - angle, 100.0);

    String newState = _motionState;
    if (angle < downThreshold) {
      newState = 'down';
    } else if (angle > upThreshold) {
      newState = 'up';
    }

    if (_motionState == 'down' && newState == 'up' && _debounceOk()) {
      _repCount++;
      _lastRepTime = DateTime.now();
      onRepDetected?.call(_repCount, '俯卧撑');
      _emitPushupFeedback(angle);
    }
    _motionState = newState;
  }

  void _emitPushupFeedback(double angle) {
    String msg;
    if (angle < 60) {
      msg = '$_repCount 个！下压到位，胸肌炸裂！';
    } else if (angle < 90) {
      msg = '$_repCount 个！标准俯卧撑，节奏不错';
    } else {
      msg = '$_repCount 个！下压再低一点效果更好';
    }
    onFeedback?.call(msg);
  }

  // ============================================================
  // 开合跳：通过手腕位置（高于肩膀=张开）+ 身体高度变化（跳跃）
  // 状态：closed（手放下） -> open（手举高，跳起） -> closed（落地）
  // 一次"open->closed"完成 = 1 个
  // ============================================================
  void _analyzeJumpingJack(Map<PoseLandmarkType, Point3D> lm) {
    final lWrist = lm[PoseLandmarkType.leftWrist];
    final rWrist = lm[PoseLandmarkType.rightWrist];
    final lShoulder = lm[PoseLandmarkType.leftShoulder];
    final rShoulder = lm[PoseLandmarkType.rightShoulder];
    final nose = lm[PoseLandmarkType.nose];
    final lHip = lm[PoseLandmarkType.leftHip];

    if (lWrist == null ||
        rWrist == null ||
        lShoulder == null ||
        rShoulder == null) {
      onFeedback?.call('请确保全身入镜');
      return;
    }

    // 手腕 Y 小于肩膀 Y（图像坐标系 Y 向下）= 手举过头
    final handsUp = lWrist.y < lShoulder.y && rWrist.y < rShoulder.y;

    // 身体高度（鼻到髋）变化，估算跳跃幅度
    double jumpFactor = 0;
    if (nose != null && lHip != null) {
      final bodyHeight = (lHip.y - nose.y).abs();
      jumpFactor = bodyHeight > 0 ? (1.0 / bodyHeight) * 100 : 0;
    }

    _updateMotionLevelByAngle(handsUp ? 1.0 : 0.3, 1.0);

    String newState = handsUp ? 'open' : 'closed';

    if (_motionState == 'open' && newState == 'closed' && _debounceOk()) {
      _repCount++;
      _lastRepTime = DateTime.now();
      onRepDetected?.call(_repCount, '开合跳');
      final msg = jumpFactor > 0.5
          ? '$_repCount 个！跳得高，节奏棒！'
          : '$_repCount 个！手脚配合，继续保持~';
      onFeedback?.call(msg);
    }
    _motionState = newState;
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

  /// 估算瞬时 FPS 并据此更新运动强度
  void _updateMotionLevel(double inferred) {
    final now = DateTime.now();
    final delta = now.difference(_lastFrameTime).inMilliseconds;
    _lastFrameTime = now;
    if (delta > 0) {
      final fps = 1000 / delta;
      // FPS 越低说明推理越吃力，间接反映处理压力；这里仅作强度提示
      final level = (fps / 30.0).clamp(0.0, 1.0) * inferred;
      _motionLevel = level;
      onMotionUpdate?.call(level);
    }
  }

  /// 设置灵敏度（0.0 ~ 1.0，1.0 = 最灵敏）
  void setSensitivity(double value) {
    _sensitivity = value.clamp(0.0, 1.0);
  }

  /// 重置计数（不停止检测）
  void resetCount() {
    _repCount = 0;
    _motionState = 'up';
    _lastRepTime = DateTime.now();
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
