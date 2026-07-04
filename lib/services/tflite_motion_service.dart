import 'dart:async';
import 'dart:io' show FileSystemException;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// 基于 TensorFlow Lite (MoveNet) 的姿态估计与动作分类服务
///
/// API 与 [CameraMotionDetector] 保持一致，方便在 UI 层互换使用。
/// 实现流程：
///   1. 加载 MoveNet Lightning tflite 模型（输入 1x192x192x3 int32）
///   2. 从 CameraImage (YUV420) 预处理为 RGB 并 resize
///   3. 运行推理得到 17 个关键点 [y, x, confidence]
///   4. 通过滑动窗口分析关键点变化，分类动作并计数
class TfliteMotionService {
  // ---- 模型配置 ----
  /// MoveNet Lightning 输入尺寸（Thunder 为 256，需要时改为 256）
  static const int kInputSize = 192;

  /// 模型资源路径（pubspec.yaml 中需声明）
  static const String kModelAsset = 'assets/models/movenet_lightning.tflite';

  /// 关键点数量（COCO 17）
  static const int kKeypointCount = 17;

  /// 关键点索引（COCO 顺序）
  static const int kNose = 0;
  static const int kLeftEye = 1;
  static const int kRightEye = 2;
  static const int kLeftEar = 3;
  static const int kRightEar = 4;
  static const int kLeftShoulder = 5;
  static const int kRightShoulder = 6;
  static const int kLeftElbow = 7;
  static const int kRightElbow = 8;
  static const int kLeftWrist = 9;
  static const int kRightWrist = 10;
  static const int kLeftHip = 11;
  static const int kRightHip = 12;
  static const int kLeftKnee = 13;
  static const int kRightKnee = 14;
  static const int kLeftAnkle = 15;
  static const int kRightAnkle = 16;

  // ---- 运行时状态 ----
  Interpreter? _interpreter;
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  bool _isInitialized = false;
  bool _isDetecting = false;
  bool _isProcessing = false; // 防止帧堆积

  String _currentExercise = '';
  int _repCount = 0;

  /// 动作阶段状态：'up' / 'down' / 'jump' / 'land' / 'idle'
  String _motionState = 'idle';
  DateTime _lastRepTime = DateTime.now();

  /// 帧跳过：降低推理频率，控制功耗
  final int _frameSkip = 2;
  int _frameCounter = 0;

  /// 滑动窗口：缓存最近 N 帧的关键点，用于平滑与模式分析
  final List<Pose> _poseBuffer = [];
  static const int _kBufferSize = 15; // ~0.5s @ 30fps

  /// 关键点置信度阈值，低于此值视为无效
  static const double _kMinConfidence = 0.3;

  /// 计数防抖（毫秒）
  int _debounceMs = 500;

  /// 是否启用硬件加速（GPU / NNAPI）
  bool _useGpuDelegate = false;
  bool _useNnApi = false;

  /// 最近一次推理耗时（毫秒），用于性能监控
  double _lastInferenceMs = 0;

  // ---- 回调 ----
  /// 完成一次动作时触发
  Function(int count, String exercise)? onRepDetected;

  /// 反馈消息（姿势纠正、鼓励等）
  Function(String feedback)? onFeedback;

  /// 运动强度更新（0.0 - 1.0），用于 UI 强度条
  Function(double level)? onMotionUpdate;

  // ---- Getter ----
  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isDetecting => _isDetecting;
  int get repCount => _repCount;
  String get currentExercise => _currentExercise;
  double get lastInferenceMs => _lastInferenceMs;
  bool get modelLoaded => _interpreter != null;

  /// 配置硬件加速。需要在 [initialize] 之前调用。
  ///
  /// - [useGpu]: 启用 GPU delegate（需要 FP16 模型）
  /// - [useNnApi]: 启用 Android NNAPI（Android 10+）
  void configure({bool useGpu = false, bool useNnApi = false}) {
    _useGpuDelegate = useGpu;
    _useNnApi = useNnApi;
  }

  /// 初始化摄像头与 TFLite 模型
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. 加载模型（即使摄像头不可用也允许加载模型做单帧推理）
    await _loadModel();

    // 2. 初始化摄像头
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        // 没有摄像头不抛出，允许仅模型推理模式
        return;
      }

      final frontCamera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      _isInitialized = true;
    } catch (_) {
      // 摄像头初始化失败不阻断，模型仍可用
      _isInitialized = _interpreter != null;
    }
  }

  /// 从 assets 加载 MoveNet tflite 模型
  Future<void> _loadModel() async {
    try {
      final options = InterpreterOptions();

      if (_useNnApi) {
        // Android NNAPI：在支持 NPU/DSP 的设备上加速
        options.useNnApiForAndroid = true;
      }

      // GPU delegate 需引入 tflite_flutter_gpu 包后启用：
      //   if (_useGpuDelegate) {
      //     options.addDelegate(GpuDelegateV2());
      //   }
      // 当前版本仅支持 CPU + NNAPI，保持零额外原生依赖
      if (_useGpuDelegate) {
        // TODO: 添加 GPU delegate 支持（需 tflite_flutter_gpu 依赖）
      }

      _interpreter = await Interpreter.fromAsset(
        kModelAsset,
        options: options,
      );
    } on FileSystemException {
      // 模型文件缺失：降级为无模型模式，后续推理会被跳过
      _interpreter = null;
    } catch (_) {
      _interpreter = null;
    }
  }

  /// 开始检测指定运动
  ///
  /// [exerciseType] 取值：'pushup' / 'squat' / 'jumping_jack' / 'running' 等
  Future<void> startDetection(String exerciseType) async {
    if (!_isInitialized) return;

    _currentExercise = exerciseType;
    _repCount = 0;
    _motionState = 'idle';
    _lastRepTime = DateTime.now();
    _poseBuffer.clear();
    _isDetecting = true;

    if (_controller != null && !_controller!.value.isStreamingImages) {
      await _controller!.startImageStream(_processCameraImage);
    }
  }

  /// 停止检测
  Future<void> stopDetection() async {
    _isDetecting = false;

    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
    _poseBuffer.clear();
  }

  /// 处理摄像头每一帧
  void _processCameraImage(CameraImage image) {
    if (!_isDetecting || _interpreter == null) return;
    if (_isProcessing) return; // 上一帧还在推理，跳过

    _frameCounter++;
    if (_frameCounter < _frameSkip) return;
    _frameCounter = 0;

    _isProcessing = true;
    try {
      final stopwatch = Stopwatch()..start();

      // 1. YUV420 → RGB → resize 到 192x192
      final inputBuffer = _preprocessCameraImage(image);

      // 2. 运行推理
      final pose = _runInference(inputBuffer);

      stopwatch.stop();
      _lastInferenceMs = stopwatch.elapsedMilliseconds.toDouble();

      // 3. 处理关键点
      if (pose != null) {
        _poseBuffer.add(pose);
        if (_poseBuffer.length > _kBufferSize) {
          _poseBuffer.removeAt(0);
        }

        // 4. 计算运动强度并回调
        final motionLevel = _calculateMotionLevel();
        onMotionUpdate?.call(motionLevel);

        // 5. 分类动作并计数
        _analyzeExercise(pose);
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// 将 CameraImage (YUV420) 预处理为模型输入
  ///
  /// 输出：Int32List，长度 = 1 * 192 * 192 * 3，每个 int 为 0-255 的 RGB 像素值
  Int32List _preprocessCameraImage(CameraImage image) {
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

    // 输出 buffer：192*192*3 个 int32
    final output = Int32List(kInputSize * kInputSize * 3);

    // 水平镜像（前置摄像头预览需要镜像）
    for (int dy = 0; dy < kInputSize; dy++) {
      final srcY = (dy * height ~/ kInputSize).clamp(0, height - 1);
      for (int dx = 0; dx < kInputSize; dx++) {
        // 镜像 X
        final srcX = (dx * width ~/ kInputSize).clamp(0, width - 1);
        final mirrorX = width - 1 - srcX;

        final yIdx = srcY * yRowStride + mirrorX;
        final uvX = mirrorX ~/ 2;
        final uvY = srcY ~/ 2;
        final uIdx = uvY * uRowStride + uvX;
        final vIdx = uvY * vRowStride + uvX;

        final yVal = (yIdx < yBytes.length) ? (yBytes[yIdx] & 0xFF) : 0;
        final uVal = (uIdx < uBytes.length) ? (uBytes[uIdx] & 0xFF) : 128;
        final vVal = (vIdx < vBytes.length) ? (vBytes[vIdx] & 0xFF) : 128;

        // YUV → RGB (BT.601)
        final r = (yVal + 1.402 * (vVal - 128)).round().clamp(0, 255);
        final g =
            (yVal - 0.344 * (uVal - 128) - 0.714 * (vVal - 128))
                .round()
                .clamp(0, 255);
        final b = (yVal + 1.772 * (uVal - 128)).round().clamp(0, 255);

        final outIdx = (dy * kInputSize + dx) * 3;
        output[outIdx] = r;
        output[outIdx + 1] = g;
        output[outIdx + 2] = b;
      }
    }

    return output;
  }

  /// 运行 MoveNet 推理
  ///
  /// 返回 17 个关键点，每个为 [y, x, confidence]（归一化到 0-1）
  Pose? _runInference(Int32List inputBuffer) {
    if (_interpreter == null) return null;

    try {
      // 输入 shape: [1, 192, 192, 3] int32
      // 输出 shape: [1, 1, 17, 3] float32
      final output = List<List<List<List<double>>>>.generate(
        1,
        (_) => List<List<List<double>>>.generate(
          1,
          (_) => List<List<double>>.generate(
            kKeypointCount,
            (_) => List<double>.filled(3, 0.0),
          ),
        ),
      );

      // 将 Int32List reshape 为模型期望的嵌套 List
      // 性能优化：直接用 ByteBuffer 会更快，但需要处理 shape 映射
      final input = _reshapeInput(inputBuffer);

      _interpreter!.run(input, output);

      // 解析输出
      final keypoints = <Keypoint>[];
      for (int i = 0; i < kKeypointCount; i++) {
        final y = output[0][0][i][0];
        final x = output[0][0][i][1];
        final conf = output[0][0][i][2];
        keypoints.add(Keypoint(
          x: x,
          y: y,
          confidence: conf,
        ));
      }

      return Pose(keypoints: keypoints);
    } catch (_) {
      return null;
    }
  }

  /// 将一维 Int32List reshape 为 [1, 192, 192, 3]
  List<List<List<List<int>>>> _reshapeInput(Int32List buffer) {
    final result = List<List<List<List<int>>>>.generate(
      1,
      (_) => List<List<List<int>>>.generate(
        kInputSize,
        (y) => List<List<int>>.generate(
          kInputSize,
          (x) {
            final idx = (y * kInputSize + x) * 3;
            return [buffer[idx], buffer[idx + 1], buffer[idx + 2]];
          },
        ),
      ),
    );
    return result;
  }

  /// 计算运动强度（基于关键点帧间位移）
  double _calculateMotionLevel() {
    if (_poseBuffer.length < 2) return 0.0;

    final prev = _poseBuffer[_poseBuffer.length - 2];
    final curr = _poseBuffer[_poseBuffer.length - 1];

    double totalMovement = 0;
    int validCount = 0;

    for (int i = 0; i < kKeypointCount; i++) {
      final p = prev.keypoints[i];
      final c = curr.keypoints[i];
      if (p.confidence > _kMinConfidence && c.confidence > _kMinConfidence) {
        final dx = c.x - p.x;
        final dy = c.y - p.y;
        totalMovement += math.sqrt(dx * dx + dy * dy);
        validCount++;
      }
    }

    if (validCount == 0) return 0.0;

    final avgMovement = totalMovement / validCount;
    // 归一化到 0-1（经验值：每帧平均位移 0.05 约为高强度）
    return (avgMovement / 0.05).clamp(0.0, 1.0);
  }

  /// 根据当前运动类型分发到对应检测器
  void _analyzeExercise(Pose pose) {
    switch (_currentExercise) {
      case 'pushup':
        _detectPushup(pose);
        break;
      case 'squat':
        _detectSquat(pose);
        break;
      case 'jumping_jack':
        _detectJumpingJack(pose);
        break;
      case 'running':
        _detectRunning(pose);
        break;
      case 'walking':
        _detectWalking(pose);
        break;
      default:
        _detectGeneric(pose);
    }
  }

  /// 检测俯卧撑
  ///
  /// 关键指标：肘关节角度（shoulder-elbow-wrist）
  /// - 'down' 状态：肘部弯曲 < 90°
  /// - 'up' 状态：肘部伸直 > 150°
  void _detectPushup(Pose pose) {
    final lShoulder = pose.keypoints[kLeftShoulder];
    final lElbow = pose.keypoints[kLeftElbow];
    final lWrist = pose.keypoints[kLeftWrist];
    final rShoulder = pose.keypoints[kRightShoulder];
    final rElbow = pose.keypoints[kRightElbow];
    final rWrist = pose.keypoints[kRightWrist];

    // 选取置信度更高的一侧
    final lConf = (lShoulder.confidence + lElbow.confidence + lWrist.confidence) / 3;
    final rConf = (rShoulder.confidence + rElbow.confidence + rWrist.confidence) / 3;

    final shoulder = lConf > rConf ? lShoulder : rShoulder;
    final elbow = lConf > rConf ? lElbow : rElbow;
    final wrist = lConf > rConf ? lWrist : rWrist;

    if (shoulder.confidence < _kMinConfidence ||
        elbow.confidence < _kMinConfidence ||
        wrist.confidence < _kMinConfidence) {
      return;
    }

    final angle = _angleAtPoint(shoulder, elbow, wrist);

    String newState = _motionState;
    if (angle < 90) {
      newState = 'down';
    } else if (angle > 150) {
      newState = 'up';
    }

    // 完成一次：down → up
    if (_motionState == 'down' && newState == 'up') {
      _triggerRep('俯卧撑');
    }

    _motionState = newState;

    // 反馈
    if (angle > 90 && angle < 120 && _motionState == 'down') {
      onFeedback?.call('再低一点，胸部靠近地面~');
    }
  }

  /// 检测深蹲
  ///
  /// 关键指标：髋关节 Y 与膝关节 Y 的相对位置
  /// - 'down' 状态：髋部接近膝盖（髋膝垂直距离 / 躯干长度 < 0.3）
  /// - 'up' 状态：髋部明显高于膝盖（> 0.6）
  void _detectSquat(Pose pose) {
    final lHip = pose.keypoints[kLeftHip];
    final rHip = pose.keypoints[kRightHip];
    final lKnee = pose.keypoints[kLeftKnee];
    final rKnee = pose.keypoints[kRightKnee];
    final lShoulder = pose.keypoints[kLeftShoulder];
    final rShoulder = pose.keypoints[kRightShoulder];

    final hip = _avgKeypoint(lHip, rHip);
    final knee = _avgKeypoint(lKnee, rKnee);
    final shoulder = _avgKeypoint(lShoulder, rShoulder);

    if (hip == null || knee == null || shoulder == null) return;
    if (hip.confidence < _kMinConfidence ||
        knee.confidence < _kMinConfidence ||
        shoulder.confidence < _kMinConfidence) {
      return;
    }

    // 躯干长度（肩到髋），用于归一化
    final torsoLen = _distance(shoulder, hip);
    if (torsoLen < 0.01) return;

    // 髋膝垂直距离（图像坐标 Y 越大越靠下）
    final hipKneeDist = (hip.y - knee.y).abs();
    final normalizedDepth = hipKneeDist / torsoLen;

    String newState = _motionState;
    if (normalizedDepth < 0.3) {
      newState = 'down';
    } else if (normalizedDepth > 0.6) {
      newState = 'up';
    }

    if (_motionState == 'down' && newState == 'up') {
      _triggerRep('深蹲');
    }

    _motionState = newState;

    // 反馈
    if (normalizedDepth > 0.3 && normalizedDepth < 0.5) {
      onFeedback?.call('蹲得再深一点~');
    }
  }

  /// 检测开合跳
  ///
  /// 关键指标：手腕 Y 与肩 Y 的相对位置
  /// - 'jump' 状态：手腕高于肩膀（y < shoulderY）
  /// - 'land' 状态：手腕低于肩膀（y > shoulderY）
  void _detectJumpingJack(Pose pose) {
    final lWrist = pose.keypoints[kLeftWrist];
    final rWrist = pose.keypoints[kRightWrist];
    final lShoulder = pose.keypoints[kLeftShoulder];
    final rShoulder = pose.keypoints[kRightShoulder];

    if (lWrist.confidence < _kMinConfidence ||
        rWrist.confidence < _kMinConfidence ||
        lShoulder.confidence < _kMinConfidence ||
        rShoulder.confidence < _kMinConfidence) {
      return;
    }

    // 双手都高于肩 → jump
    final bothArmsUp =
        lWrist.y < lShoulder.y && rWrist.y < rShoulder.y;
    // 双手都低于肩 → land
    final bothArmsDown =
        lWrist.y > lShoulder.y && rWrist.y > rShoulder.y;

    String newState = _motionState;
    if (bothArmsUp) {
      newState = 'jump';
    } else if (bothArmsDown) {
      newState = 'land';
    }

    if (_motionState == 'jump' && newState == 'land') {
      _triggerRep('开合跳');
    }

    _motionState = newState;
  }

  /// 检测跑步（基于膝盖交替抬起的频率）
  void _detectRunning(Pose pose) {
    final lKnee = pose.keypoints[kLeftKnee];
    final rKnee = pose.keypoints[kRightKnee];
    final lHip = pose.keypoints[kLeftHip];
    final rHip = pose.keypoints[kRightHip];

    if (lKnee.confidence < _kMinConfidence ||
        rKnee.confidence < _kMinConfidence ||
        lHip.confidence < _kMinConfidence ||
        rHip.confidence < _kMinConfidence) {
      return;
    }

    // 检测膝盖是否高于髋部（抬起）
    final lKneeUp = lKnee.y < lHip.y;
    final rKneeUp = rKnee.y < rHip.y;

    // 左右膝交替抬起算一步
    if ((lKneeUp && _motionState == 'right') ||
        (rKneeUp && _motionState == 'left')) {
      _repCount++;
      _motionState = lKneeUp ? 'left' : 'right';
      _lastRepTime = DateTime.now();

      if (_repCount % 10 == 0) {
        onRepDetected?.call(_repCount, '跑步');
        onFeedback?.call('$_repCount 步！继续跑~');
      }
    } else if (lKneeUp) {
      _motionState = 'left';
    } else if (rKneeUp) {
      _motionState = 'right';
    }
  }

  /// 检测快走（与跑步类似，但阈值更低）
  void _detectWalking(Pose pose) {
    _detectRunning(pose); // 逻辑相同，仅在反馈文案上有差别
    if (_repCount > 0 && _repCount % 20 == 0) {
      onFeedback?.call('$_repCount 步！');
    }
  }

  /// 通用动作检测（使用运动强度）
  void _detectGeneric(Pose pose) {
    final motionLevel = _calculateMotionLevel();
    final now = DateTime.now();
    final debounceOK = now.difference(_lastRepTime).inMilliseconds > 800;

    if (motionLevel > 0.3 && _motionState == 'idle' && debounceOK) {
      _motionState = 'active';
    } else if (motionLevel < 0.1 && _motionState == 'active') {
      _motionState = 'idle';
      _repCount++;
      _lastRepTime = now;
      onRepDetected?.call(_repCount, _getExerciseName());
      onFeedback?.call(_getFeedbackMessage());
    }
  }

  /// 触发一次动作完成
  void _triggerRep(String exerciseName) {
    final now = DateTime.now();
    if (now.difference(_lastRepTime).inMilliseconds < _debounceMs) return;

    _repCount++;
    _lastRepTime = now;
    onRepDetected?.call(_repCount, exerciseName);
    onFeedback?.call(_getFeedbackMessage());
  }

  String _getExerciseName() {
    switch (_currentExercise) {
      case 'pushup':
        return '俯卧撑';
      case 'squat':
        return '深蹲';
      case 'jumping_jack':
        return '开合跳';
      case 'running':
        return '跑步';
      case 'walking':
        return '快走';
      case 'cycling':
        return '骑行';
      case 'swimming':
        return '游泳';
      case 'yoga':
        return '瑜伽';
      case 'hiit':
        return 'HIIT';
      case 'jumprope':
        return '跳绳';
      case 'strength':
        return '力量训练';
      default:
        return '运动';
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
    return '$_repCount 个！${messages[_repCount % messages.length]}';
  }

  // ---- 几何工具方法 ----

  /// 计算点 B 处的夹角（A-B-C）
  double _angleAtPoint(Keypoint a, Keypoint b, Keypoint c) {
    final radians = math.atan2(c.y - b.y, c.x - b.x) -
        math.atan2(a.y - b.y, a.x - b.x);
    var angle = (radians.abs() * 180 / math.pi);
    if (angle > 180) angle = 360 - angle;
    return angle;
  }

  /// 两点距离
  double _distance(Keypoint a, Keypoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// 求两个关键点的中点（仅当都有效时返回）
  Keypoint? _avgKeypoint(Keypoint a, Keypoint b) {
    if (a.confidence < _kMinConfidence && b.confidence < _kMinConfidence) {
      return null;
    }
    if (a.confidence < _kMinConfidence) return b;
    if (b.confidence < _kMinConfidence) return a;
    return Keypoint(
      x: (a.x + b.x) / 2,
      y: (a.y + b.y) / 2,
      confidence: (a.confidence + b.confidence) / 2,
    );
  }

  /// 设置灵敏度（0.0 = 高灵敏度短防抖，1.0 = 低灵敏度长防抖）
  void setSensitivity(double sensitivity) {
    _debounceMs = (200 + sensitivity * 800).round().clamp(200, 1000);
  }

  /// 释放资源
  Future<void> dispose() async {
    await stopDetection();
    _interpreter?.close();
    _interpreter = null;
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _poseBuffer.clear();
  }
}

/// 单个关键点
class Keypoint {
  /// X 坐标，归一化到 [0, 1]（相对于输入图像宽度）
  final double x;

  /// Y 坐标，归一化到 [0, 1]（相对于输入图像高度）
  final double y;

  /// 置信度 [0, 1]
  final double confidence;

  const Keypoint({
    required this.x,
    required this.y,
    required this.confidence,
  });

  @override
  String toString() =>
      'Keypoint(x: ${x.toStringAsFixed(3)}, y: ${y.toStringAsFixed(3)}, conf: ${confidence.toStringAsFixed(3)})';
}

/// 一帧姿态（17 个关键点）
class Pose {
  final List<Keypoint> keypoints;

  const Pose({required this.keypoints});

  /// 整体置信度（所有关键点置信度的平均值）
  double get averageConfidence {
    if (keypoints.isEmpty) return 0;
    var sum = 0.0;
    for (final kp in keypoints) {
      sum += kp.confidence;
    }
    return sum / keypoints.length;
  }

  /// 是否有效（核心关键点置信度足够）
  bool get isValid {
    final core = [
      5, 6, 11, 12, 13, 14, 15, 16, // shoulders, hips, knees, ankles
    ];
    for (final idx in core) {
      if (keypoints[idx].confidence < 0.3) return false;
    }
    return true;
  }
}
