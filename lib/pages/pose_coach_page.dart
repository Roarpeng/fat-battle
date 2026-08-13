import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/forge_theme.dart';
import '../constants/app_constants.dart';
import '../widgets/exercise/pose_coach_guide.dart';
import '../widgets/exercise/pose_overlay.dart';

/// 全屏姿态教练页（预览 + 白框剪影 + HUD）。
/// 横/竖屏跟随手机姿态，不强制锁定某一方向。
class PoseCoachPage extends StatefulWidget {
  final String exerciseName;
  final String exerciseEmoji;
  final String exerciseType;
  final String tip;
  final CameraController controller;
  final ValueNotifier<Map<String, Map<String, double>>?> landmarks;
  final ValueNotifier<String> feedback;
  final ValueNotifier<int> repCount;
  final ValueNotifier<String> countUnit;
  final ValueNotifier<int> combo;
  final ValueNotifier<double> stamina;
  final ValueNotifier<bool> paused;
  final ValueNotifier<bool> preparing;
  final ValueNotifier<double> prepareProgress;
  final Future<void> Function() onStop;

  /// 切换前置/后置；返回新的 Controller（可为 null 表示失败）
  final Future<CameraController?> Function()? onFlipCamera;

  /// 连训：当前第几式（1-based）；null 表示非连训。
  final int? planStep;

  /// 连训总式数。
  final int? planTotal;

  /// 本式目标数值（次数或秒）。
  final int? targetCount;

  /// 目标单位文案，如「次」「秒」。
  final String? targetUnit;

  /// 式间休息倒计时（秒）；>0 时显示休息遮罩。
  final ValueNotifier<int>? restCountdown;

  /// 外部触发结束（达标自动完成）：为 true 时走 onStop 并 pop，不视为用户中止。
  final ValueNotifier<bool>? externalComplete;

  /// 免触控阶段：setup / align / countdown / active
  final ValueNotifier<String>? coachPhase;

  /// 阶段提示文案
  final ValueNotifier<String>? coachPhaseHint;

  /// 倒计时秒数（countdown 阶段）
  final ValueNotifier<int>? coachCountdown;

  /// 诊断日记实时状态（关键点/对齐）
  final ValueNotifier<String>? diaryStatus;

  /// 分享诊断日记
  final Future<void> Function()? onShareDiary;

  /// 教练页首帧后预热预览方向（pause/resume）
  final Future<void> Function()? onWarmPreview;

  /// 暂停并保存进度后退出（可续训）；为 null 时不显示暂停按钮
  final Future<void> Function()? onPauseSave;

  /// 最近一次动作等级（S–D），教练 HUD 展示。
  final ValueNotifier<String>? qualityGrade;

  const PoseCoachPage({
    super.key,
    required this.exerciseName,
    required this.exerciseEmoji,
    required this.exerciseType,
    required this.tip,
    required this.controller,
    required this.landmarks,
    required this.feedback,
    required this.repCount,
    required this.countUnit,
    required this.combo,
    required this.stamina,
    required this.paused,
    required this.preparing,
    required this.prepareProgress,
    required this.onStop,
    this.onFlipCamera,
    this.planStep,
    this.planTotal,
    this.targetCount,
    this.targetUnit,
    this.restCountdown,
    this.externalComplete,
    this.coachPhase,
    this.coachPhaseHint,
    this.coachCountdown,
    this.diaryStatus,
    this.onShareDiary,
    this.onWarmPreview,
    this.onPauseSave,
    this.qualityGrade,
  });

  @override
  State<PoseCoachPage> createState() => _PoseCoachPageState();
}

class _PoseCoachPageState extends State<PoseCoachPage> {
  bool _stopping = false;
  bool _flipping = false;
  bool _pausing = false;
  /// 切换镜头时先置 null，避免 CameraPreview 挂在已 dispose 的 Controller 上黑屏
  CameraController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    // 允许跟随手机姿态旋转
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    widget.externalComplete?.addListener(_onExternalComplete);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await widget.onWarmPreview?.call();
      } catch (_) {}
    });
  }

  Future<void> _handleFlipCamera() async {
    if (_stopping || _flipping || widget.onFlipCamera == null) return;
    // 先拆掉预览，再让 service dispose 旧相机
    setState(() {
      _flipping = true;
      _controller = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    try {
      final next = await widget.onFlipCamera!();
      if (!mounted) return;
      if (next != null && next.value.isInitialized) {
        setState(() => _controller = next);
      }
    } catch (e) {
      debugPrint('flip camera failed: $e');
    } finally {
      if (mounted) setState(() => _flipping = false);
    }
  }

  @override
  void dispose() {
    widget.externalComplete?.removeListener(_onExternalComplete);
    // 退出训练时重置为系统默认布局与竖屏锁定
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  void _onExternalComplete() {
    if (widget.externalComplete?.value == true) {
      _handleStop();
    }
  }

  Future<void> _handleStop() async {
    if (_stopping || _pausing) return;
    setState(() => _stopping = true);
    await widget.onStop();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handlePauseSave() async {
    if (_stopping || _pausing || widget.onPauseSave == null) return;
    setState(() => _pausing = true);
    try {
      await widget.onPauseSave!();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('pause save failed: $e');
      if (mounted) setState(() => _pausing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleStop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 摄像头 contain 入镜（完整画面，不 cover 裁切）+ 同框引导/骨架
              Positioned.fill(
                child: _buildCameraStage(context),
              ),
              // 动作信息：竖屏放顶部左侧，横屏放左下
              Positioned(
                left: 16,
                top: isPortrait ? 88 : null,
                bottom: isPortrait ? null : 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.copper.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.exerciseEmoji} ${widget.exerciseName}',
                        style: AppFonts.body(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (widget.planStep != null &&
                          widget.planTotal != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '第 ${widget.planStep}/${widget.planTotal} 式'
                          '${widget.targetCount != null ? ' · 目标 ${widget.targetCount}${widget.targetUnit ?? '次'}' : ''}',
                          style: AppFonts.body(
                            color: AppColors.copper,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // HUD：横屏靠右，竖屏靠底部
              Positioned(
                right: 16,
                top: isPortrait ? null : 56,
                bottom: isPortrait ? 16 : 16,
                left: isPortrait ? 16 : null,
                child: _CoachHud(
                  feedback: widget.feedback,
                  repCount: widget.repCount,
                  countUnit: widget.countUnit,
                  combo: widget.combo,
                  stamina: widget.stamina,
                  paused: widget.paused,
                  preparing: widget.preparing,
                  prepareProgress: widget.prepareProgress,
                  compact: isPortrait,
                  targetCount: widget.targetCount,
                  targetUnit: widget.targetUnit,
                  qualityGrade: widget.qualityGrade,
                ),
              ),
              // 结束 + 切换镜头 + 分享日记
              Positioned(
                top: 12,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onFlipCamera != null) ...[
                      OutlinedButton.icon(
                        onPressed: (_stopping || _flipping)
                            ? null
                            : _handleFlipCamera,
                        icon: _flipping
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cameraswitch_rounded, size: 16),
                        label: Text(
                          _flipping
                              ? '切换中'
                              : (_controller?.description.lensDirection ==
                                      CameraLensDirection.front
                                  ? '后置'
                                  : '前置'),
                          style: AppFonts.body(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (widget.onShareDiary != null) ...[
                      OutlinedButton.icon(
                        onPressed: _stopping
                            ? null
                            : () async {
                                try {
                                  await widget.onShareDiary!();
                                } catch (_) {}
                              },
                        icon: const Icon(Icons.bug_report_outlined, size: 16),
                        label: Text(
                          '日记',
                          style: AppFonts.body(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (widget.onPauseSave != null) ...[
                      OutlinedButton.icon(
                        onPressed: (_stopping || _pausing)
                            ? null
                            : _handlePauseSave,
                        icon: _pausing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.pause_rounded, size: 16),
                        label: Text(
                          _pausing ? '保存中' : '暂停',
                          style: AppFonts.body(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FilledButton.icon(
                      onPressed: (_stopping || _pausing) ? null : _handleStop,
                      icon: _stopping
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.stop_rounded, size: 18),
                      label: Text(
                        _stopping ? '结算中' : '结束',
                        style: AppFonts.body(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            AppColors.ember.withValues(alpha: 0.85),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 诊断状态条（入镜检测是否在跑）
              if (widget.diaryStatus != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: isPortrait ? 88 : 72,
                  child: ValueListenableBuilder<String>(
                    valueListenable: widget.diaryStatus!,
                    builder: (_, status, __) {
                      return IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.copper.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            '诊断 · $status',
                            style: AppFonts.body(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              // 免触控阶段大字引导（架设 / 入镜 / 倒计时）
              if (widget.coachPhase != null)
                Positioned.fill(
                  child: ValueListenableBuilder<String>(
                    valueListenable: widget.coachPhase!,
                    builder: (_, phase, __) {
                      if (phase == 'active') return const SizedBox.shrink();
                      return IgnorePointer(
                        child: _HandsFreePhaseOverlay(
                          phase: phase,
                          hintListenable: widget.coachPhaseHint,
                          countdownListenable: widget.coachCountdown,
                          progressListenable: widget.prepareProgress,
                        ),
                      );
                    },
                  ),
                ),
              // 式间休息遮罩
              if (widget.restCountdown != null)
                Positioned.fill(
                  child: ValueListenableBuilder<int>(
                    valueListenable: widget.restCountdown!,
                    builder: (_, secs, __) {
                      if (secs <= 0) return const SizedBox.shrink();
                      return ColoredBox(
                        color: Colors.black.withValues(alpha: 0.72),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '休息一下',
                                style: AppFonts.body(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '$secs',
                                style: AppFonts.display(
                                  color: AppColors.copper,
                                  fontSize: 64,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.planStep != null &&
                                        widget.planTotal != null
                                    ? '下一式准备中（${widget.planStep! + 1}/${widget.planTotal}）'
                                    : '下一式准备中',
                                style: AppFonts.body(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 官方 CameraPreview：纹理自带 RotatedBox + SurfaceTexture 变换；
  /// 骨架必须放在 child（最终显示空间）。jpeg_buffer 关键点经
  /// [_bufferPixelToPreviewNorm] 映射到该空间（与 google_ml_kit 示例一致）。
  Widget _buildCameraStage(BuildContext context) {
    final cam = _controller;
    if (cam == null || !cam.value.isInitialized) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white54),
              const SizedBox(height: 12),
              Text(
                _flipping ? '正在切换摄像头…' : '摄像头准备中…',
                style: AppFonts.body(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ValueListenableBuilder<CameraValue>(
      valueListenable: cam,
      builder: (context, value, _) {
        final orient = value.deviceOrientation;

        Widget stage = CameraPreview(
          // 方向变化时重建 Texture，避免冷启动预览变换滞后
          key: ValueKey('preview_${cam.description.name}_$orient'),
          cam,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ValueListenableBuilder<Map<String, Map<String, double>>?>(
                valueListenable: widget.landmarks,
                builder: (context, lm, _) {
                  return PoseCoachGuideOverlay(
                    exerciseType: widget.exerciseType,
                    landmarks: lm,
                    tip: widget.tip,
                  );
                },
              ),
              ValueListenableBuilder<Map<String, Map<String, double>>?>(
                valueListenable: widget.landmarks,
                builder: (context, lm, _) {
                  if (lm == null) return const SizedBox.shrink();
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return PoseOverlay(
                        landmarks: lm,
                        size: Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );

        // 前置镜像在 landmark 映射里做 x=1-x；勿再 Transform 整页，
        // 否则纹理与骨架相对镜像关系不变。
        return ColoredBox(
          color: Colors.black,
          child: Center(child: stage),
        );
      },
    );
  }
}

/// 架设 / 入镜 / 倒计时 全屏提示（不拦截手势以外的结束按钮——用 IgnorePointer 包住）
class _HandsFreePhaseOverlay extends StatelessWidget {
  final String phase;
  final ValueNotifier<String>? hintListenable;
  final ValueNotifier<int>? countdownListenable;
  final ValueNotifier<double> progressListenable;

  const _HandsFreePhaseOverlay({
    required this.phase,
    required this.hintListenable,
    required this.countdownListenable,
    required this.progressListenable,
  });

  @override
  Widget build(BuildContext context) {
    final title = switch (phase) {
      'setup' => '架设手机',
      'align' => '站进白框',
      'countdown' => '即将开始',
      _ => '',
    };

    return ColoredBox(
      color: Colors.black.withValues(alpha: phase == 'countdown' ? 0.35 : 0.45),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppFonts.body(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (phase == 'countdown' && countdownListenable != null)
                ValueListenableBuilder<int>(
                  valueListenable: countdownListenable!,
                  builder: (_, n, __) => Text(
                    n > 0 ? '$n' : 'GO',
                    style: AppFonts.display(
                      color: AppColors.copper,
                      fontSize: 88,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Icon(
                  phase == 'setup'
                      ? Icons.phonelink_setup_rounded
                      : Icons.accessibility_new_rounded,
                  color: AppColors.copper,
                  size: 56,
                ),
              const SizedBox(height: 16),
              if (hintListenable != null)
                ValueListenableBuilder<String>(
                  valueListenable: hintListenable!,
                  builder: (_, hint, __) => Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: AppFonts.body(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: 180,
                child: ValueListenableBuilder<double>(
                  valueListenable: progressListenable,
                  builder: (_, p, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: p.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.white24,
                      color: AppColors.copper,
                    ),
                  ),
                ),
              ),
              if (phase == 'setup') ...[
                const SizedBox(height: 16),
                Text(
                  '点一次后无需再碰手机\n入镜稳定后会自动 3-2-1 开练',
                  textAlign: TextAlign.center,
                  style: AppFonts.body(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachHud extends StatelessWidget {
  final ValueNotifier<String> feedback;
  final ValueNotifier<int> repCount;
  final ValueNotifier<String> countUnit;
  final ValueNotifier<int> combo;
  final ValueNotifier<double> stamina;
  final ValueNotifier<bool> paused;
  final ValueNotifier<bool> preparing;
  final ValueNotifier<double> prepareProgress;
  final bool compact;
  final int? targetCount;
  final String? targetUnit;
  final ValueNotifier<String>? qualityGrade;

  const _CoachHud({
    required this.feedback,
    required this.repCount,
    required this.countUnit,
    required this.combo,
    required this.stamina,
    required this.paused,
    required this.preparing,
    required this.prepareProgress,
    this.compact = false,
    this.targetCount,
    this.targetUnit,
    this.qualityGrade,
  });

  Widget _repBlock(int reps, String unit) {
    final target = targetCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          target != null ? '$reps / $target' : '$reps',
          style: AppFonts.display(
            color: AppColors.ember,
            fontSize: compact ? 28 : 36,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          target != null
              ? '${targetUnit ?? unit}'
              : unit,
          style: AppFonts.body(
            color: Colors.white70,
            fontSize: compact ? 11 : 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? double.infinity : 160,
      child: Column(
        crossAxisAlignment:
            compact ? CrossAxisAlignment.stretch : CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<int>(
            valueListenable: combo,
            builder: (_, c, __) {
              if (c < 2) return const SizedBox.shrink();
              return Align(
                alignment: compact ? Alignment.centerLeft : Alignment.centerRight,
                child: _chip('🔥 ${c}连击', AppColors.copper),
              );
            },
          ),
          if (qualityGrade != null)
            ValueListenableBuilder<String>(
              valueListenable: qualityGrade!,
              builder: (_, g, __) {
                if (g.isEmpty) return const SizedBox.shrink();
                return Align(
                  alignment:
                      compact ? Alignment.centerLeft : Alignment.centerRight,
                  child: _chip('$g 级', AppColors.forgeGlow),
                );
              },
            ),
          ValueListenableBuilder<bool>(
            valueListenable: preparing,
            builder: (_, prep, __) {
              if (!prep) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ValueListenableBuilder<double>(
                  valueListenable: prepareProgress,
                  builder: (_, p, __) => Column(
                    crossAxisAlignment: compact
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                    children: [
                      _chip('准备中…', AppColors.shield),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: compact ? double.infinity : 120,
                        child: LinearProgressIndicator(
                          value: p,
                          minHeight: 4,
                          backgroundColor: Colors.white24,
                          color: AppColors.shield,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: paused,
            builder: (_, p, __) {
              if (!p) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment:
                      compact ? Alignment.centerLeft : Alignment.centerRight,
                  child: _chip('已暂停', AppColors.ember),
                ),
              );
            },
          ),
          if (!compact) const Spacer(),
          if (compact) const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(compact ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: compact
                ? Row(
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: repCount,
                        builder: (_, reps, __) {
                          return ValueListenableBuilder<String>(
                            valueListenable: countUnit,
                            builder: (_, unit, __) => _repBlock(reps, unit),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ValueListenableBuilder<double>(
                              valueListenable: stamina,
                              builder: (_, s, __) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '体力 ${s.toInt()}',
                                    style: AppFonts.body(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: (s / 100).clamp(0.0, 1.0),
                                      minHeight: 6,
                                      backgroundColor: Colors.white24,
                                      color: AppColors.copper,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            ValueListenableBuilder<String>(
                              valueListenable: feedback,
                              builder: (_, fb, __) => Text(
                                fb.isEmpty ? '跟随白色剪影站位' : fb,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.body(
                                  color: Colors.white,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: repCount,
                        builder: (_, reps, __) {
                          return ValueListenableBuilder<String>(
                            valueListenable: countUnit,
                            builder: (_, unit, __) => _repBlock(reps, unit),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<double>(
                        valueListenable: stamina,
                        builder: (_, s, __) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '体力 ${s.toInt()}',
                              style: AppFonts.body(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (s / 100).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: Colors.white24,
                                color: AppColors.copper,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<String>(
                        valueListenable: feedback,
                        builder: (_, fb, __) => Text(
                          fb.isEmpty ? '跟随白色剪影站位' : fb,
                          style: AppFonts.body(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        text,
        style: AppFonts.body(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
