import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/forge_theme.dart';
import '../theme/app_icons.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../constants/app_constants.dart';
import '../core/barrel.dart' as core;
import '../models/game_models.dart';
import '../providers/game_provider.dart';
import '../services/game_algorithm.dart';
import '../widgets/forge_pressable.dart';
import '../widgets/home/forge_background.dart';
import '../widgets/hp_bar.dart';
import '../widgets/medical_disclaimer.dart';
import '../widgets/trend_line_chart.dart';

/// 进度页 — 锻造工坊视觉（方案 A）
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  final _weightController = TextEditingController();
  final _waistController = TextEditingController();

  @override
  void dispose() {
    _weightController.dispose();
    _waistController.dispose();
    super.dispose();
  }

  TextStyle get _displayStyle => AppFonts.display(
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      );

  TextStyle get _bodyStyle => AppFonts.body(color: AppColors.text);

  TextStyle get _mutedStyle =>
      AppFonts.body(color: AppColors.text2, fontSize: 13);

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);

    if (!gameState.hasGame) {
      return ForgeBackground(
        child: Center(
          child: Text('请先创建角色', style: _bodyStyle),
        ),
      );
    }

    final user = gameState.user;
    final progress = GameAlgorithm.calcProgress(
      gameState.weightRecords.isNotEmpty
          ? gameState.weightRecords.first.weight
          : user.weight,
      user.weight,
      user.targetWeight,
    );
    final bmi = GameAlgorithm.calcBMI(user.weight, user.height);
    final bodyType = GameAlgorithm.getBodyType(bmi);

    return ForgeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('进度', style: _displayStyle.copyWith(fontSize: 20)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: AppSpace.page.copyWith(bottom: AppSpace.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (gameState.inExtremeDeficitCrisis)
                const SafetyCrisisBanner(),
              ForgeStagger(index: 0, child: _buildHero(progress, user, gameState)),
              const SizedBox(height: AppSpace.xl),
              ForgeStagger(
                index: 1,
                child: _sectionCard(
                  icon: Icons.track_changes_outlined,
                  title: '雕琢进度',
                  subtitle: '腰围趋势与平滑体重是主指标，单日体重作参考',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('当前 ${user.weight.toInt()} kg', style: _mutedStyle),
                          Text('目标 ${user.targetWeight.toInt()} kg',
                              style: _mutedStyle),
                        ],
                      ),
                      const SizedBox(height: AppSpace.md),
                      ProgressBar(
                        percent: progress / 100,
                        text: '${progress.toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              ForgeStagger(
                index: 2,
                child: _buildWaterCard(gameState, gameNotifier),
              ),
              const SizedBox(height: AppSpace.lg),
              ForgeStagger(
                index: 3,
                child: _buildBmiCard(bmi, bodyType),
              ),
              const SizedBox(height: AppSpace.lg),
              ForgeStagger(
                index: 4,
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildStatCard('${gameState.kills}', '击杀怪物',
                            Icons.local_fire_department_outlined),
                        const SizedBox(width: AppSpace.md),
                        _buildStatCard('${gameState.user.totalDamage.toInt()}',
                            '总伤害', Icons.bolt_outlined),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    Row(
                      children: [
                        _buildStatCard('${gameState.user.totalExercise.toInt()}',
                            '总消耗(千卡)', Icons.fitness_center_outlined),
                        const SizedBox(width: AppSpace.md),
                        _buildStatCard('${gameState.streak}', '连续天数',
                            Icons.calendar_today_outlined),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              _sectionCard(
                icon: Icons.view_week_outlined,
                title: '本周概览',
                child: gameState.weekData.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                          child: Text('暂无数据', style: _mutedStyle),
                        ),
                      )
                    : Column(
                        children: gameState.weekData.map((d) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpace.sm),
                            child: ForgeSurface(
                              color: AppColors.surface,
                              borderRadius: AppRadii.smAll,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.md,
                                vertical: AppSpace.md - 2,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Day ${d.day} · ${d.date}',
                                    style: _bodyStyle.copyWith(fontSize: 13),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    d.completed
                                        ? Icons.check_circle_outline
                                        : Icons.radio_button_unchecked,
                                    size: 16,
                                    color: d.completed
                                        ? AppColors.green
                                        : AppColors.text2,
                                  ),
                                  const SizedBox(width: AppSpace.xs),
                                  Text(
                                    d.completed ? '完成' : '未完成',
                                    style: AppFonts.body(
                                      fontSize: 12,
                                      color: d.completed
                                          ? AppColors.green
                                          : AppColors.text2,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpace.md),
                                  Text(
                                    '${d.calIn}入/${d.calExercise}出',
                                    style: _mutedStyle.copyWith(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: AppSpace.lg),
              _buildProgressGallery(gameState, gameNotifier),
              const SizedBox(height: AppSpace.lg),
              _buildExerciseTrends(gameState),
              const SizedBox(height: AppSpace.lg),
              _sectionCard(
                icon: Icons.monitor_weight_outlined,
                title: '记录今日体重',
                subtitle: '单日体重波动较大，趋势看平滑曲线',
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        style: _bodyStyle,
                        decoration: InputDecoration(
                          hintText: '输入体重 (kg)',
                          hintStyle: _mutedStyle,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    ElevatedButton(
                      onPressed: () {
                        final weight =
                            double.tryParse(_weightController.text);
                        if (weight == null || weight < 30 || weight > 300) {
                          _showToast('请输入有效体重');
                          return;
                        }
                        gameNotifier.recordWeight(weight);
                        _weightController.clear();
                        _showToast('体重已记录: ${weight}kg');
                      },
                      child: const Text('记录'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              _sectionCard(
                icon: Icons.straighten,
                title: '记录腰围（可选）',
                subtitle: '主进度指标，不需要连接腰部 Hub',
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _waistController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: _bodyStyle,
                        decoration: InputDecoration(
                          hintText: '腰围 (cm)',
                          hintStyle: _mutedStyle,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    ElevatedButton(
                      onPressed: () {
                        final waist = double.tryParse(_waistController.text);
                        if (waist == null || waist < 40 || waist > 200) {
                          _showToast('请输入有效腰围 (40-200cm)');
                          return;
                        }
                        gameNotifier.recordWaist(waist);
                        _waistController.clear();
                        _showToast('腰围已记录: ${waist}cm');
                      },
                      child: const Text('记录'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              _sectionCard(
                icon: Icons.show_chart_outlined,
                title: '平滑体重 (7–14日)',
                subtitle: '主曲线为移动平均，虚线为每日体重',
                child: gameState.weightRecords.length < 2
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpace.xl,
                          ),
                          child: Text('需要至少 2 天记录', style: _mutedStyle),
                        ),
                      )
                    : SizedBox(
                        height: 180,
                        child: _buildSmoothedWeightChart(
                          gameState.weightRecords,
                        ),
                      ),
              ),
              const SizedBox(height: AppSpace.lg),
              _sectionCard(
                icon: Icons.accessibility_new_outlined,
                title: '腰围趋势',
                subtitle: '塑身主指标，手动录入即可',
                child: gameState.waistRecords.length < 2
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpace.xl,
                          ),
                          child: Text(
                            gameState.waistRecords.isEmpty
                                ? '还没有腰围记录，可在上方手动录入'
                                : '再记一天就能看到趋势',
                            style: _mutedStyle,
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 180,
                        child: _buildWaistChart(gameState.waistRecords),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(double progress, User user, GameState gs) {
    final logs = gs.weightRecords
        .map((r) => core.WeightLogEntry(date: r.date, weightKg: r.weight))
        .toList();
    final smoothed = core.smoothWeightSeries(
      logs,
      windowDays: logs.length >= 14 ? 14 : 7,
    );
    final smoothKg =
        smoothed.isNotEmpty ? smoothed.last : user.weight;
    final waistTrend = core.analyzeWaistTrend(
      gs.waistRecords
          .map((r) => core.WaistLogEntry(date: r.date, waistCm: r.waistCm))
          .toList(),
    );
    final waistLabel = waistTrend == null
        ? (user.waistCm != null
            ? '${user.waistCm!.toStringAsFixed(1)} cm'
            : '未记录')
        : '${waistTrend.currentWaistCm.toStringAsFixed(1)} cm';
    final waistHint = waistTrend == null
        ? '主指标'
        : (waistTrend.trend == core.WeightTrendDirection.decreasing
            ? '趋势下降'
            : waistTrend.trend == core.WeightTrendDirection.increasing
                ? '趋势上升'
                : '趋势平稳');

    return ForgeSurface(
      borderColor: AppColors.copper.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本周雕琢',
            style: _displayStyle.copyWith(fontSize: 28, height: 1.15),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            '腰围与平滑体重是主进度；单日体重只作参考',
            style: _mutedStyle.copyWith(height: 1.45),
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('腰围', style: _mutedStyle.copyWith(fontSize: 11)),
                    Text(
                      waistLabel,
                      style: _displayStyle.copyWith(
                        fontSize: 18,
                        color: AppColors.ember,
                      ),
                    ),
                    Text(waistHint, style: _mutedStyle.copyWith(fontSize: 10)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('平滑体重', style: _mutedStyle.copyWith(fontSize: 11)),
                    Text(
                      '${smoothKg.toStringAsFixed(1)} kg',
                      style: _displayStyle.copyWith(fontSize: 18),
                    ),
                    Text(
                      '7–14日均值',
                      style: _mutedStyle.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('今日体重', style: _mutedStyle.copyWith(fontSize: 11)),
                    Text(
                      '${user.weight.toStringAsFixed(1)} kg',
                      style: _displayStyle.copyWith(
                        fontSize: 18,
                        color: AppColors.copper,
                      ),
                    ),
                    Text(
                      '${progress.toStringAsFixed(0)}% 目标',
                      style: _mutedStyle.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
    String? subtitle,
    Widget? trailing,
  }) {
    return ForgeSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ForgeSectionHeader(
            title: title,
            subtitle: subtitle,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.copper, size: 20),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpace.sm),
                  trailing,
                ],
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildWaterCard(GameState gs, GameStateNotifier notifier) {
    final goal = gs.waterGoal;
    final cups = gs.waterCups;
    final percent = goal > 0 ? (cups / goal).clamp(0.0, 1.0) : 0.0;

    return _sectionCard(
      icon: Icons.water_drop_outlined,
      title: '今日饮水',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _waterControlButton(
                icon: Icons.remove,
                onTap: () async {
                  HapticFeedback.lightImpact();
                  await notifier.removeWaterCup();
                },
              ),
              const SizedBox(width: 28),
              Column(
                children: [
                  Text(
                    '$cups',
                    style: _displayStyle.copyWith(
                      fontSize: 36,
                      color: AppColors.copper,
                    ),
                  ),
                  Text('/ $goal 杯', style: _mutedStyle),
                  const SizedBox(height: 2),
                  Text(
                    '约 ${cups * 200} ml',
                    style: _mutedStyle.copyWith(fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(width: 28),
              _waterControlButton(
                icon: Icons.add,
                onTap: () async {
                  HapticFeedback.lightImpact();
                  await notifier.addWaterCup();
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          ClipRRect(
            borderRadius: AppRadii.smAll,
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: AppColors.bg,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.shield),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              percent >= 1.0 ? '目标已达成' : '还需 ${(goal - cups).clamp(0, goal)} 杯',
              style: _mutedStyle.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waterControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ForgePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: ForgeSurface(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.copper, size: 22),
        ),
      ),
    );
  }

  Widget _buildBmiCard(double bmi, String bodyType) {
    final bmiColor = bmi < 18.5
        ? AppColors.shield
        : bmi < 24
            ? AppColors.green
            : bmi < 28
                ? AppColors.copper
                : AppColors.ember;

    return ForgeSurface(
      child: Row(
        children: [
          const Icon(Icons.accessibility_new_outlined,
              color: AppColors.copper, size: 22),
          const SizedBox(width: AppSpace.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BMI', style: _mutedStyle.copyWith(fontSize: 12)),
              Text(
                bmi.toStringAsFixed(1),
                style: _displayStyle.copyWith(fontSize: 32, color: bmiColor),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.sm - 2,
            ),
            decoration: BoxDecoration(
              color: bmiColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: bmiColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              bodyType,
              style: AppFonts.body(
                color: bmiColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Expanded(
      child: ForgeSurface(
        padding: const EdgeInsets.all(AppSpace.lg - 2),
        borderRadius: AppRadii.mdAll,
        child: Column(
          children: [
            Icon(icon, color: AppColors.copper, size: 18),
            const SizedBox(height: AppSpace.sm),
            Text(
              value,
              style: _displayStyle.copyWith(
                fontSize: 22,
                color: AppColors.copper,
              ),
            ),
            const SizedBox(height: AppSpace.xs - 2),
            Text(label, style: _mutedStyle.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressGallery(GameState gs, GameStateNotifier notifier) {
    return _sectionCard(
      icon: Icons.photo_library_outlined,
      title: '身体变化相册',
      trailing: TextButton.icon(
        onPressed: () => _addProgressPhoto(notifier),
        icon: const Icon(Icons.add_a_photo_outlined, size: 18),
        label: Text('添加', style: AppFonts.body(fontSize: 13)),
        style: TextButton.styleFrom(foregroundColor: AppColors.copper),
      ),
      child: gs.progressPhotos.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(Icons.photo_camera_outlined,
                        size: 40, color: AppColors.text2.withValues(alpha: 0.6)),
                    const SizedBox(height: 10),
                    Text('记录你的身体变化', style: _mutedStyle),
                    const SizedBox(height: 4),
                    Text(
                      '定期拍照，见证雕刻的成果',
                      style: _mutedStyle.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            )
          : SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: gs.progressPhotos.length,
                itemBuilder: (context, index) {
                  final photo = gs.progressPhotos[index];
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: AppColors.bg2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: photo.photoPath.isNotEmpty &&
                                  File(photo.photoPath).existsSync()
                              ? Image.file(
                                  File(photo.photoPath),
                                  width: 100,
                                  height: 120,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 100,
                                  height: 120,
                                  color: AppColors.bg,
                                  child: Icon(Icons.image_outlined,
                                      color: AppColors.text2, size: 32),
                                ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.bg.withValues(alpha: 0.82),
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(9)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  photo.date.length > 5
                                      ? photo.date.substring(5)
                                      : photo.date,
                                  style: AppFonts.body(
                                    fontSize: 9,
                                    color: AppColors.text2,
                                  ),
                                ),
                                if (photo.weight > 0)
                                  Text(
                                    '${photo.weight.toStringAsFixed(1)} kg',
                                    style: AppFonts.body(
                                      fontSize: 10,
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: ForgePressable(
                            onTap: () => notifier.removeProgressPhoto(photo.id),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: AppColors.bg.withValues(alpha: 0.75),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close,
                                  size: 14,
                                  color: AppColors.text2.withValues(alpha: 0.9)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Future<void> _addProgressPhoto(GameStateNotifier notifier) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final photoDir = Directory(path.join(appDir.path, 'progress_photos'));
      if (!await photoDir.exists()) {
        await photoDir.create(recursive: true);
      }

      final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destPath = path.join(photoDir.path, fileName);
      await File(picked.path).copy(destPath);

      final weight = ref.read(gameStateProvider).user.weight;
      final photo = ProgressPhoto(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now().toDateString(),
        photoPath: destPath,
        weight: weight,
      );
      await notifier.addProgressPhoto(photo);
      if (mounted) _showToast('照片已保存');
    } catch (e) {
      if (mounted) _showToast('添加照片失败: $e');
    }
  }

  Widget _buildExerciseTrends(GameState gs) {
    final today = DateTime.now().toDateString();
    final todayExercises =
        gs.exercises.where((e) => e.date == today).toList();

    return _sectionCard(
      icon: Icons.directions_run_outlined,
      title: '运动趋势',
      child: todayExercises.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '今日还没有运动记录，去锤炼一下吧！',
                  style: _mutedStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: _buildExerciseTypeList(todayExercises),
            ),
    );
  }

  List<Widget> _buildExerciseTypeList(List<ExerciseRecord> exercises) {
    final grouped = <String, Map<String, dynamic>>{};
    for (final e in exercises) {
      grouped.putIfAbsent(
          e.name, () => {'emoji': e.emoji, 'count': 0, 'duration': 0});
      grouped[e.name]!['count'] = (grouped[e.name]!['count'] as int) + 1;
      grouped[e.name]!['duration'] =
          (grouped[e.name]!['duration'] as int) + e.duration;
    }

    final sorted = grouped.entries.toList()
      ..sort((a, b) =>
          (b.value['duration'] as int).compareTo(a.value['duration'] as int));
    final top3 = sorted.take(3).toList();

    return top3.map((entry) {
      final name = entry.key;
      final count = entry.value['count'] as int;
      final duration = entry.value['duration'] as int;
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Icon(AppIcons.exerciseByName(name), size: 22, color: AppColors.copper),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: _bodyStyle.copyWith(fontSize: 14)),
                  Text('$count 次 · $duration 分钟',
                      style: _mutedStyle.copyWith(fontSize: 12)),
                ],
              ),
            ),
            Text(
              '$duration min',
              style: AppFonts.body(
                color: AppColors.copper,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSmoothedWeightChart(List<WeightRecord> records) {
    final logs = records
        .map((r) => core.WeightLogEntry(date: r.date, weightKg: r.weight))
        .toList();
    final window = logs.length >= 14 ? 14 : 7;
    final smoothed = core.smoothWeightSeries(logs, windowDays: window);
    final primary = <FlSpot>[
      for (var i = 0; i < smoothed.length; i++)
        FlSpot(i.toDouble(), smoothed[i]),
    ];
    final daily = <FlSpot>[
      for (var i = 0; i < records.length; i++)
        FlSpot(i.toDouble(), records[i].weight),
    ];
    return TrendLineChart(
      primary: primary,
      secondary: daily,
      showSecondary: true,
      labels: records.map((r) => r.date).toList(),
      primaryColor: AppColors.copper,
      secondaryColor: AppColors.text2,
    );
  }

  Widget _buildWaistChart(List<WaistRecord> records) {
    final primary = <FlSpot>[
      for (var i = 0; i < records.length; i++)
        FlSpot(i.toDouble(), records[i].waistCm),
    ];
    return TrendLineChart(
      primary: primary,
      labels: records.map((r) => r.date).toList(),
      primaryColor: AppColors.ember,
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: _bodyStyle),
        backgroundColor: AppColors.bg3,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
