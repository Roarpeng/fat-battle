import 'dart:async';
import 'dart:io' show File, Platform;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'pose_coach_diary.dart';
import 'exercise_fsm.dart';
import 'camera_move_fsm.dart';

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
  DateTime? _lastMlkitDiaryAt;
  bool _loggedFrameMeta = false;

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
  static const double _emaAlpha = 0.45;
  final Map<PoseLandmarkType, Point3D> _smoothedLandmarks = {};
  final Map<PoseLandmarkType, Point3D> _velocity = {};
  // 放宽跳变阈值：错误初始帧 + 过严阈值会把肩点「粘死」在边缘
  static const double _maxJumpRatio = 0.35;

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

  // ===== Pause 暂停系统 =====
  bool _isPaused = false;
  bool _lastFrameHadPerson = true;
  int _noPersonFrames = 0;
  int _personFrames = 0;
  static const int _pauseThreshold = 15;
  static const int _resumeThreshold = 5;
  /// 短暂空检时保留上一帧骨架，避免闪断；超时再清空
  Map<PoseLandmarkType, Point3D>? _heldLandmarks;
  DateTime? _heldLandmarksAt;
  static const int _landmarkHoldMs = 800;

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

  /// 精彩瞬间回调：完成标准/完美动作时触发（供 UI 自动截屏）
  Function()? onHighlightMoment;

  /// 是否允许计次（免触控入镜门控通过前为 false，只出姿态不出次数）
  bool _countingEnabled = false;

  /// 深蹲/俯卧撑/弓步蹲有限状态机（校准 + ROM）
  ExerciseRepFsm? _repFsm;

  /// 高抬腿 / 平板 / 波比 / 登山跑 / 开合跳
  CameraMoveFsm? _moveFsm;

  /// 本组最低膝角（供组后 recap）；无则 null
  double? lastMinKneeAngle;
  double? sessionMinKneeAngle;

  /// 浅幅度未计次次数 + 本组常见口令（供离线 recap）
  int sessionShallowCount = 0;
  final List<String> sessionFaultCues = [];

  // ===== Getters =====
  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isDetecting => _isDetecting;
  bool get countingEnabled => _countingEnabled;
  int get repCount => _repCount;
  String get currentExercise => _currentExercise;
  double get sensitivity => _sensitivity;
  double get motionLevel => _motionLevel;
  CameraLensDirection get lensDirection =>
      _controller?.description.lensDirection ?? _preferredLens;

  // ===== 新增 Getters =====
  int get comboCount => _comboCount;
  double get comboMultiplier => _comboMultiplier;
  double get stamina => _stamina;
  bool get isPaused => _isPaused;
  bool get isPreparing => _isPreparing;
  double get currentFps => _currentFps;

  CameraLensDirection _preferredLens = CameraLensDirection.front;
  /// Android 优先走官方 YuvImage→JPEG→fromFilePath（绕开坏掉的 fromBitmap）
  bool _useJpegInput = Platform.isAndroid;
  /// Android 默认曾用 fromBitmap；JPEG 失败时回退
  bool _useBitmapInput = false;
  int _mlkitFailStreak = 0;
  int _mlkitEmptyStreak = 0;
  bool _detectorRecreating = false;
  String? _jpegTempPath;
  /// fromFilePath 无 metadata；记住缓冲尺寸用于归一化
  Size? _lastInputImageSize;
  DeviceOrientation? _lastEmaOrientation;
  String? _lastEmaSizeKey;
  /// 竖屏 mapRot 90/270 是否再 +180；冷启动可自动翻转校准
  bool _portraitFlip180 = true;
  int _mapBadSpanStreak = 0;
  /// 开流后前几帧不做跳变过滤，避免首帧脏点锁死 EMA
  int _emaWarmupLeft = 0;
  static const int _emaWarmupFrames = 20;
  static const _mlkitFrameChannel = MethodChannel('fat_battle/mlkit_frame');

  /// 初始化摄像头（默认前置；可用 [switchCamera] 切换）
  Future<void> initialize({
    CameraLensDirection preferredLens = CameraLensDirection.front,
  }) async {
    if (_isInitialized) return;

    _createPoseDetector();

    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('没有找到摄像头');
      }
      _preferredLens = preferredLens;
      await _openCamera(_pickCamera(_preferredLens));
      _isInitialized = true;
      PoseCoachDiary.instance.log(
        'MLKIT_INIT',
        'lens=$_preferredLens jpeg=$_useJpegInput bitmap=$_useBitmapInput',
      );
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  void _createPoseDetector() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
  }

  Future<void> _recreatePoseDetector(String reason) async {
    if (_detectorRecreating) return;
    _detectorRecreating = true;
    try {
      try {
        await _poseDetector.close();
      } catch (_) {}
      _createPoseDetector();
      PoseCoachDiary.instance.log('MLKIT_RECREATE', reason);
    } finally {
      _detectorRecreating = false;
    }
  }

  CameraDescription _pickCamera(CameraLensDirection lens) {
    final cams = _cameras!;
    return cams.firstWhere(
      (cam) => cam.lensDirection == lens,
      orElse: () => cams.first,
    );
  }

  Future<void> _openCamera(CameraDescription camera) async {
    // 必须先释放旧相机再开新机：双开 + 预览仍挂已 dispose 的 Controller 会导致永久黑屏
    final old = _controller;
    _controller = null;
    if (old != null) {
      try {
        if (old.value.isInitialized && old.value.isStreamingImages) {
          await old.stopImageStream();
        }
      } catch (_) {}
      try {
        await old.dispose();
      } catch (_) {}
      // 小米等机型释放硬件需要一点时间
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    final next = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      // 本机 camera_android 的 nv21 单平面喂 ML Kit 恒空检；
      // TFLite 已验证 yuv420 三平面有人，故自转 NV21。
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );
    await next.initialize();
    _controller = next;
    _isPaused = false;
    _noPersonFrames = 0;
    _personFrames = 0;
    _preferredLens = camera.lensDirection;
    _portraitFlip180 = true;
    _resetLandmarkPipeline(reason: 'open_camera');
    await syncOrientation();
  }

  void _resetLandmarkPipeline({required String reason}) {
    _smoothedLandmarks.clear();
    _velocity.clear();
    _lastEmaOrientation = null;
    _lastEmaSizeKey = null;
    _heldLandmarks = null;
    _heldLandmarksAt = null;
    _emaWarmupLeft = _emaWarmupFrames;
    _mapBadSpanStreak = 0;
    _loggedFrameMeta = false;
    PoseCoachDiary.instance.log('EMA_RESET', reason);
  }

  /// 刷新预览显示方向：pause/resume 比 lockCapture 更能触发 Surface 变换。
  Future<void> syncOrientation() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      final orient = c.value.deviceOrientation;
      final streaming = c.value.isStreamingImages;
      if (streaming) {
        try {
          await c.stopImageStream();
        } catch (_) {}
      }
      try {
        await c.pausePreview();
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await c.resumePreview();
      } catch (_) {
        // 部分机型 pause 不可用时退回 lock/unlock
        await c.lockCaptureOrientation(orient);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await c.unlockCaptureOrientation();
      }
      _resetLandmarkPipeline(reason: 'orient_sync');
      // 竖屏冷启动默认保留 +180；若贴合失败由 span 自动翻转
      _portraitFlip180 = true;
      PoseCoachDiary.instance.log(
        'ORIENT_SYNC',
        'orient=$orient mapRot=${_computeRotationDegrees()} '
        'flip180=$_portraitFlip180 pauseResume=true',
      );
      if (streaming && _isDetecting) {
        await c.startImageStream(_processCameraImage);
      }
    } catch (e) {
      PoseCoachDiary.instance.log('ORIENT_SYNC_FAIL', '$e');
    }
  }

  /// 前置 ↔ 后置切换；检测中会自动停流再恢复。
  Future<CameraController?> switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) {
      return _controller;
    }
    final wasDetecting = _isDetecting;
    final exercise = _currentExercise;
    final currentLens =
        _controller?.description.lensDirection ?? _preferredLens;
    if (wasDetecting) {
      try {
        await stopDetection();
      } catch (_) {}
    }

    final nextLens = currentLens == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    await _openCamera(_pickCamera(nextLens));
    PoseCoachDiary.instance.log(
      'CAMERA_SWITCH',
      'lens=$nextLens sensor=${_controller!.description.sensorOrientation}',
    );

    if (wasDetecting && exercise.isNotEmpty) {
      await startDetection(exercise);
    }
    return _controller;
  }

  /// 开始检测指定运动
  Future<void> startDetection(String exerciseType) async {
    if (!_isInitialized || _controller == null) {
      throw StateError('摄像头未初始化');
    }

    // 若残留推流，先停干净再开，避免 CameraException
    if (_controller!.value.isStreamingImages) {
      try {
        await _controller!.stopImageStream();
      } catch (_) {}
    }

    _currentExercise = exerciseType;
    _repCount = 0;
    _motionState = _isJumpingExercise(exerciseType) ? 'closed' : 'up';
    _smoothedLandmarks.clear();
    _velocity.clear();
    _heldLandmarks = null;
    _heldLandmarksAt = null;
    _lastRepTime = DateTime.now();
    _isDetecting = true;
    _isBusy = false;
    _countingEnabled = false; // 等入镜门控通过后再计次
    _repFsm = ExerciseRepFsm.forType(exerciseType);
    _repFsm?.reset();
    _moveFsm = CameraMoveFsm.forType(exerciseType);
    _moveFsm?.reset();
    lastMinKneeAngle = null;
    sessionMinKneeAngle = null;
    sessionShallowCount = 0;
    sessionFaultCues.clear();

    // 重置动作特定状态
    _jackNoseMinY = 999;
    _jackNoseMaxY = 0;
    _lastJackRhythm = 0;

    // 重置新运动状态
    _highKneeState = 'down';
    _plankAccumulatedSeconds = 0;
    _plankStartTime = null;
    _burpeePhase = 'stand';
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
    _loggedFrameMeta = false;

    // 启动入镜等待（不计次）；正式计次由 UI 门控 setCountingEnabled(true)
    _startPrepare();

    await _controller!.startImageStream(_processCameraImage);
  }

  /// 免控通过后开启计次；离开入镜时也可再次关闭。
  void setCountingEnabled(bool enabled) {
    if (_countingEnabled == enabled) return;
    _countingEnabled = enabled;
    if (enabled) {
      _isPreparing = false;
      _repFsm?.commitCalibration();
      onPrepareProgress?.call(1.0);
      onFeedback?.call('开始运动！');
    }
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

  /// 安全截屏：若正在推流则先停流再拍照，避免与 ML Kit 抢相机。
  /// 返回 JPEG 路径；失败返回 null。调用方负责决定是否恢复检测。
  Future<String?> captureStillSafe() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return null;
    final wasStreaming = c.value.isStreamingImages;
    final wasDetecting = _isDetecting;
    try {
      if (wasStreaming) {
        _isDetecting = false;
        await c.stopImageStream();
        // 等最后一帧释放
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      final file = await c.takePicture();
      return file.path;
    } catch (e) {
      debugPrint('captureStillSafe failed: $e');
      return null;
    } finally {
      if (wasStreaming && wasDetecting && c.value.isInitialized) {
        _isDetecting = true;
        try {
          if (!c.value.isStreamingImages) {
            await c.startImageStream(_processCameraImage);
          }
        } catch (e) {
          debugPrint('restart stream after capture failed: $e');
        }
      }
    }
  }

  /// 处理每一帧摄像头图像
  void _processCameraImage(CameraImage image) {
    if (!_isDetecting || _isBusy) return;

    // 0. 更新 FPS 统计（每帧都统计以确保准确性）
    _updateFpsStats();

    // 1. 暂停只根据上一帧结果更新状态；绝不能跳过推理，
    //    否则无人暂停后永远无法再检出人体恢复（死锁）。
    _updatePauseState(_lastFrameHadPerson);

    // 2. 恢复体力（暂停时也缓慢恢复）
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

    _isBusy = true;
    _processCameraImageAsync(image);
  }

  Future<void> _processCameraImageAsync(CameraImage image) async {
    try {
      final inputImage = await _toInputImageAsync(image);
      if (inputImage == null) {
        _isBusy = false;
        return;
      }
      await _runDetection(inputImage);
    } catch (e) {
      debugPrint('PoseDetection 帧处理失败: $e');
      PoseCoachDiary.instance.log('FRAME_FAIL', '$e');
      _isBusy = false;
    }
  }

  Future<String> _ensureJpegTempPath() async {
    if (_jpegTempPath != null) return _jpegTempPath!;
    final dir = await getTemporaryDirectory();
    _jpegTempPath = '${dir.path}/mlkit_pose_frame.jpg';
    return _jpegTempPath!;
  }

  int _computeRotationDegrees() {
    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;
    if (Platform.isIOS) return sensorOrientation;
    var rotationCompensation =
        _orientations[_controller!.value.deviceOrientation] ?? 0;
    if (camera.lensDirection == CameraLensDirection.front) {
      return (sensorOrientation + rotationCompensation) % 360;
    }
    return (sensorOrientation - rotationCompensation + 360) % 360;
  }

  Future<InputImage?> _toInputImageAsync(CameraImage image) async {
    if (!Platform.isAndroid || !_useJpegInput || image.planes.length < 3) {
      return _toInputImage(image);
    }

    try {
      final rotationDeg = _computeRotationDegrees();
      final nv21 = _yuv420ToNv21(image);
      // 冻结：不旋转 JPEG。关键点保持缓冲坐标，与 preview 内 RotatedBox 同系。
      final jpeg = await _mlkitFrameChannel.invokeMethod<Uint8List>(
        'nv21ToJpeg',
        {
          'nv21': nv21,
          'width': image.width,
          'height': image.height,
          'rotation': 0,
          'quality': 80,
        },
      );
      if (jpeg == null || jpeg.isEmpty) {
        PoseCoachDiary.instance.log('JPEG_EMPTY', 'channel returned empty');
        return _toInputImage(image);
      }

      final path = await _ensureJpegTempPath();
      await File(path).writeAsBytes(jpeg, flush: true);

      _lastInputImageSize =
          Size(image.width.toDouble(), image.height.toDouble());

      if (!_loggedFrameMeta) {
        _loggedFrameMeta = true;
        final planeLens = image.planes
            .map((p) => '${p.bytes.length}/${p.bytesPerRow}/${p.bytesPerPixel}')
            .join(';');
        PoseCoachDiary.instance.log(
          'CAMERA_FRAME',
          'rawFmt=${image.format.raw} planes=${image.planes.length} '
          'size=${image.width}x${image.height} mapRot=$rotationDeg '
          'sensor=${_controller!.description.sensorOrientation} '
          'orient=${_controller!.value.deviceOrientation} '
          'planeLens=$planeLens path=jpeg_buffer jpegBytes=${jpeg.length}',
        );
      }

      return InputImage.fromFilePath(path);
    } catch (e) {
      PoseCoachDiary.instance.log('JPEG_FAIL', '$e');
      // 不永久关闭 JPEG
      return _toInputImage(image);
    }
  }

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// 将 CameraImage 转换为 ML Kit 可识别的 InputImage
  /// 对齐 google_ml_kit 官方 camera_view 示例（Android 必须 nv21）。
  InputImage? _toInputImage(CameraImage image) {
    try {
      final camera = _controller!.description;
      final sensorOrientation = camera.sensorOrientation;

      InputImageRotation? rotation;
      if (Platform.isIOS) {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      } else {
        var rotationCompensation =
            _orientations[_controller!.value.deviceOrientation];
        if (rotationCompensation == null) {
          // 方向尚未就绪时用传感器默认，避免整段检测空转
          rotationCompensation = 0;
        }
        if (camera.lensDirection == CameraLensDirection.front) {
          rotationCompensation =
              (sensorOrientation + rotationCompensation) % 360;
        } else {
          rotationCompensation =
              (sensorOrientation - rotationCompensation + 360) % 360;
        }
        rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      }
      if (rotation == null) return null;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      final size = Size(image.width.toDouble(), image.height.toDouble());

      if (!_loggedFrameMeta) {
        _loggedFrameMeta = true;
        final planeLens = image.planes
            .map((p) => '${p.bytes.length}/${p.bytesPerRow}/${p.bytesPerPixel}')
            .join(';');
        PoseCoachDiary.instance.log(
          'CAMERA_FRAME',
          'rawFmt=${image.format.raw} mapped=$format '
          'planes=${image.planes.length} size=${image.width}x${image.height} '
          'rot=$rotation sensor=$sensorOrientation '
          'orient=${_controller!.value.deviceOrientation} '
          'planeLens=$planeLens',
        );
      }

      // Android：优先三平面 yuv420 → 自转 NV21（本机插件 nv21 单平面对 Pose 恒空）
      if (Platform.isAndroid && image.planes.length >= 3) {
        final nv21 = _yuv420ToNv21(image);
        if (_useBitmapInput) {
          final rgba = _yuv420ToRgba(image);
          return InputImage.fromBitmap(
            bitmap: rgba,
            width: image.width,
            height: image.height,
            rotation: rotation.rawValue,
          );
        }
        return InputImage.fromBytes(
          bytes: nv21,
          metadata: InputImageMetadata(
            size: size,
            rotation: rotation,
            format: InputImageFormat.nv21,
            bytesPerRow: image.width,
          ),
        );
      }

      // 兼容：相机直接输出 nv21 单平面
      if (Platform.isAndroid &&
          image.planes.length == 1 &&
          (format == null ||
              format == InputImageFormat.nv21 ||
              format == InputImageFormat.yuv_420_888)) {
        final plane = image.planes.first;
        final bytes = Uint8List.fromList(plane.bytes);

        if (_useBitmapInput) {
          final rgba = _nv21ToRgba(bytes, image.width, image.height);
          return InputImage.fromBitmap(
            bitmap: rgba,
            width: image.width,
            height: image.height,
            rotation: rotation.rawValue,
          );
        }

        return InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: size,
            rotation: rotation,
            format: InputImageFormat.nv21,
            bytesPerRow: plane.bytesPerRow,
          ),
        );
      }

      if (Platform.isIOS &&
          format == InputImageFormat.bgra8888 &&
          image.planes.length == 1) {
        final plane = image.planes.first;
        final bytes = Uint8List.fromList(plane.bytes);
        return InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: size,
            rotation: rotation,
            format: InputImageFormat.bgra8888,
            bytesPerRow: plane.bytesPerRow,
          ),
        );
      }

      PoseCoachDiary.instance.log(
        'INPUT_IMAGE_SKIP',
        'format=${image.format.raw} planes=${image.planes.length} '
        'size=${image.width}x${image.height}',
      );
      return null;
    } catch (e) {
      debugPrint('PoseDetection: InputImage 转换失败: $e');
      PoseCoachDiary.instance.log('INPUT_IMAGE_FAIL', '$e');
      return null;
    }
  }

  void _diaryMlkitThrottled(String event, String detail) {
    final now = DateTime.now();
    if (_lastMlkitDiaryAt != null &&
        now.difference(_lastMlkitDiaryAt!) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastMlkitDiaryAt = now;
    PoseCoachDiary.instance.log(event, detail);
  }

  /// 将 Android CameraImage (YUV_420_888) 转换为 NV21 单缓冲格式
  /// 对齐 googlesamples/mlkit BitmapUtils.yuv420ThreePlanesToNV21
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
    final yPixelStride = yPlane.bytesPerPixel ?? 1;
    if (yRowStride == width && yPixelStride == 1) {
      final copy = ySize < yPlane.bytes.length ? ySize : yPlane.bytes.length;
      nv21.setRange(0, copy, yPlane.bytes);
    } else {
      var out = 0;
      for (int row = 0; row < height; row++) {
        var inputPos = row * yRowStride;
        for (int col = 0; col < width; col++) {
          nv21[out++] = yPlane.bytes[inputPos.clamp(0, yPlane.bytes.length - 1)];
          inputPos += yPixelStride;
        }
      }
    }

    // 2. 交错拷贝 V、U（NV21 = VU 对）
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    final halfHeight = height ~/ 2;
    final halfWidth = width ~/ 2;
    int uvIndex = ySize;

    // 快路径：UV 已是 NV21 交错（pixelStride=2 且 V 在 U 前 1 字节）
    if (uvPixelStride == 2 &&
        vPlane.bytesPerPixel == 2 &&
        identical(uPlane.bytes, vPlane.bytes) == false) {
      // 仍逐点取，兼容小米等机型 buffer 布局
    }

    for (int row = 0; row < halfHeight; row++) {
      final uRowStart = row * uvRowStride;
      final vRowStart = row * (vPlane.bytesPerRow);
      for (int col = 0; col < halfWidth; col++) {
        final uIdx = uRowStart + col * uvPixelStride;
        final vIdx = vRowStart + col * (vPlane.bytesPerPixel ?? uvPixelStride);
        final v = vPlane.bytes[vIdx.clamp(0, vPlane.bytes.length - 1)];
        final u = uPlane.bytes[uIdx.clamp(0, uPlane.bytes.length - 1)];
        if (uvIndex + 1 >= nv21.length) break;
        nv21[uvIndex++] = v;
        nv21[uvIndex++] = u;
      }
    }

    return nv21;
  }

  /// YUV420 三平面 → RGBA（与 TFLite 同源采样，供 fromBitmap）
  Uint8List _yuv420ToRgba(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;
    final yRowStride = yPlane.bytesPerRow;
    final uRowStride = uPlane.bytesPerRow;
    final vRowStride = vPlane.bytesPerRow;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    final out = Uint8List(width * height * 4);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIdx = y * yRowStride + x;
        final uvX = x ~/ 2;
        final uvY = y ~/ 2;
        final uIdx = uvY * uRowStride + uvX * uPixelStride;
        final vIdx = uvY * vRowStride + uvX * vPixelStride;
        final yVal = yIdx < yBytes.length ? (yBytes[yIdx] & 0xff) : 0;
        final uVal = uIdx < uBytes.length ? (uBytes[uIdx] & 0xff) : 128;
        final vVal = vIdx < vBytes.length ? (vBytes[vIdx] & 0xff) : 128;
        final r = (yVal + 1.402 * (vVal - 128)).round().clamp(0, 255);
        final g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128))
            .round()
            .clamp(0, 255);
        final b = (yVal + 1.772 * (uVal - 128)).round().clamp(0, 255);
        final o = (y * width + x) * 4;
        out[o] = r;
        out[o + 1] = g;
        out[o + 2] = b;
        out[o + 3] = 255;
      }
    }
    return out;
  }

  /// 执行姿态推理并分析
  Future<void> _runDetection(InputImage inputImage) async {
    try {
      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isEmpty) {
        _lastFrameHadPerson = false;
        _mlkitEmptyStreak++;
        final now = DateTime.now();
        final holdOk = _heldLandmarks != null &&
            _heldLandmarksAt != null &&
            now.difference(_heldLandmarksAt!).inMilliseconds < _landmarkHoldMs;
        if (holdOk) {
          // 短时空检：继续展示上一帧，避免点位闪灭
          onPoseUpdate?.call(_heldLandmarks);
        } else {
          _heldLandmarks = null;
          _heldLandmarksAt = null;
          onPoseUpdate?.call(null);
          _motionLevel = 0;
          onMotionUpdate?.call(0);
          onFeedback?.call('请将全身入镜');
        }
        final sz = inputImage.metadata?.size;
        // 不在空检时切 Bitmap：会污染会话且 JPEG 路径下无益
        _diaryMlkitThrottled(
          'MLKIT_EMPTY',
          'img=${sz?.width.toInt()}x${sz?.height.toInt()} '
          'rot=${inputImage.metadata?.rotation} '
          'fmt=${inputImage.metadata?.format} '
          'jpeg=$_useJpegInput empty=$_mlkitEmptyStreak '
          'paused=$_isPaused hold=$holdOk',
        );
        if (_mlkitEmptyStreak == 25 || _mlkitEmptyStreak == 60) {
          await _recreatePoseDetector('empty=$_mlkitEmptyStreak');
        }
        return;
      }

      _lastFrameHadPerson = true;
      _mlkitFailStreak = 0;
      _mlkitEmptyStreak = 0;

      final pose = poses.first;
      // fromFilePath 无 metadata.size，用 JPEG 摆正尺寸兜底
      final imageSize = inputImage.metadata?.size ?? _lastInputImageSize;
      // EMA 平滑（像素 → 归一化 0..1，供 UI / 门控 / 阈值共用）
      final smoothed = _applyEmaSmoothing(pose.landmarks, imageSize);
      _heldLandmarks = smoothed;
      _heldLandmarksAt = DateTime.now();
      onPoseUpdate?.call(smoothed);

      // 入镜/倒计时：采集站姿髋膝基线（不计次）
      if (_repFsm != null && !_countingEnabled && !_isPaused) {
        _repFsm!.ingestCalibration(_toFsmLandmarks(smoothed));
      }

      // 暂停时仍展示姿态，但不计次
      if (!_isPreparing && _countingEnabled && !_isPaused) {
        _analyzePose(smoothed);
      }
    } catch (e) {
      debugPrint('PoseDetection 推理失败: $e');
      final sz = inputImage.metadata?.size;
      _mlkitFailStreak++;
      final err = '$e';
      if (err.contains('Internal error') || err.contains('PoseDetectorError')) {
        // 不切 Bitmap：会污染 JPEG 会话；仅重建 detector
        if (_mlkitFailStreak == 3 || _mlkitFailStreak == 10) {
          await _recreatePoseDetector('fails=$_mlkitFailStreak err=$err');
        }
      }
      _diaryMlkitThrottled(
        'MLKIT_FAIL',
        'err=$e img=${sz?.width.toInt()}x${sz?.height.toInt()} '
        'rot=${inputImage.metadata?.rotation} '
        'fmt=${inputImage.metadata?.format} '
        'bitmap=$_useBitmapInput streak=$_mlkitFailStreak',
      );
    } finally {
      _isBusy = false;
    }
  }

  /// NV21 → RGBA（供 InputImage.fromBitmap，绕开部分机型 NV21 fromBytes Internal error）
  Uint8List _nv21ToRgba(Uint8List nv21, int width, int height) {
    final frameSize = width * height;
    final out = Uint8List(frameSize * 4);
    for (int y = 0; y < height; y++) {
      final uvRow = frameSize + (y >> 1) * width;
      for (int x = 0; x < width; x++) {
        final yi = y * width + x;
        final yVal = nv21[yi] & 0xff;
        final uvIndex = uvRow + (x & ~1);
        final v = nv21[uvIndex.clamp(0, nv21.length - 1)] & 0xff;
        final u = nv21[(uvIndex + 1).clamp(0, nv21.length - 1)] & 0xff;
        final r = (yVal + 1.370705 * (v - 128)).round().clamp(0, 255);
        final g = (yVal - 0.337633 * (u - 128) - 0.698001 * (v - 128))
            .round()
            .clamp(0, 255);
        final b = (yVal + 1.732446 * (u - 128)).round().clamp(0, 255);
        final o = yi * 4;
        out[o] = r;
        out[o + 1] = g;
        out[o + 2] = b;
        out[o + 3] = 255;
      }
    }
    return out;
  }

  /// 缓冲像素 → CameraPreview.child 归一化坐标。
  /// jpeg_buffer 关键点在传感器缓冲空间；按 ML Kit rotation 顺时针摆正。
  /// 竖屏（rot 90/270）默认再 +180；冷启动若肩宽虚高会自动翻转 [_portraitFlip180]。
  /// 横屏 rot=0 已贴合，禁止加补偿。
  (double, double) _bufferPixelToPreviewNorm(
    double px,
    double py,
    double bufW,
    double bufH,
    int rotationDeg,
  ) {
    var rot = rotationDeg % 360;
    if ((rot == 90 || rot == 270) && _portraitFlip180) {
      rot = (rot + 180) % 360;
    }
    late final double dx;
    late final double dy;
    late final double dw;
    late final double dh;
    switch (rot) {
      case 90:
        dw = bufH;
        dh = bufW;
        dx = py;
        dy = bufW - px;
        break;
      case 270:
        dw = bufH;
        dh = bufW;
        dx = bufH - py;
        dy = px;
        break;
      case 180:
        dw = bufW;
        dh = bufH;
        dx = bufW - px;
        dy = bufH - py;
        break;
      default:
        dw = bufW;
        dh = bufH;
        dx = px;
        dy = py;
        break;
    }
    return (
      (dx / dw).clamp(0.0, 1.0),
      (dy / dh).clamp(0.0, 1.0),
    );
  }

  /// 前置预览一般为镜像自拍；jpeg_buffer 关键点未镜像，需水平翻转对齐。
  (double, double) _toPreviewNorm(
    double px,
    double py,
    double bufW,
    double bufH,
    int rotationDeg,
  ) {
    var (x, y) = _bufferPixelToPreviewNorm(px, py, bufW, bufH, rotationDeg);
    if (_controller?.description.lensDirection == CameraLensDirection.front) {
      x = 1.0 - x;
    }
    return (x, y);
  }

  /// 对关键点应用 EMA 平滑 + 异常值过滤，抑制抖动。
  /// jpeg_buffer 像素 → 预览 child 归一化（供 CameraPreview.child 叠层）。
  Map<PoseLandmarkType, Point3D> _applyEmaSmoothing(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    Size? imageSize,
  ) {
    final result = <PoseLandmarkType, Point3D>{};
    var bufW = imageSize?.width ?? 0;
    var bufH = imageSize?.height ?? 0;
    if (bufW <= 0 || bufH <= 0) {
      bufW = _lastInputImageSize?.width ?? 0;
      bufH = _lastInputImageSize?.height ?? 0;
    }
    if (bufW <= 0 || bufH <= 0) {
      bufW = 720;
      bufH = 480;
    }

    final orient = _controller?.value.deviceOrientation;
    final rot = _computeRotationDegrees();
    final isFront =
        _controller?.description.lensDirection == CameraLensDirection.front;
    final sizeKey =
        '${bufW.round()}x${bufH.round()}@$rot|f=${_portraitFlip180 ? 1 : 0}|cam=${isFront ? 'F' : 'B'}';
    if (orient != _lastEmaOrientation || sizeKey != _lastEmaSizeKey) {
      _smoothedLandmarks.clear();
      _velocity.clear();
      _emaWarmupLeft = _emaWarmupFrames;
      _lastEmaOrientation = orient;
      _lastEmaSizeKey = sizeKey;
    }

    final ls = landmarks[PoseLandmarkType.leftShoulder];
    final rs = landmarks[PoseLandmarkType.rightShoulder];
    if (ls != null && rs != null && bufW > 0) {
      final span = ((ls.x - rs.x) / bufW).abs();
      if (span > 0.7) {
        _smoothedLandmarks.clear();
        _velocity.clear();
        _emaWarmupLeft = _emaWarmupFrames;
      }
    }

    final warmup = _emaWarmupLeft > 0;
    if (warmup) _emaWarmupLeft--;

    landmarks.forEach((type, lm) {
      final (x, y) = _toPreviewNorm(lm.x, lm.y, bufW, bufH, rot);
      final curr = Point3D(x, y, lm.z);
      final prev = _smoothedLandmarks[type];

      if (prev == null || warmup) {
        _smoothedLandmarks[type] = curr;
        _velocity[type] = Point3D(0, 0, 0);
        result[type] = curr;
        return;
      }

      final dx = curr.x - prev.x;
      final dy = curr.y - prev.y;
      final dist = math.sqrt(dx * dx + dy * dy);

      Point3D filtered;
      if (dist > _maxJumpRatio) {
        // 大跳变：直接采纳新点，避免脏首帧把肩锁在边缘（旧逻辑用速度拖住）
        filtered = curr;
      } else {
        filtered = Point3D(
          prev.x + (curr.x - prev.x) * _emaAlpha,
          prev.y + (curr.y - prev.y) * _emaAlpha,
          prev.z + (curr.z - prev.z) * _emaAlpha,
        );
      }

      _velocity[type] = Point3D(
        filtered.x - prev.x,
        filtered.y - prev.y,
        filtered.z - prev.z,
      );

      _smoothedLandmarks[type] = filtered;
      result[type] = filtered;
    });

    // 预览肩宽虚高 → 映射可能差 180°，自动翻转并清空 EMA
    final outLs = result[PoseLandmarkType.leftShoulder];
    final outRs = result[PoseLandmarkType.rightShoulder];
    if (outLs != null && outRs != null) {
      final previewSpan = (outLs.x - outRs.x).abs();
      final portraitRot = rot == 90 || rot == 270;
      if (portraitRot && previewSpan > 0.55) {
        _mapBadSpanStreak++;
        if (_mapBadSpanStreak >= 2) {
          _portraitFlip180 = !_portraitFlip180;
          _mapBadSpanStreak = 0;
          _smoothedLandmarks.clear();
          _velocity.clear();
          _emaWarmupLeft = _emaWarmupFrames;
          PoseCoachDiary.instance.log(
            'MAP_FLIP',
            'flip180=$_portraitFlip180 span=${previewSpan.toStringAsFixed(3)} '
            'mapRot=$rot',
          );
          // 用新翻转重映射本帧
          result.clear();
          landmarks.forEach((type, lm) {
            final (x, y) = _toPreviewNorm(lm.x, lm.y, bufW, bufH, rot);
            final curr = Point3D(x, y, lm.z);
            _smoothedLandmarks[type] = curr;
            _velocity[type] = Point3D(0, 0, 0);
            result[type] = curr;
          });
        }
      } else if (previewSpan > 0.05 && previewSpan < 0.45) {
        _mapBadSpanStreak = 0;
      }
    }

    return result;
  }

  /// 根据当前运动类型分发分析逻辑
  void _analyzePose(Map<PoseLandmarkType, Point3D> lm) {
    switch (_currentExercise) {
      case 'squat':
      case 'pushup':
      case 'lunge':
        _tickRepFsm(lm);
        break;
      case 'jumping_jack':
      case 'hiit':
      case 'jumprope':
      case 'highknee':
      case 'plank':
      case 'burpee':
      case 'mountainclimber':
        _tickMoveFsm(lm);
        break;
      default:
        // 未实现姿态检测的运动，使用通用运动强度
        _analyzeGeneric(lm);
    }
  }

  // ============================================================
  // 深蹲 / 俯卧撑 / 弓步蹲：校准站姿 + ROM 有限状态机
  // idle/setup → eccentric → bottom（必须达 ROM）→ concentric → lock
  // 浅幅度只出口令、不计次。质量分走 _calcQualityScore。
  // ============================================================

  Map<String, LandmarkPoint> _toFsmLandmarks(
    Map<PoseLandmarkType, Point3D> lm,
  ) {
    final out = <String, LandmarkPoint>{};
    lm.forEach((k, v) {
      out[k.name] = LandmarkPoint(v.x, v.y, v.z);
    });
    return out;
  }

  void _tickRepFsm(Map<PoseLandmarkType, Point3D> lm) {
    final fsm = _repFsm;
    if (fsm == null) return;
    final tick = fsm.tick(_toFsmLandmarks(lm), sensitivity: _sensitivity);
    _motionState = tick.phase.name;
    _updateMotionLevelByAngle(tick.motionLevel, 1.0);
    if (tick.minKneeAngle != null) {
      lastMinKneeAngle = tick.minKneeAngle;
      final cur = sessionMinKneeAngle;
      sessionMinKneeAngle =
          cur == null ? tick.minKneeAngle : math.min(cur, tick.minKneeAngle!);
    }
    if (tick.cue != null && tick.cue!.isNotEmpty && !tick.counted) {
      _noteFaultCue(tick.cue!);
      onFeedback?.call(tick.cue!);
    }
    if (tick.shallow) {
      sessionShallowCount++;
    }
    if (!tick.counted) return;
    _repCount++;
    _lastRepTime = DateTime.now();
    onRepDetected?.call(_repCount, tick.exerciseName);
    _handleRepSuccess();
    if (tick.qualityAngle != null) {
      _calcQualityScore(
        fsm.exerciseType,
        tick.qualityAngle!,
        tick.qualityDepth ?? 0.7,
        tick.qualityBodyLine ?? 0.8,
      );
    }
    if (tick.highlight) onHighlightMoment?.call();
    final fb = tick.feedback;
    onFeedback?.call(
      fb == null || fb.isEmpty ? '$_repCount 个' : '$_repCount 个！$fb',
    );
  }

  void _tickMoveFsm(Map<PoseLandmarkType, Point3D> lm) {
    final fsm = _moveFsm;
    if (fsm == null) {
      _analyzeGeneric(lm);
      return;
    }
    final tick = fsm.tick(_toFsmLandmarks(lm), sensitivity: _sensitivity);
    _motionState = tick.phase.name;
    _updateMotionLevelByAngle(tick.motionLevel, 1.0);
    if (tick.minKneeAngle != null && fsm.exerciseType != 'plank') {
      lastMinKneeAngle = tick.minKneeAngle;
      final cur = sessionMinKneeAngle;
      sessionMinKneeAngle =
          cur == null ? tick.minKneeAngle : math.min(cur, tick.minKneeAngle!);
    }
    if (tick.cue != null && tick.cue!.isNotEmpty && !tick.counted) {
      _noteFaultCue(tick.cue!);
      onFeedback?.call(tick.cue!);
    }
    if (tick.shallow) {
      sessionShallowCount++;
    }
    if (!tick.counted) return;
    _repCount++;
    _lastRepTime = DateTime.now();
    onRepDetected?.call(_repCount, tick.exerciseName);
    _handleRepSuccess();
    if (tick.qualityAngle != null) {
      _calcQualityScore(
        fsm.exerciseType,
        tick.qualityAngle!,
        tick.qualityDepth ?? 0.7,
        tick.qualityBodyLine ?? 0.8,
      );
    }
    if (tick.highlight) onHighlightMoment?.call();
    final fb = tick.feedback;
    final unit = fsm.exerciseType == 'plank' ? '秒' : '个';
    onFeedback?.call(
      fb == null || fb.isEmpty
          ? '$_repCount $unit'
          : '$_repCount $unit！$fb',
    );
  }

  void _noteFaultCue(String cue) {
    if (cue.isEmpty) return;
    if (sessionFaultCues.contains(cue)) return;
    if (sessionFaultCues.length >= 6) return;
    sessionFaultCues.add(cue);
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
      _handleRepSuccess();
      _emitJackFeedback(jumpHeight, feetSpread);
      _calcQualityScore(
        'jumping_jack',
        (jumpHeight / 0.08).clamp(0.0, 1.0),
        (feetSpread / 1.5).clamp(0.0, 1.0),
        0.85,
      );
      _jackNoseMinY = 999;
    }
    _motionState = newState;
  }

  void _emitJackFeedback(double jumpHeight, double feetSpread) {
    String msg;
    if (jumpHeight > 0.08 && feetSpread > 1.5) {
      msg = '🔥 $_repCount 个！标准开合跳，爆发十足！';
      onHighlightMoment?.call();
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
      onFeedback?.call('请正对手机，下半身入镜');
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
      onHighlightMoment?.call();
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
      onFeedback?.call('请正对手机，全身入镜');
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
      final secs = _plankAccumulatedSeconds.toInt();
      // 每整秒推进一次计数（供 UI / 连训达标检测）
      if (secs > _repCount) {
        _repCount = secs;
        onRepDetected?.call(_repCount, '平板支撑');
        if (secs > 0 && secs % 15 == 0) {
          onHighlightMoment?.call();
        }
      }
      // 每累计5秒提示一次
      if (secs > 0 && secs % 5 == 0 && _debounceOk()) {
        _emitPlankFeedback(_plankAccumulatedSeconds);
        _calcQualityScore('plank', 0.9, 0.8, bodyLine);
      }
    } else {
      _plankStartTime = null;
      if (shoulderHipDiff >= shoulderHipThreshold) {
        onFeedback?.call('腰往下塌了，收紧核心把髋抬平');
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
      onFeedback?.call('请正对手机，全身入镜');
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
      onHighlightMoment?.call();
    } else if (kneeAngle > 160) {
      msg = '💪 $_repCount 个！节奏不错，继续燃烧！';
    } else {
      msg = '👍 $_repCount 个！动作幅度可以再大一点';
    }
    onFeedback?.call(msg);
  }

  // 弓步蹲由 ExerciseRepFsm 处理（见 _tickRepFsm）

  // ============================================================
  // 登山者：平板形态下用膝到肩距离判断收腿（不依赖画面 X 左右手性）
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
      onFeedback?.call('请正对手机，全身入镜');
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
      if (shoulderHipDiff >= shThreshold) {
        onFeedback?.call('腰往下塌了，收紧核心把髋抬平');
      } else {
        onFeedback?.call('请保持平板支撑姿势');
      }
      _updateMotionLevelByAngle(0.1, 1.0);
      return;
    }

    // 膝到肩距离判断收腿，不依赖画面 X 左右手性（前置/镜像也可计次）
    final midShoulder = Point3D(
      (lShoulder.x + rShoulder.x) / 2,
      (lShoulder.y + rShoulder.y) / 2,
      0,
    );
    final leftTuck = _dist(lKnee, midShoulder);
    final rightTuck = _dist(rKnee, midShoulder);
    final tuckDelta = (leftTuck - rightTuck).abs();
    final threshold = 0.04 * (1.0 + (1.0 - _sensitivity) * 0.5);
    final leftForward = leftTuck + threshold < rightTuck;
    final rightForward = rightTuck + threshold < leftTuck;

    final motion = tuckDelta > threshold ? 0.8 : 0.3;
    _updateMotionLevelByAngle(motion, 1.0);

    String newState = _mountainClimberState;
    if (leftForward && !rightForward) {
      newState = 'left';
    } else if (rightForward && !leftForward) {
      newState = 'right';
    }

    if (_mountainClimberState == 'left' && newState == 'right' && _debounceOk()) {
      _repCount++;
      _lastRepTime = DateTime.now();
      onRepDetected?.call(_repCount, '登山者');
      _handleRepSuccess();
      _emitMountainClimberFeedback(leftForward, rightForward, inPlank);
      _calcQualityScore('mountainclimber', inPlank ? 0.9 : 0.5, 0.8, 0.7);
    }

    _mountainClimberState = newState;
  }

  void _emitMountainClimberFeedback(
    bool leftFwd,
    bool rightFwd,
    bool inPlank,
  ) {
    String msg;
    if (inPlank && (leftFwd || rightFwd)) {
      msg = '🔥 $_repCount 次！标准登山跑，核心炸裂！';
      onHighlightMoment?.call();
    } else if (leftFwd || rightFwd) {
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

  double _dist(Point3D a, Point3D b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
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
    _jackNoseMinY = 999;
    _jackNoseMaxY = 0;
    _lastJackRhythm = 0;

    // 重置新运动状态
    _highKneeState = 'down';
    _plankAccumulatedSeconds = 0;
    _plankStartTime = null;
    _burpeePhase = 'stand';
    _mountainClimberState = 'left';

    // 重置连击
    _comboCount = 0;
    _comboMultiplier = 1.0;
    _lastComboTime = DateTime.now();
    _repFsm?.reset();
    _moveFsm?.reset();
    lastMinKneeAngle = null;
    sessionMinKneeAngle = null;
    sessionShallowCount = 0;
    sessionFaultCues.clear();
  }

  /// 续训：恢复已累计次数/秒数（平板按秒）。
  void seedRepCount(int count) {
    final n = count < 0 ? 0 : count;
    _repCount = n;
    if (_currentExercise == 'plank') {
      _plankAccumulatedSeconds = n.toDouble();
      _plankStartTime = null;
      final plank = _moveFsm;
      if (plank is PlankHoldFsm) plank.seedSeconds(n);
    }
    onRepDetected?.call(_repCount, _currentExercise);
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
