import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../theme/forge_theme.dart';
import '../theme/forge_routes.dart';
import '../theme/tokens.dart';
import '../theme/app_icons.dart';
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
import '../services/exercise_prescription.dart';
import '../services/coach_cues.dart';
import '../services/coach_feel.dart';
import '../services/coach_injury.dart';
import '../services/coach_lesson.dart';
import '../services/coach_settlement.dart';
import '../services/pose_coach_diary.dart';
import '../services/pose_coach_voice.dart';
import '../services/training_session_store.dart';
import '../widgets/exercise/pose_overlay.dart';
import '../widgets/exercise/pose_coach_guide.dart';
import '../widgets/forge_pressable.dart';
import '../widgets/home/forge_background.dart';
import '../widgets/home/mini_monster_header.dart';
import 'package:gal/gal.dart';
import 'pose_coach_page.dart';

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
  String _cameraEngine = 'mlkit'; // 修复 ML Kit；不再默认跳过到 TFLite
  bool _cameraBleFusion = false;
  WorkoutFocus _workoutFocus = WorkoutFocus.mixed;
  WorkoutPlan? _recommendedPlan;

  /// 连续训练进度：-1 未在连训；>=0 当前进行到组合内第几个动作
  int _planSeqIndex = -1;

  /// 用户按「结束」时是否中止连训（达标自动完成则为 false）
  bool _abortPlanOnStop = true;

  /// 本式已达标、正在结算（防重复触发）
  bool _planTargetHit = false;

  /// 结算后待推进下一式（等教练页 pop 完成再休息/开练）
  bool _pendingPlanAdvance = false;

  final PoseCoachVoice _coachVoice = PoseCoachVoice();
  final TrainingSessionStore _sessionStore = TrainingSessionStore();
  TrainingSession? _resumableSession;
  int _sessionBonusSeconds = 0;
  String? _lastCoachPhaseForVoice;
  String? _lastFormTipForVoice;

  /// 精彩瞬间截屏节流（避免连击时疯狂截图）
  DateTime _lastHighlightCapture = DateTime.fromMillisecondsSinceEpoch(0);

  /// 本课累计（连训跨式）供结算
  int _sessionCal = 0;
  int _sessionReps = 0;
  int _qualitySum = 0;
  int _qualityCount = 0;
  int _peakCombo = 0;
  String _lastGrade = 'D';
  String? _sessionExerciseType;
  bool _returnToBattle = false;
  final ValueNotifier<String> _qualityGradeN = ValueNotifier('');

  final ValueNotifier<int> _restCountdownN = ValueNotifier(0);
  final ValueNotifier<bool> _coachExternalCompleteN = ValueNotifier(false);
  Timer? _restTimer;
  
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

  /// 教练页实时数据桥
  final ValueNotifier<Map<String, Map<String, double>>?> _landmarksN =
      ValueNotifier(null);
  final ValueNotifier<String> _feedbackN = ValueNotifier('准备开始');
  final ValueNotifier<int> _repCountN = ValueNotifier(0);
  final ValueNotifier<String> _countUnitN = ValueNotifier('次');
  final ValueNotifier<int> _comboN = ValueNotifier(0);
  final ValueNotifier<double> _staminaN =
      ValueNotifier(ExerciseGameLogic.maxStamina);
  final ValueNotifier<bool> _pausedN = ValueNotifier(false);
  final ValueNotifier<bool> _preparingN = ValueNotifier(false);
  final ValueNotifier<double> _prepareProgressN = ValueNotifier(0);
  bool _coachPageOpen = false;

  /// 免触控开练阶段：setup → align → countdown → active
  final ValueNotifier<String> _coachPhaseN = ValueNotifier('setup');
  final ValueNotifier<String> _coachPhaseHintN =
      ValueNotifier('请架好手机，走到运动位置');
  final ValueNotifier<int> _coachCountdownN = ValueNotifier(0);
  DateTime? _handsFreeSessionStart;
  DateTime? _alignGoodSince;
  DateTime? _countdownStartedAt;
  Timer? _setupGraceTimer;
  static const int _setupGraceSec = 8;
  static const int _alignHoldMs = 2800;
  static const int _countdownSec = 3;
  static const double _alignThreshold = 0.62;

  TextStyle get _displayStyle => AppFonts.display(
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      );

  TextStyle get _bodyStyle => AppFonts.body(color: AppColors.text);

  TextStyle get _mutedStyle =>
      AppFonts.body(color: AppColors.text2, fontSize: 13);
  
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
          _repCountN.value = count;
        });
        _maybeCompletePlanTarget(count);
      }
    };
    _fusionService.onFeedback = (feedback) {
      if (_cameraBleFusion && mounted) {
        setState(() {
          _cameraFeedback = feedback;
          _feedbackN.value = feedback;
        });
      }
    };

    // 游戏逻辑回调
    _gameLogic.onComboChanged = (combo, multiplier) {
      _comboN.value = combo;
      if (combo > _peakCombo) _peakCombo = combo;
      if (mounted) setState(() {});
    };
    _gameLogic.onStaminaChanged = (stamina, depleted) {
      _staminaN.value = stamina;
      if (mounted) setState(() {});
    };
    _gameLogic.onPauseChanged = (paused) {
      _pausedN.value = paused;
      if (paused) {
        _coachVoice.announcePause();
      } else {
        _coachVoice.announceResume();
      }
      if (mounted) setState(() {});
    };
    _gameLogic.onPrepareProgress = (progress) {
      _prepareProgressN.value = progress;
      _preparingN.value = _gameLogic.isPreparing;
      if (mounted) setState(() {});
    };
    _gameLogic.onQualityScored = (quality, grade) {
      _qualitySum += quality;
      _qualityCount += 1;
      _lastGrade = grade;
      _qualityGradeN.value = grade;
      if (mounted) {
        setState(() {
          _cameraFeedback = '⭐ $grade (${quality}分) $_cameraFeedback';
          _feedbackN.value = _cameraFeedback;
        });
      }
    };

    _coachPhaseN.addListener(_onCoachPhaseVoice);
    // ignore: discarded_futures
    _refreshResumableSession();
    // ignore: discarded_futures
    _coachVoice.ensureReady();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyTodayLesson(silent: true);
    });
  }

  void _syncCoachVoiceEnabled() {
    try {
      final enabled = ref.read(gameStateProvider).voiceEnabled;
      _coachVoice.setEnabled(enabled);
    } catch (_) {
      _coachVoice.setEnabled(true);
    }
  }

  Future<void> _refreshResumableSession() async {
    final s = await _sessionStore.loadSession();
    if (!mounted) return;
    setState(() => _resumableSession = s);
  }

  void _onCoachPhaseVoice() {
    final phase = _coachPhaseN.value;
    if (phase == _lastCoachPhaseForVoice) return;
    _lastCoachPhaseForVoice = phase;
    switch (phase) {
      case 'setup':
        _coachVoice.announceSetup();
        break;
      case 'align':
        _coachVoice.announceAlign();
        break;
      case 'countdown':
        break;
      case 'active':
        final name = _selectedExercise != null
            ? Exercises.all[_selectedExercise!].name
            : null;
        _coachVoice.announceStartCounting(exerciseName: name);
        break;
    }
  }

  void _wireCameraCallbacks(dynamic detector) {
    detector.onRepDetected = (count, exercise) {
      if (!mounted || !_isActiveCamera(detector)) return;
      // 入镜门控未进入 active 前丢弃计次（防 TFLite / 误触发）
      if (_cameraDetecting && _coachPhaseN.value != 'active') return;
      if (_cameraBleFusion) {
        _fusionService.updateCameraResult(
          exerciseType: exercise,
          repCount: count,
          accuracy: 0.85,
        );
      } else {
        setState(() {
          _cameraRepCount = count;
          _repCountN.value = count;
        });
      }
      // 平板按秒累计：不要每秒都抽体力，否则十几秒就「耗尽」
      final type = _selectedExercise != null
          ? Exercises.all[_selectedExercise!].type
          : '';
      if (type != 'plank') {
        _gameLogic.handleRepSuccess();
        _coachVoice.announceRep(count); // 每次都报
      } else if (count > 0) {
        if (count % 5 == 0) _gameLogic.handleRepSuccess();
        _coachVoice.announceRep(count); // 平板也每次报秒/次
      }
      _maybeCompletePlanTarget(count);
    };
    detector.onFeedback = (feedback) {
      if (!mounted || !_isActiveCamera(detector)) return;
      // 门控阶段用大字提示，避免检测反馈抢话
      if (_cameraDetecting && _coachPhaseN.value != 'active') return;
      setState(() {
        _cameraFeedback = feedback;
        _feedbackN.value = feedback;
      });
      // 远场：屏幕纠错必须同时播出口令
      _speakDetectorCue(feedback);
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
          setState(() {
            _currentLandmarks = null;
            _landmarksN.value = null;
          });
          _onHandsFreePose(null);
          return;
        }
        final converted = <String, Map<String, double>>{};
        landmarks.forEach((type, pt) {
          converted[type.name] = {'x': pt.x, 'y': pt.y, 'z': pt.z};
        });
        setState(() {
          _currentLandmarks = converted;
          _landmarksN.value = converted;
        });
        _onHandsFreePose(converted);
      };
      // 人丢失自动暂停 → HUD「已暂停」+ 语音（此前未接线）
      detector.onPauseChanged = (paused) {
        if (!mounted || !_isActiveCamera(detector)) return;
        _pausedN.value = paused;
        _gameLogic.isPaused = paused;
        if (paused) {
          _coachVoice.announcePause();
        } else {
          _coachVoice.announceResume();
        }
        setState(() {});
      };
    } else if (detector is TfliteMotionService) {
      detector.onPoseUpdate = (landmarks) {
        if (!_isActiveCamera(detector) || !mounted) return;
        setState(() {
          _currentLandmarks = landmarks;
          _landmarksN.value = landmarks;
        });
        _onHandsFreePose(landmarks);
      };
    }
  }

  /// 免触控门控：架设宽限 → 入镜稳住 → 3-2-1 → 才开始计次
  void _resetHandsFreeGate() {
    _handsFreeSessionStart = DateTime.now();
    _alignGoodSince = null;
    _countdownStartedAt = null;
    PoseCoachDiary.instance.logPhase('-', 'setup', 'reset_gate');
    _coachPhaseN.value = 'setup';
    _coachPhaseHintN.value = '请把手机架稳，然后走到镜头前';
    _coachCountdownN.value = 0;
    _preparingN.value = true;
    _prepareProgressN.value = 0;
    if (_activeCameraDetector is PoseDetectionService) {
      (_activeCameraDetector as PoseDetectionService).setCountingEnabled(false);
    }
    _setupGraceTimer?.cancel();
    // 即使画面无人，也按时从「架设」进入「入镜」，避免卡死
    _setupGraceTimer = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (!mounted || !_cameraDetecting) {
        t.cancel();
        return;
      }
      if (_coachPhaseN.value != 'setup') {
        t.cancel();
        return;
      }
      final start = _handsFreeSessionStart ?? DateTime.now();
      final elapsed = DateTime.now().difference(start);
      _prepareProgressN.value =
          (elapsed.inMilliseconds / (_setupGraceSec * 1000)).clamp(0.0, 1.0);
      final left =
          (_setupGraceSec - elapsed.inSeconds).clamp(0, _setupGraceSec);
      _coachPhaseHintN.value = left > 0
          ? '请架好手机并走到白框位置（$left）'
          : '请站进白色虚线框，全身入镜';
      if (elapsed.inSeconds >= _setupGraceSec) {
        t.cancel();
        PoseCoachDiary.instance.logPhase('setup', 'align', 'grace_done');
        _coachPhaseN.value = 'align';
        _alignGoodSince = null;
        _coachPhaseHintN.value = '请正对手机，全身入镜，站稳准备';
        _prepareProgressN.value = 0;
      }
    });
  }

  void _onHandsFreePose(Map<String, Map<String, double>>? landmarks) {
    if (!_cameraDetecting || _planTargetHit) return;
    if (_coachPhaseN.value == 'active') {
      _watchActiveFraming(landmarks);
      // active 阶段降频记一条心跳，确认仍有关键点
      if (landmarks != null && landmarks.isNotEmpty) {
        PoseCoachDiary.instance.logPoseFrame(
          phase: 'active',
          keypointCount: landmarks.length,
          alignment: 1,
          tooClose: false,
          hint: 'counting',
          sample: _diarySample(landmarks),
        );
      }
      return;
    }

    final now = DateTime.now();
    final isPortrait =
        MediaQuery.maybeOf(context)?.orientation == Orientation.portrait;
    final exerciseType = _selectedExercise != null
        ? Exercises.all[_selectedExercise!].type
        : 'squat';
    final phase = _coachPhaseN.value;

    // Phase 1: 架设宽限——给人离开手机、摆姿势的时间，绝不自动开练
    if (phase == 'setup') {
      PoseCoachDiary.instance.logPoseFrame(
        phase: 'setup',
        keypointCount: landmarks?.length ?? 0,
        alignment: 0,
        tooClose: false,
        hint: _coachPhaseHintN.value,
        sample: landmarks == null ? 'null' : _diarySample(landmarks),
      );
      return;
    }

    // Phase 2: 入镜对齐
    if (phase == 'align') {
      if (landmarks == null || landmarks.isEmpty) {
        _alignGoodSince = null;
        _coachPhaseHintN.value = '未检测到人，请走进画面';
        _prepareProgressN.value = 0;
        PoseCoachDiary.instance.logPoseFrame(
          phase: 'align',
          keypointCount: 0,
          alignment: 0,
          tooClose: false,
          hint: 'no_person',
          sample: 'null',
        );
        return;
      }
      final tooClose = _isPersonTooClose(landmarks);
      if (tooClose) {
        _alignGoodSince = null;
        _coachPhaseHintN.value = '太近了，请再退后几步';
        _prepareProgressN.value = 0;
        _announceFormTipOnce('too_close');
        PoseCoachDiary.instance.logPoseFrame(
          phase: 'align',
          keypointCount: landmarks.length,
          alignment: 0,
          tooClose: true,
          hint: 'too_close',
          sample: _diarySample(landmarks),
        );
        return;
      }
      final score = PoseCoachGuideMath.alignmentScore(
        exerciseType: exerciseType,
        landmarks: landmarks,
        isPortrait: isPortrait ?? true,
      );
      if (score >= _alignThreshold) {
        _alignGoodSince ??= now;
        final held = now.difference(_alignGoodSince!).inMilliseconds;
        _prepareProgressN.value = (held / _alignHoldMs).clamp(0.0, 1.0);
        _coachPhaseHintN.value = held >= _alignHoldMs
            ? '入镜成功'
            : '保持姿势，即将开始…';
        PoseCoachDiary.instance.logPoseFrame(
          phase: 'align',
          keypointCount: landmarks.length,
          alignment: score,
          tooClose: false,
          hint: 'holding_${held}ms',
          sample: _diarySample(landmarks),
        );
        if (held >= _alignHoldMs) {
          PoseCoachDiary.instance.logPhase('align', 'countdown', 'score=$score');
          _coachPhaseN.value = 'countdown';
          _countdownStartedAt = now;
          _coachCountdownN.value = _countdownSec;
          _coachPhaseHintN.value = '准备开始';
          _feedbackN.value = '$_countdownSec';
        }
      } else {
        _alignGoodSince = null;
        _prepareProgressN.value = score.clamp(0.0, 1.0);
        _coachPhaseHintN.value = score < 0.25
            ? '请全身进入画面'
            : '再调整站位，站稳对准手机';
        PoseCoachDiary.instance.logPoseFrame(
          phase: 'align',
          keypointCount: landmarks.length,
          alignment: score,
          tooClose: false,
          hint: score < 0.25 ? 'out_of_frame' : 'adjusting',
          sample: _diarySample(landmarks),
        );
        _announceFormTipOnce(score < 0.25 ? 'out_of_frame' : 'adjusting');
      }
      return;
    }

    // Phase 3: 倒计时 3-2-1
    if (phase == 'countdown') {
      if (landmarks != null && !_isPersonTooClose(landmarks)) {
        final score = PoseCoachGuideMath.alignmentScore(
          exerciseType: exerciseType,
          landmarks: landmarks,
          isPortrait: isPortrait ?? true,
        );
        PoseCoachDiary.instance.logPoseFrame(
          phase: 'countdown',
          keypointCount: landmarks.length,
          alignment: score,
          tooClose: false,
          hint: 'countdown',
          sample: _diarySample(landmarks),
        );
        if (score < 0.35) {
          PoseCoachDiary.instance.logPhase(
            'countdown',
            'align',
            'score=$score left_frame',
          );
          _coachPhaseN.value = 'align';
          _alignGoodSince = null;
          _countdownStartedAt = null;
          _coachCountdownN.value = 0;
          _coachPhaseHintN.value = '出画面了，请重新走进镜头';
          return;
        }
      } else {
        PoseCoachDiary.instance.logPoseFrame(
          phase: 'countdown',
          keypointCount: landmarks?.length ?? 0,
          alignment: 0,
          tooClose: landmarks != null && _isPersonTooClose(landmarks),
          hint: landmarks == null ? 'lost_person' : 'too_close',
          sample: landmarks == null ? 'null' : _diarySample(landmarks),
        );
      }
      final started = _countdownStartedAt ?? now;
      final elapsed = now.difference(started).inMilliseconds;
      final left =
          _countdownSec - (elapsed / 1000).floor();
      if (left > 0) {
        if (_coachCountdownN.value != left) {
          _coachVoice.announceCountdown(left);
        }
        _coachCountdownN.value = left;
        _feedbackN.value = '$left';
        _coachPhaseHintN.value = '不要动，马上开始';
        _prepareProgressN.value =
            (1 - left / _countdownSec).clamp(0.0, 1.0);
      } else {
        PoseCoachDiary.instance.logPhase('countdown', 'active', 'go');
        _coachPhaseN.value = 'active';
        _coachCountdownN.value = 0;
        _preparingN.value = false;
        _prepareProgressN.value = 1;
        _coachPhaseHintN.value = '开始锻炼！听口令做动作';
        _feedbackN.value = '开始！';
        if (_activeCameraDetector is PoseDetectionService) {
          (_activeCameraDetector as PoseDetectionService)
              .setCountingEnabled(true);
        }
      }
    }
  }

  String _diarySample(Map<String, Map<String, double>> landmarks) {
    String fmt(String key) {
      final p = landmarks[key];
      if (p == null) return '$key:-';
      return '$key=(${(p['x'] ?? 0).toStringAsFixed(2)},${(p['y'] ?? 0).toStringAsFixed(2)})';
    }

    return [
      fmt('nose'),
      fmt('leftShoulder'),
      fmt('rightShoulder'),
      fmt('leftAnkle'),
      fmt('rightAnkle'),
    ].join(' ');
  }

  /// 肩宽过大 ≈ 贴脸架设，避免误触发开练
  bool _isPersonTooClose(Map<String, Map<String, double>> landmarks) {
    final ls = landmarks['leftShoulder'];
    final rs = landmarks['rightShoulder'];
    if (ls != null && rs != null) {
      final w = ((ls['x'] ?? 0) - (rs['x'] ?? 0)).abs();
      // 坐标未对齐时肩宽易虚高；仅在极端值才判太近
      if (w > 0.72) return true;
    }
    final nose = landmarks['nose'];
    final la = landmarks['leftAnkle'];
    final ra = landmarks['rightAnkle'];
    if (nose != null && la != null && ra != null) {
      final ankleY = (((la['y'] ?? 0) + (ra['y'] ?? 0)) / 2);
      final h = (ankleY - (nose['y'] ?? 0)).abs();
      // 头到脚几乎占满画面且脚贴近底边 → 太近
      if (h > 0.95) return true;
    }
    return false;
  }

  bool _isActiveCamera(dynamic detector) {
    if (_cameraEngine == 'mlkit') return detector is PoseDetectionService;
    return detector is TfliteMotionService;
  }

  dynamic get _activeCameraDetector =>
      _cameraEngine == 'mlkit' ? _cameraDetector : _tfliteDetector;

  String get _cameraEngineLabel =>
      _cameraEngine == 'mlkit' ? 'ML Kit' : 'TFLite';
  
  void _announceFormTipOnce(String tip) {
    if (_lastFormTipForVoice == tip) return;
    _lastFormTipForVoice = tip;
    _coachVoice.announceFormTip(tip);
  }

  void _speakDetectorCue(String feedback) {
    final type = _selectedExercise != null
        ? Exercises.all[_selectedExercise!].type
        : '';
    final cue = resolveCoachCue(
      liveFeedback: feedback,
      exerciseType: type,
    );
    if (cue.kind == CoachCueKind.squatDepth) {
      if (_lastFormTipForVoice == 'squat_depth') {
        _coachVoice.announceLiveCue(feedback);
        return;
      }
      _lastFormTipForVoice = 'squat_depth';
      _coachVoice.announceDepthCue(exerciseType: type);
      return;
    }
    if (cue.kind == CoachCueKind.outOfFrame) {
      _announceFormTipOnce('out_of_frame');
      return;
    }
    if (cue.kind == CoachCueKind.tooClose) {
      _announceFormTipOnce('too_close');
      return;
    }
    if (cue.kind == CoachCueKind.tooFar) {
      _announceFormTipOnce('too_far');
      return;
    }
    _coachVoice.announceLiveCue(feedback);
  }

  /// 开练后继续盯出画 / 过近，口令复用门控同一套。
  void _watchActiveFraming(Map<String, Map<String, double>>? landmarks) {
    if (landmarks == null || landmarks.isEmpty) {
      _announceFormTipOnce('out_of_frame');
      return;
    }
    if (_isPersonTooClose(landmarks)) {
      _announceFormTipOnce('too_close');
      return;
    }
    final isPortrait =
        MediaQuery.maybeOf(context)?.orientation == Orientation.portrait;
    final exerciseType = _selectedExercise != null
        ? Exercises.all[_selectedExercise!].type
        : 'squat';
    final score = PoseCoachGuideMath.alignmentScore(
      exerciseType: exerciseType,
      landmarks: landmarks,
      isPortrait: isPortrait ?? true,
    );
    if (score < 0.22) {
      _announceFormTipOnce('out_of_frame');
    } else if (_lastFormTipForVoice == 'out_of_frame' ||
        _lastFormTipForVoice == 'too_close') {
      _lastFormTipForVoice = null;
    }
  }

  void _resetSessionStats({bool keepAccumulated = false}) {
    if (keepAccumulated) return;
    _sessionCal = 0;
    _sessionReps = 0;
    _qualitySum = 0;
    _qualityCount = 0;
    _peakCombo = 0;
    _lastGrade = 'D';
    _sessionExerciseType = null;
    _qualityGradeN.value = '';
  }

  int _currentBaseTarget() {
    if (_planSeqIndex >= 0) {
      return _recommendedPlan?.itemAt(_planSeqIndex)?.target ?? 0;
    }
    return 0;
  }

  bool _currentIsTimed() {
    if (_planSeqIndex >= 0) {
      return _recommendedPlan?.itemAt(_planSeqIndex)?.isTimed ?? false;
    }
    final i = _selectedExercise;
    if (i == null) return false;
    return Exercises.all[i].type == 'plank';
  }

  int _currentEffectiveTarget() {
    final base = _currentBaseTarget();
    if (base <= 0) return 0;
    if (_currentIsTimed()) return base + _sessionBonusSeconds;
    return base +
        (_sessionBonusSeconds ~/ TrainingSessionStore.secondsPerBonusRep);
  }

  WorkoutPlan _planFromSnapshot(TrainingPlanSnapshot snap) {
    return WorkoutPlan(
      items: snap.items
          .map(
            (i) => WorkoutPlanItem(
              exerciseIndex: i.exerciseIndex,
              target: i.target,
              isTimed: i.isTimed,
            ),
          )
          .toList(growable: false),
      title: snap.title,
      reason: '续训恢复',
      estimatedMinutes: 0,
      restSeconds: snap.restSeconds,
    );
  }

  TrainingPlanSnapshot? _snapshotFromPlan(WorkoutPlan? plan) {
    if (plan == null) return null;
    return TrainingPlanSnapshot(
      title: plan.title,
      restSeconds: plan.restSeconds,
      items: plan.items
          .map(
            (i) => TrainingPlanItemSnapshot(
              exerciseIndex: i.exerciseIndex,
              target: i.target,
              isTimed: i.isTimed,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _pauseAndSaveSession() async {
    if (_selectedExercise == null || _cameraStartTime == null) return;
    final exercise = Exercises.all[_selectedExercise!];
    final elapsed = DateTime.now().difference(_cameraStartTime!);
    final baseTarget = _currentBaseTarget();
    final session = TrainingSession(
      exerciseType: exercise.type,
      exerciseIndex: _selectedExercise!,
      exerciseName: exercise.name,
      planSeqIndex: _planSeqIndex,
      plan: _snapshotFromPlan(_recommendedPlan),
      repCount: _cameraRepCount,
      elapsedActiveSeconds: elapsed.inSeconds,
      pausedAt: DateTime.now(),
      bonusSeconds: _sessionBonusSeconds,
      target: baseTarget > 0 ? baseTarget : (_currentIsTimed() ? 30 : 15),
      isTimed: _currentIsTimed(),
    );
    await _sessionStore.saveSession(session);
    _coachVoice.announcePause();
    _abortPlanOnStop = false;
    await _stopCameraDetection(abortSequence: false, skipFinish: true);
    if (mounted) {
      setState(() {
        _resumableSession = session;
        _cameraStartTime = null;
        _cameraDetecting = false;
      });
      _showToast('已暂停并保存进度，可随时继续');
    }
  }

  Future<void> _resumeSavedSession() async {
    var session = await _sessionStore.loadSession();
    if (session == null) {
      _showToast('没有可继续的训练');
      return;
    }
    final pausedAt = session.pausedAt;
    final gapSec = pausedAt != null
        ? DateTime.now().difference(pausedAt).inSeconds
        : null;
    final beforeBonus = session.bonusSeconds;
    session = TrainingSessionStore.applyPauseBonus(session);
    final added = session.bonusSeconds - beforeBonus;
    _sessionBonusSeconds = session.bonusSeconds;
    if (session.plan != null) {
      _recommendedPlan = _planFromSnapshot(session.plan!);
      _planSeqIndex = session.planSeqIndex;
    } else {
      _planSeqIndex = -1;
    }
    setState(() {
      _selectedExercise = session!.exerciseIndex;
      _exerciseMode = 'camera';
      _cameraRepCount = session.repCount;
      _repCountN.value = session.repCount;
      _resumableSession = session;
    });
    _coachVoice.announceResumeAfterLongBreak(
      bonusSeconds: added > 0 ? added : session.bonusSeconds,
      gapSeconds: gapSec,
    );
    await _sessionStore.saveSession(session);
    await _startCameraDetection(seedReps: session.repCount);
  }

  @override
  void dispose() {
    _coachPhaseN.removeListener(_onCoachPhaseVoice);
    // ignore: discarded_futures
    _coachVoice.endSession();
    _restTimer?.cancel();
    _setupGraceTimer?.cancel();
    _restCountdownN.dispose();
    _coachExternalCompleteN.dispose();
    _logScrollController.dispose();
    _landmarksN.dispose();
    _feedbackN.dispose();
    _repCountN.dispose();
    _countUnitN.dispose();
    _comboN.dispose();
    _staminaN.dispose();
    _pausedN.dispose();
    _preparingN.dispose();
    _prepareProgressN.dispose();
    _coachPhaseN.dispose();
    _coachPhaseHintN.dispose();
    _coachCountdownN.dispose();
    _qualityGradeN.dispose();
    _cameraDetector.dispose();
    _tfliteDetector.dispose();
    _restoreAppOrientation();
    super.dispose();
  }

  Future<void> _enableSensorOrientations() async {
    // 跟随手机姿态：允许横/竖自由旋转
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _restoreAppOrientation() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // 退出教练后回到竖屏主导（列表页更合适）
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
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
        padding: AppSpace.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModeSelector(),
            const SizedBox(height: AppSpace.lg),
            
            // IMU模式显示BLE连接状态和检测界面
            if (_exerciseMode == 'imu') ...[
              _buildBleStatus(bleService, isConnected, imuDataAsync),
              const SizedBox(height: AppSpace.sm),
              Container(
                width: double.infinity,
                padding: AppSpace.card,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: AppRadii.smAll,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '💡 当前为纯 IMU（BLE）识别。摄像头+IMU 融合为可选功能，'
                  '可在「摄像头」模式中连接 BLE 后开启「IMU 融合」。',
                  style: _mutedStyle.copyWith(fontSize: 12),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              if (_isDetecting)
                _buildDetectionPanel(isConnected)
              else if (isConnected && _selectedExercise != null)
                _buildStartDetectionButton(),
            ],
            
            // 摄像头模式
            if (_exerciseMode == 'camera') ...[
              if (_resumableSession != null) ...[
                _sectionCard(
                  icon: Icons.play_circle_outline,
                  title: '未完成的训练',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${_resumableSession!.exerciseName}'
                        '${_resumableSession!.planSeqIndex >= 0 ? ' · 连训第${_resumableSession!.planSeqIndex + 1}式' : ''}'
                        ' · 已完成 ${_resumableSession!.repCount}'
                        '${_resumableSession!.isTimed ? '秒' : '次'}',
                        style: _bodyStyle,
                      ),
                      if (_resumableSession!.bonusSeconds > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '已累计暂停补偿 ${_resumableSession!.bonusSeconds} 秒',
                          style: _mutedStyle,
                        ),
                      ],
                      const SizedBox(height: AppSpace.md),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _cameraSettling || _cameraDetecting
                                  ? null
                                  : _resumeSavedSession,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('继续训练'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              await _sessionStore.clearSession();
                              if (!mounted) return;
                              setState(() {
                                _resumableSession = null;
                                _sessionBonusSeconds = 0;
                              });
                            },
                            child: const Text('放弃'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
              ],
              _buildCameraPanel(),
              const SizedBox(height: AppSpace.lg),
            ],
            
            // 运动选择
            _sectionCard(
              icon: Icons.fitness_center_outlined,
              title: _exerciseMode == 'camera' ? '摄像头可识别动作' : '选择运动',
              trailing: TextButton.icon(
                onPressed: () => _applyTodayLesson(),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: Text(
                  '今日克制课',
                  style: AppFonts.body(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.copper,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('锻炼偏好', style: _mutedStyle.copyWith(fontSize: 12)),
                  const SizedBox(height: AppSpace.sm),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: WorkoutFocus.values.map((f) {
                      final selected = _workoutFocus == f;
                      return ForgePressable(
                        onTap: () {
                          setState(() => _workoutFocus = f);
                          if (_planSeqIndex < 0) {
                            _applyTodayLesson();
                          }
                        },
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.md,
                            vertical: AppSpace.xs + 3,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.copper.withValues(alpha: 0.14)
                                : AppColors.bg2,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            border: Border.all(
                              color: selected
                                  ? AppColors.copper
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            f.label,
                            style: AppFonts.body(
                              fontSize: 12,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected
                                  ? AppColors.copper
                                  : AppColors.text2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpace.xs + 2),
                  Text(
                    _workoutFocus.hint,
                    style: _mutedStyle.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text('伤病护身（可选）', style: _mutedStyle.copyWith(fontSize: 12)),
                  const SizedBox(height: AppSpace.xs),
                  Wrap(
                    spacing: AppSpace.sm,
                    children: [
                      _injuryChip(
                        label: '膝盖不适',
                        selected: gameState.user.kneeIssue,
                        onTap: () {
                          gameNotifier.updateInjuryFlags(
                            kneeIssue: !gameState.user.kneeIssue,
                          );
                          if (_planSeqIndex < 0) _applyTodayLesson();
                        },
                      ),
                      _injuryChip(
                        label: '腰腹不适',
                        selected: gameState.user.waistIssue,
                        onTap: () {
                          gameNotifier.updateInjuryFlags(
                            waistIssue: !gameState.user.waistIssue,
                          );
                          if (_planSeqIndex < 0) _applyTodayLesson();
                        },
                      ),
                    ],
                  ),
                  if (_exerciseMode == 'camera') ...[
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      '摄像头模式只显示可姿态识别的动作；跑步/骑行等请用「手动」或「IMU」记录。',
                      style: _mutedStyle.copyWith(
                        fontSize: 11,
                        color: AppColors.ember.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                  if (_recommendedPlan != null) ...[
                    const SizedBox(height: AppSpace.md),
                    Container(
                      width: double.infinity,
                      padding: AppSpace.card,
                      decoration: BoxDecoration(
                        color: AppColors.copper.withValues(alpha: 0.08),
                        borderRadius: AppRadii.smAll,
                        border: Border.all(
                          color: AppColors.copper.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _recommendedPlan!.title,
                            style: _bodyStyle.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            '${_recommendedPlan!.reason} · 约 ${_recommendedPlan!.estimatedMinutes} 分钟 · 式间休 ${_recommendedPlan!.restSeconds}s',
                            style: _mutedStyle.copyWith(fontSize: 11),
                          ),
                          if (_recommendedPlan!.targetBurnCal > 0) ...[
                            const SizedBox(height: AppSpace.xs),
                            Text(
                              '目标消耗 ${_recommendedPlan!.targetBurnCal} kcal · Lv.${_recommendedPlan!.level}',
                              style: AppFonts.body(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ember,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpace.sm),
                          Wrap(
                            spacing: AppSpace.xs + 2,
                            runSpacing: AppSpace.xs + 2,
                            children: _recommendedPlan!.items
                                .asMap()
                                .entries
                                .map((e) {
                              final item = e.value;
                              final idx = item.exerciseIndex;
                              final ex = item.exercise;
                              final selected = _selectedExercise == idx;
                              final done = _planSeqIndex > e.key;
                              final current =
                                  _planSeqIndex == e.key && _planSeqIndex >= 0;
                              return ForgePressable(
                                onTap: () {
                                  if (_planSeqIndex >= 0) return; // 连训中不可跳选
                                  setState(() => _selectedExercise = idx);
                                },
                                borderRadius: AppRadii.mdAll,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpace.md,
                                    vertical: AppSpace.xs + 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: current
                                        ? AppColors.ember.withValues(alpha: 0.2)
                                        : done
                                            ? AppColors.copper
                                                .withValues(alpha: 0.18)
                                            : selected
                                                ? AppColors.ember
                                                    .withValues(alpha: 0.15)
                                                : AppColors.bg,
                                    borderRadius: AppRadii.mdAll,
                                    border: Border.all(
                                      color: current
                                          ? AppColors.ember
                                          : done
                                              ? AppColors.copper
                                              : selected
                                                  ? AppColors.ember
                                                  : AppColors.border,
                                      width: current || selected ? 2 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    '${done ? '✓ ' : ''}${e.key + 1}. ${ex.name} · ${item.target}${item.isTimed ? '秒' : '次'}',
                                    style: AppFonts.body(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: current || selected
                                          ? AppColors.ember
                                          : done
                                              ? AppColors.copper
                                              : AppColors.text,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: AppSpace.md),
                          // 按组合顺序连续训练
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _planSeqIndex >= 0
                                  ? null
                                  : _startPlanSequence,
                              icon: const Icon(Icons.play_arrow_rounded, size: 18),
                              label: Text(
                                _planSeqIndex >= 0
                                    ? '连训进行中（${_planSeqIndex + 1}/${_recommendedPlan!.items.length}）'
                                    : '架好手机开练（${_recommendedPlan!.items.length} 式 · 走开即自动开始）',
                                style: AppFonts.body(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    AppColors.ember.withValues(alpha: 0.9),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.ember.withValues(alpha: 0.35),
                                padding:
                                    const EdgeInsets.symmetric(vertical: AppSpace.md),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.md),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpace.md,
                    crossAxisSpacing: AppSpace.md,
                    childAspectRatio: 1.28,
                    children: _visibleExercises().map((entry) {
                      final index = entry.key;
                      final exercise = entry.value;
                      final isSelected = _selectedExercise == index;
                      final inPlan = _recommendedPlan?.exerciseIndexes
                              .contains(index) ??
                          false;

                      return ForgePressable(
                        onTap: () =>
                            setState(() => _selectedExercise = index),
                        borderRadius: AppRadii.smAll,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.md,
                            vertical: AppSpace.sm,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.copper.withValues(alpha: 0.1)
                                : AppColors.bg2,
                            borderRadius: AppRadii.smAll,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.copper
                                  : inPlan
                                      ? AppColors.forgeGlow
                                      : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                AppIcons.exercise(exercise.type),
                                size: 28,
                                color: isSelected
                                    ? AppColors.copper
                                    : AppColors.text2,
                              ),
                              const SizedBox(height: AppSpace.xs),
                              Text(
                                exercise.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _bodyStyle.copyWith(
                                  fontSize: 13,
                                  height: 1.15,
                                ),
                              ),
                              Text(
                                exercise.supportCamera
                                    ? '${exercise.calPerMin}千卡/分 · 可识别'
                                    : '${exercise.calPerMin}千卡/分',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _mutedStyle.copyWith(
                                  color: AppColors.copper,
                                  fontSize: 10,
                                  height: 1.15,
                                ),
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
            const SizedBox(height: AppSpace.lg),
            
            // 时长选择
            _sectionCard(
              icon: Icons.timer_outlined,
              title: '选择时长',
              child: Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.sm,
                      children: durations.map((d) {
                        final isSelected = _selectedDuration == d;
                        return ForgePressable(
                          onTap: () => setState(() => _selectedDuration = d),
                          borderRadius: AppRadii.smAll,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.copper.withValues(alpha: 0.12)
                                  : AppColors.bg2,
                              borderRadius: AppRadii.smAll,
                              border: Border.all(
                                color: isSelected ? AppColors.copper : AppColors.border,
                              ),
                            ),
                            child: Text(
                              '$d分钟',
                              style: AppFonts.body(
                                color: isSelected ? AppColors.copper : AppColors.text,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: AppSpace.lg),
            
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
                      const SizedBox(height: AppSpace.sm),
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
            const SizedBox(height: AppSpace.lg),
            
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
                style: AppFonts.body(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            
            // 今日锻炼记录
            _sectionCard(
              icon: Icons.history_outlined,
              title: '今日锻炼',
              child: gameState.exercises.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpace.md),
                            child: Text('今天还没有锻炼', style: _mutedStyle),
                          ),
                        )
                      : Column(
                          children: gameState.exercises.map((ex) => 
                            Container(
                              margin: const EdgeInsets.only(bottom: AppSpace.xs + 2),
                              padding: const EdgeInsets.all(AppSpace.md),
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: AppRadii.smAll,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(AppIcons.exerciseByName(ex.name), size: 16, color: AppColors.copper),
                                  const SizedBox(width: AppSpace.xs),
                                  Text(ex.name, style: _bodyStyle.copyWith(fontSize: 13)),
                                  const Spacer(),
                                  Text(
                                    '${ex.duration}分钟 / ${ex.cal}千卡',
                                    style: _mutedStyle.copyWith(fontSize: 12),
                                  ),
                                  const SizedBox(width: AppSpace.sm),
                                  Text(
                                    '-${ex.damage}',
                                    style: AppFonts.body(
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
                        child: Text('断开', style: AppFonts.body(fontSize: 13)),
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
                          style: AppFonts.body(fontSize: 13),
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
                          style: AppFonts.body(
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
            style: AppFonts.body(fontWeight: FontWeight.w700, fontSize: 14),
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
              exercise.name,
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
                style: AppFonts.body(fontWeight: FontWeight.w700),
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
      title: '${exercise?.name ?? ''} 检测中',
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
                style: AppFonts.body(fontWeight: FontWeight.w600),
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
                    style: AppFonts.body(
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
                    style: AppFonts.body(
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
                onPressed: _cameraSettling ? null : _initCamera,
                icon: const Icon(Icons.screen_rotation_alt_outlined, size: 18),
                label: Text(
                  _cameraSettling ? '正在打开…' : '架好手机 · 走开自动开练',
                  style: AppFonts.body(fontWeight: FontWeight.w600),
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
                    '开始摄像头教练',
                    style: AppFonts.body(fontWeight: FontWeight.w700),
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
                  '结束教练（结算）',
                  style: AppFonts.body(fontWeight: FontWeight.w600),
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
  
  /// 启动摄像头；就绪后若已选动作则直接进教练页（方向跟随手机姿态）
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

    if (_selectedExercise == null) {
      _showToast('请先选择运动类型，再打开摄像头');
      return;
    }

    setState(() => _cameraSettling = true);
    try {
      // 必须先解锁横竖，再 initialize：否则竖屏冷启动 SurfaceTexture
      // 要等到第一次物理旋转才与 mapRot 对齐。
      await _enableSensorOrientations();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final ready = await _initializeActiveCameraEngine();
      if (!ready) return;

      setState(() {
        _cameraReady = true;
        _cameraSettling = false;
      });
      // 打开摄像头即进入教练页（横/竖屏跟随手机姿态）
      await _startCameraDetection();
    } catch (e) {
      if (_cameraEngine == 'tflite') {
        final fallback = await _fallbackToMlKit(reason: '$e');
        if (fallback) {
          setState(() => _cameraSettling = false);
          _showToast('TFLite 初始化失败，已回退 ML Kit');
          await _startCameraDetection();
          return;
        }
      }
      _showToast('摄像头初始化失败: $e');
    } finally {
      if (mounted && _cameraSettling) {
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
  
  /// 开始摄像头检测 → 允许横竖自由旋转并进入全屏教练页
  Future<void> _startCameraDetection({int seedReps = 0}) async {
    if (_selectedExercise == null) {
      _showToast('请先选择运动类型');
      return;
    }
    if (!_cameraReady || _activeCameraDetector.controller == null) {
      // 未就绪则走完整打开流程
      await _initCamera();
      return;
    }
    if (_coachPageOpen) return;

    final exercise = Exercises.all[_selectedExercise!];
    if (!exercise.supportCamera) {
      _showToast('${exercise.name} 暂不支持摄像头识别，请换动作或用手动记录');
      return;
    }

    // 跟随手机姿态，不强制横/竖
    await _enableSensorOrientations();
    if (!mounted) return;
    // 相机可能在竖屏锁定下已打开：再同步一次预览方向
    if (_activeCameraDetector is PoseDetectionService) {
      await (_activeCameraDetector as PoseDetectionService).syncOrientation();
    }
    if (!mounted) return;

    final preferLandscape = PoseCoachGuideMath.prefersLandscape(exercise.type);
    setState(() {
      _cameraDetecting = true;
      _cameraRepCount = seedReps;
      _cameraFeedback = preferLandscape
          ? '可横持手机 · ${_getActionTip(exercise.type)}'
          : '可竖持手机 · ${_getActionTip(exercise.type)}';
      _cameraStartTime = DateTime.now();
      _repCountN.value = seedReps;
      _feedbackN.value = _cameraFeedback;
      _countUnitN.value = _getCountUnit(exercise.type);
      _comboN.value = 0;
      _staminaN.value = ExerciseGameLogic.maxStamina;
      _pausedN.value = false;
      _preparingN.value = true;
      _prepareProgressN.value = 0;
      _landmarksN.value = _currentLandmarks;
      _planTargetHit = false;
      _coachExternalCompleteN.value = false;
      _restCountdownN.value = 0;
      _lastCoachPhaseForVoice = null;
      _lastFormTipForVoice = null;
    });

    _gameLogic.reset();
    if (_planSeqIndex < 0) {
      _resetSessionStats();
    }
    _qualityGradeN.value = _lastGrade == 'D' && _qualityCount == 0 ? '' : _lastGrade;
    // 远场语音：同步开关 + 耳机/外放路由
    _syncCoachVoiceEnabled();
    // ignore: discarded_futures
    _coachVoice.prepareSession();
    // 不再用 2 秒 prepare；改为架设→入镜→倒计时免触控门控
    await PoseCoachDiary.instance.startSession(
      engine: _cameraEngine,
      exerciseType: exercise.type,
      note: 'preferLandscape=$preferLandscape',
    );
    _resetHandsFreeGate();
    if (_cameraBleFusion) {
      _fusionService.startDetection(exercise.type);
    }
    // ML Kit 引擎：注册精彩瞬间自动截屏回调
    if (_activeCameraDetector is PoseDetectionService) {
      (_activeCameraDetector as PoseDetectionService).onHighlightMoment =
          _captureHighlight;
    } else {
      // TFLite 无精彩瞬间能力
      _cameraDetector.onHighlightMoment = null;
    }
    try {
      await _activeCameraDetector.startDetection(exercise.type);
      if (seedReps > 0 &&
          _activeCameraDetector is PoseDetectionService) {
        (_activeCameraDetector as PoseDetectionService)
            .seedRepCount(seedReps);
      }
    } catch (e) {
      debugPrint('startDetection failed: $e');
      setState(() {
        _cameraDetecting = false;
        _cameraStartTime = null;
      });
      _showToast('姿态检测启动失败，请重试');
      return;
    }
    _startCameraTimer();

    final planItem =
        _planSeqIndex >= 0 ? _recommendedPlan?.itemAt(_planSeqIndex) : null;
    final effectiveTarget = _currentEffectiveTarget();
    final showTarget = effectiveTarget > 0
        ? effectiveTarget
        : planItem?.target;

    _coachPageOpen = true;
    _abortPlanOnStop = true;
    await Navigator.of(context).push(
      forgePageRoute(
        builder: (_) => PoseCoachPage(
          exerciseName: exercise.name,
          exerciseEmoji: exercise.emoji,
          exerciseType: exercise.type,
          tip: _getActionTip(exercise.type),
          controller: _activeCameraDetector.controller!,
          landmarks: _landmarksN,
          feedback: _feedbackN,
          repCount: _repCountN,
          countUnit: _countUnitN,
          combo: _comboN,
          stamina: _staminaN,
          paused: _pausedN,
          preparing: _preparingN,
          prepareProgress: _prepareProgressN,
          onStop: () => _stopCameraDetection(abortSequence: _abortPlanOnStop),
          onPauseSave: _pauseAndSaveSession,
          qualityGrade: _qualityGradeN,
          onFlipCamera: () async {
            final d = _activeCameraDetector;
            if (d is PoseDetectionService) {
              return d.switchCamera();
            }
            if (d is TfliteMotionService) {
              return d.switchCamera();
            }
            return null;
          },
          planStep: _planSeqIndex >= 0 ? _planSeqIndex + 1 : null,
          planTotal: _recommendedPlan?.items.length,
          targetCount: showTarget,
          targetUnit: planItem == null
              ? null
              : (planItem.isTimed ? '秒' : '次'),
          restCountdown: _restCountdownN,
          externalComplete: _coachExternalCompleteN,
          coachPhase: _coachPhaseN,
          coachPhaseHint: _coachPhaseHintN,
          coachCountdown: _coachCountdownN,
          diaryStatus: PoseCoachDiary.instance.liveStatus,
          onWarmPreview: () async {
            final d = _activeCameraDetector;
            if (d is PoseDetectionService) {
              await d.syncOrientation();
            }
          },
          onShareDiary: () async {
            try {
              await PoseCoachDiary.instance.share();
              if (mounted) _showToast('请把日记文件发给开发排查');
            } catch (e) {
              if (mounted) _showToast('分享日记失败: $e');
            }
          },
        ),
      ),
    );
    _coachPageOpen = false;
    await _restoreAppOrientation();
    if (_pendingPlanAdvance) {
      _pendingPlanAdvance = false;
      await _advancePlanSequence();
    } else if (_returnToBattle) {
      _returnToBattle = false;
      await _promptFeelThenPop();
    }
    if (mounted) setState(() {});
  }

  /// 连训达标：自动结算本式并进入休息/下一式
  void _maybeCompletePlanTarget(int count) {
    if (_planTargetHit || _planSeqIndex < 0) return;
    final item = _recommendedPlan?.itemAt(_planSeqIndex);
    if (item == null) return;
    final target = _currentEffectiveTarget();
    if (count < target) return;
    _planTargetHit = true;
    _abortPlanOnStop = false;
    // ignore: discarded_futures
    _sessionStore.clearSession();
    _resumableSession = null;
    _sessionBonusSeconds = 0;
    _coachVoice.announceExerciseComplete(
      exerciseName: item.exercise.name,
      reps: count,
    );
    _showToast('✅ ${item.exercise.name} 达标！');
    // 触发教练页走结束流程（pop + 结算）
    _coachExternalCompleteN.value = true;
  }

  /// 按推荐组合顺序连续训练：从第一式开始，每式完成后自动进入下一式
  Future<void> _startPlanSequence() async {
    final plan = _recommendedPlan;
    if (plan == null || plan.items.isEmpty) return;
    if (_exerciseMode != 'camera') {
      setState(() => _exerciseMode = 'camera');
    }
    // 连训用 ML Kit（全动作规则）；本机已修 beta 降级
    if (_cameraEngine != 'mlkit') {
      await _switchCameraEngine('mlkit');
      if (mounted) _showToast('连训已切换到 ML Kit 姿态引擎');
    }
    _planSeqIndex = 0;
    _planTargetHit = false;
    _pendingPlanAdvance = false;
    _returnToBattle = false;
    _resetSessionStats();
    setState(() => _selectedExercise = plan.items.first.exerciseIndex);
    final first = plan.items.first;
    _showToast(
      '已进入架设模式：把手机放好后走开，站进白框即可自动开练（${first.exercise.name} · ${first.targetLabel}）',
    );
    await _startCameraDetection();
  }

  /// 精彩瞬间（🔥 完美动作）自动截屏并保存到相册
  Future<void> _captureHighlight() async {
    // 达标结算 / 未在检测中：禁止截屏，避免与 stopImageStream 竞态
    if (_planTargetHit || !_cameraDetecting || _cameraSettling) return;
    final detector = _activeCameraDetector;
    if (detector is! PoseDetectionService) return;
    final now = DateTime.now();
    if (now.difference(_lastHighlightCapture).inSeconds < 12) return;
    _lastHighlightCapture = now;
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) return;
      }
      if (_planTargetHit || !_cameraDetecting) return;
      final path = await detector.captureStillSafe();
      if (path == null || !mounted) return;
      if (_planTargetHit || !_cameraDetecting) return;
      await Gal.putImage(path);
      if (!mounted) return;
      _showToast('📸 精彩动作已自动保存到相册');
    } catch (e) {
      debugPrint('精彩瞬间截屏失败: $e');
    }
  }

  /// 停止摄像头检测
  Future<void> _stopCameraDetection({
    bool abortSequence = true,
    bool skipFinish = false,
  }) async {
    if (!_cameraDetecting && _cameraStartTime == null) return;

    if (abortSequence && _planSeqIndex >= 0) {
      _planSeqIndex = -1;
      _pendingPlanAdvance = false;
      _restTimer?.cancel();
      _setupGraceTimer?.cancel();
      _restCountdownN.value = 0;
      _showToast('已退出连续训练');
      // ignore: discarded_futures
      _sessionStore.clearSession();
      _resumableSession = null;
      _sessionBonusSeconds = 0;
    }

    setState(() {
      _cameraDetecting = false;
      _cameraSettling = true;
      _preparingN.value = false;
    });

    await _activeCameraDetector.stopDetection();
    if (_cameraBleFusion) {
      _fusionService.stopDetection();
    }
    // ignore: discarded_futures
    _coachVoice.voice.restorePlayback();
    final diaryPath =
        await PoseCoachDiary.instance.endSession(reason: 'stop_camera');
    if (diaryPath != null) {
      debugPrint('[PoseCoachDiary] saved: $diaryPath');
    }

    if (!mounted) return;
    if (!skipFinish) {
      final gameNotifier = ref.read(gameStateProvider.notifier);
      await _finishCameraDetection(gameNotifier);
    } else {
      setState(() {
        _cameraStartTime = null;
      });
    }

    if (mounted) {
      setState(() => _cameraSettling = false);
    }
  }

  void _applyTodayLesson({bool silent = false}) {
    final gs = ref.read(gameStateProvider);
    final pendingBurn = math.max(0, gs.todayCalIn - gs.targetCal);
    final plan = CoachLesson.recommendToday(
      user: gs.user,
      focus: _workoutFocus,
      monsterAffinity: gs.monster.resolvedAffinity,
      injury: InjuryFlags(
        kneeIssue: gs.user.kneeIssue,
        waistIssue: gs.user.waistIssue,
      ),
      feelNudge: gs.coachFeelNudge,
      targetBurnCal: pendingBurn,
      streak: gs.streak,
    );
    if (plan.exerciseIndexes.isEmpty) {
      if (!silent) _showToast('暂无可用的摄像头可识别动作');
      return;
    }
    setState(() {
      _recommendedPlan = plan;
      _selectedExercise = plan.exerciseIndexes.first;
      _exerciseMode = 'camera';
      final opts = const [5, 10, 15, 20, 30];
      _selectedDuration = opts.reduce(
        (a, b) =>
            (a - plan.estimatedMinutes).abs() <=
                    (b - plan.estimatedMinutes).abs()
                ? a
                : b,
      );
    });
    if (!silent) {
      final names = plan.exercises.map((e) => e.name).join(' → ');
      _showToast('${plan.title}：$names');
    }
  }

  /// 摄像头模式只展示可识别动作；手动/IMU 展示全部（跑步等仅此可用）。
  List<MapEntry<int, ExerciseType>> _visibleExercises() {
    final all = Exercises.all.asMap().entries.toList();
    if (_exerciseMode == 'camera') {
      return all.where((e) => e.value.supportCamera).toList();
    }
    return all;
  }

  Widget _injuryChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ForgePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.xs + 3,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.ember.withValues(alpha: 0.14)
              : AppColors.bg2,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? AppColors.ember : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppFonts.body(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.ember : AppColors.text2,
          ),
        ),
      ),
    );
  }
  
  /// 完成摄像头检测并保存记录；连训跨式累计，结束时挂 pendingAttack。
  Future<void> _finishCameraDetection(GameStateNotifier gameNotifier) async {
    if (_selectedExercise == null || _cameraStartTime == null) return;
    
    final exercise = Exercises.all[_selectedExercise!];
    final elapsed = DateTime.now().difference(_cameraStartTime!);
    final repCount = _cameraBleFusion
        ? _fusionService.finalRepCount
        : _cameraRepCount;
    // 达标或已有有效计数时，即使不足 1 秒也按 1 分钟结算，避免打断连训
    var durationMinutes = (elapsed.inSeconds / 60).ceil();
    if (durationMinutes < 1) {
      final planItem =
          _planSeqIndex >= 0 ? _recommendedPlan?.itemAt(_planSeqIndex) : null;
      final hitTarget = _planTargetHit ||
          (planItem != null && repCount >= _currentEffectiveTarget()) ||
          repCount > 0;
      if (hitTarget) {
        durationMinutes = 1;
      } else {
        _showToast('运动时间太短，未记录');
        _planSeqIndex = -1;
        _pendingPlanAdvance = false;
        setState(() {
          _cameraStartTime = null;
          _cameraRepCount = 0;
          _cameraFeedback = '准备开始';
        });
        return;
      }
    }
    final elapsedMinutes = elapsed.inSeconds / 60.0;
    final baseCal = cameraBaseCalories(
      calPerMin: exercise.calPerMin,
      elapsedMinutes: elapsedMinutes,
      reps: repCount,
    );
    _sessionCal += baseCal;
    _sessionReps += repCount;
    _sessionExerciseType ??= exercise.type;
    if (_gameLogic.comboCount > _peakCombo) {
      _peakCombo = _gameLogic.comboCount;
    }
    if (_gameLogic.lastRepGrade.isNotEmpty && _qualityCount == 0) {
      _lastGrade = _gameLogic.lastRepGrade;
    }

    final gs = ref.read(gameStateProvider);
    final avgGrade = _qualityCount > 0
        ? _gradeFromAverage((_qualitySum / _qualityCount).round())
        : _lastGrade;
    final settlement = settleCoachSession(
      CoachSettlementInput(
        baseCalories: _sessionCal,
        reps: _sessionReps,
        grade: avgGrade,
        qualityScore:
            _qualityCount > 0 ? (_qualitySum / _qualityCount).round() : null,
        peakCombo: _peakCombo,
        stamina: _gameLogic.stamina,
        exerciseType: _sessionExerciseType ?? exercise.type,
        todayCalIn: gs.todayCalIn,
        difficulty: gs.difficulty,
        monsterAffinity: gs.monster.resolvedAffinity,
      ),
    );

    final modeLabel = _cameraEngine == 'tflite' ? 'camera_tflite' : 'camera';
    final record = ExerciseRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now().toDateString(),
      name: exercise.name,
      emoji: exercise.emoji,
      duration: durationMinutes,
      cal: baseCal,
      damage: 0,
      mode: modeLabel,
    );

    await gameNotifier.addExercise(record, applyCombat: false);

    setState(() {
      _cameraStartTime = null;
      _cameraRepCount = 0;
      _cameraFeedback = '准备开始';
    });

    var sessionEnded = true;
    if (_planSeqIndex >= 0 && _recommendedPlan != null) {
      final plan = _recommendedPlan!;
      final next = _planSeqIndex + 1;
      if (next < plan.items.length) {
        _planSeqIndex = next;
        setState(() => _selectedExercise = plan.items[next].exerciseIndex);
        _pendingPlanAdvance = true;
        sessionEnded = false;
        _showToast(
          '${exercise.name}完成 · $repCount${_getCountUnit(exercise.type)}，继续下一式',
        );
      } else {
        _planSeqIndex = -1;
        _coachVoice.announcePlanComplete(planTitle: plan.title);
        // ignore: discarded_futures
        _sessionStore.clearSession();
        _resumableSession = null;
        _sessionBonusSeconds = 0;
        _showToast('🎉 ${plan.title}全部完成！待攻 ${settlement.damage}');
      }
    } else {
      _showToast(
        '${exercise.name}完成！'
        '$repCount${_getCountUnit(exercise.type)}，'
        '${settlement.grade}级 · 待攻 ${settlement.damage}',
      );
    }

    if (sessionEnded) {
      await gameNotifier.setPendingAttack(settlement.pendingAttack);
      _returnToBattle = true;
      _resetSessionStats();
    }
  }

  String _gradeFromAverage(int score) {
    if (score >= 90) return 'S';
    if (score >= 80) return 'A';
    if (score >= 70) return 'B';
    if (score >= 60) return 'C';
    return 'D';
  }

  Future<void> _promptFeelThenPop() async {
    if (!mounted) return;
    CoachFeel? picked;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '课后手感',
                style: AppFonts.display(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '这炉火候如何？会微调明天的克制课。',
                style: AppFonts.body(fontSize: 13, color: AppColors.text2),
              ),
              const SizedBox(height: 16),
              ...CoachFeel.values.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () {
                      picked = f;
                      Navigator.of(ctx).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.copper,
                      side: const BorderSide(color: AppColors.copper),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      '${f.label} · ${f.hint}',
                      style: AppFonts.body(fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    await ref
        .read(gameStateProvider.notifier)
        .recordCoachFeel(picked ?? CoachFeel.justRight);
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// 式间休息倒计时结束后的下一式提示
  Future<void> _advancePlanSequence() async {
    final plan = _recommendedPlan;
    if (plan == null || _planSeqIndex < 0) return;
    final item = plan.itemAt(_planSeqIndex);
    if (item == null) return;
    _coachVoice.announcePlanRest(
      plan.restSeconds,
      nextExerciseName: item.exercise.name,
    );
    await _awaitPlanRest(plan.restSeconds);
    if (!mounted || _planSeqIndex < 0) return;
    _showToast(
      '下一式自动入镜：${item.exercise.name} · ${item.targetLabel}'
      '（${_planSeqIndex + 1}/${plan.items.length}）',
    );
    await _startCameraDetection();
  }

  /// 式间休息倒计时
  Future<void> _awaitPlanRest(int seconds) async {
    if (seconds <= 0) return;
    _restTimer?.cancel();
    final completer = Completer<void>();
    _restCountdownN.value = seconds;
    var dialogOpen = false;

    if (mounted) {
      dialogOpen = true;
      // ignore: unawaited_futures
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        pageBuilder: (ctx, _, __) {
          return PopScope(
            canPop: false,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: ValueListenableBuilder<int>(
                  valueListenable: _restCountdownN,
                  builder: (_, secs, __) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bg2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.copper.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '式间休息（无需操作，倒计时后自动下一式）',
                            style: AppFonts.body(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$secs',
                            style: AppFonts.display(
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ember,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '深呼吸，准备下一式',
                            style: _mutedStyle.copyWith(fontSize: 12),
                          ),
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: () {
                              _restTimer?.cancel();
                              _restCountdownN.value = 0;
                              if (!completer.isCompleted) {
                                completer.complete();
                              }
                              Navigator.of(ctx).pop();
                            },
                            child: Text(
                              '跳过休息',
                              style: AppFonts.body(
                                color: AppColors.copper,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
    }

    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final next = _restCountdownN.value - 1;
      if (next <= 0) {
        t.cancel();
        _restCountdownN.value = 0;
        if (!completer.isCompleted) completer.complete();
        if (dialogOpen && mounted) {
          final nav = Navigator.of(context, rootNavigator: true);
          if (nav.canPop()) nav.pop();
        }
      } else {
        _restCountdownN.value = next;
      }
    });

    await completer.future;
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
    _showToast('${exercise.name}完成！${durationMinutes}分钟，消耗${cal}千卡，造成${damageResult.damage}点伤害！');
    
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
      case 'plank':
        return '秒';
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
              style: AppFonts.body(color: AppColors.text, fontSize: 12),
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
                  exercise.name,
                  style: AppFonts.body(
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
        return '侧身入框，身体与剪影重合，手肘约 90°';
      case 'squat':
        return '正面入框，跟随剪影半蹲，膝盖勿过度前顶';
      case 'jumping_jack':
        return '正面入框，手臂上举过头，双脚开合';
      case 'plank':
        return '侧身入框，身体成一条直线';
      case 'lunge':
        return '侧面/正面入框，前膝约 90°';
      case 'highknee':
        return '正面入框，膝盖抬至髋高';
      case 'burpee':
        return '全身入框，跟随剪影节奏完成动作';
      case 'mountainclimber':
        return '侧身入框，核心收紧交替收腿';
      case 'hiit':
      case 'jumprope':
        return '正面入框，保持全身可见';
      default:
        return '站进白色画框，与剪影对齐后开始动作';
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
    _showToast('${exercise.name}完成！造成${_calcPreviewDamage()}点伤害！');
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
          final mode = selected.first;
          setState(() {
            _exerciseMode = mode;
            // 切到摄像头时，若当前选了不可识别动作则清空
            if (mode == 'camera' &&
                _selectedExercise != null &&
                !Exercises.all[_selectedExercise!].supportCamera) {
              _selectedExercise = null;
            }
          });
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
            RoundedRectangleBorder(borderRadius: AppRadii.smAll),
          ),
          textStyle: WidgetStateProperty.all(
            AppFonts.body(fontSize: 12, fontWeight: FontWeight.w600),
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
        padding: AppSpace.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.copper, size: 20),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    title,
                    style: _displayStyle.copyWith(fontSize: 17),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: AppSpace.md),
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
    return ForgePressable(
      onTap: onTap,
      borderRadius: AppRadii.smAll,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.copper.withValues(alpha: 0.15)
              : AppColors.bg2,
          borderRadius: AppRadii.smAll,
          border: Border.all(
            color: selected ? AppColors.copper : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppFonts.body(
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
        content: Text(message, style: AppFonts.body()),
        backgroundColor: AppColors.bg3,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}