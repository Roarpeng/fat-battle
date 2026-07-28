import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
  });

  @override
  State<PoseCoachPage> createState() => _PoseCoachPageState();
}

class _PoseCoachPageState extends State<PoseCoachPage> {
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    // 允许跟随手机姿态旋转
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _handleStop() async {
    if (_stopping) return;
    setState(() => _stopping = true);
    await widget.onStop();
    if (mounted) Navigator.of(context).pop();
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
              // 摄像头（镜像，贴近自拍习惯）
              Positioned.fill(
                child: Transform.scale(
                  scaleX: -1,
                  child: CameraPreview(widget.controller),
                ),
              ),
              // 引导框 + 剪影（随方向自适应）
              Positioned.fill(
                child: ValueListenableBuilder<Map<String, Map<String, double>>?>(
                  valueListenable: widget.landmarks,
                  builder: (context, lm, _) {
                    return PoseCoachGuideOverlay(
                      exerciseType: widget.exerciseType,
                      landmarks: lm,
                      tip: widget.tip,
                    );
                  },
                ),
              ),
              // 实时骨架
              Positioned.fill(
                child: ValueListenableBuilder<Map<String, Map<String, double>>?>(
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
                  child: Text(
                    '${widget.exerciseEmoji} ${widget.exerciseName}',
                    style: GoogleFonts.figtree(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
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
                ),
              ),
              // 结束按钮
              Positioned(
                top: 12,
                right: 16,
                child: FilledButton.icon(
                  onPressed: _stopping ? null : _handleStop,
                  icon: _stopping
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.stop_rounded, size: 18),
                  label: Text(
                    _stopping ? '结算中' : '结束',
                    style: GoogleFonts.figtree(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ember,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
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
  });

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
                            builder: (_, unit, __) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$reps',
                                  style: GoogleFonts.fraunces(
                                    color: AppColors.ember,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  unit,
                                  style: GoogleFonts.figtree(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
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
                                    style: GoogleFonts.figtree(
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
                                style: GoogleFonts.figtree(
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
                            builder: (_, unit, __) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$reps',
                                  style: GoogleFonts.fraunces(
                                    color: AppColors.ember,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  unit,
                                  style: GoogleFonts.figtree(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
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
                              style: GoogleFonts.figtree(
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
                          style: GoogleFonts.figtree(
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
        style: GoogleFonts.figtree(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
