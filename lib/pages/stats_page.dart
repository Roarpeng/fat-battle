import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../constants/app_constants.dart';
import '../models/game_models.dart';
import '../providers/game_provider.dart';
import '../services/game_algorithm.dart';
import '../widgets/home/forge_background.dart';
import '../widgets/hp_bar.dart';

/// 进度页 — 锻造工坊视觉（方案 A）
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  final _weightController = TextEditingController();

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  TextStyle get _displayStyle => GoogleFonts.fraunces(
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      );

  TextStyle get _bodyStyle => GoogleFonts.figtree(color: AppColors.text);

  TextStyle get _mutedStyle =>
      GoogleFonts.figtree(color: AppColors.text2, fontSize: 13);

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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(),
              const SizedBox(height: 20),
              _sectionCard(
                icon: Icons.track_changes_outlined,
                title: '雕琢进度',
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
                    const SizedBox(height: 10),
                    ProgressBar(
                      percent: progress / 100,
                      text: '${progress.toStringAsFixed(1)}%',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildWaterCard(gameState, gameNotifier),
              const SizedBox(height: 14),
              _buildBmiCard(bmi, bodyType),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildStatCard('${gameState.kills}', '击杀怪物',
                      Icons.local_fire_department_outlined),
                  const SizedBox(width: 10),
                  _buildStatCard('${gameState.user.totalDamage.toInt()}',
                      '总伤害', Icons.bolt_outlined),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildStatCard('${gameState.user.totalExercise.toInt()}',
                      '总消耗(千卡)', Icons.fitness_center_outlined),
                  const SizedBox(width: 10),
                  _buildStatCard('${gameState.streak}', '连续天数',
                      Icons.calendar_today_outlined),
                ],
              ),
              const SizedBox(height: 14),
              _sectionCard(
                icon: Icons.view_week_outlined,
                title: '本周概览',
                child: gameState.weekData.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text('暂无数据', style: _mutedStyle),
                        ),
                      )
                    : Column(
                        children: gameState.weekData.map((d) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.bg2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
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
                                const SizedBox(width: 4),
                                Text(
                                  d.completed ? '完成' : '未完成',
                                  style: GoogleFonts.figtree(
                                    fontSize: 12,
                                    color: d.completed
                                        ? AppColors.green
                                        : AppColors.text2,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${d.calIn}入/${d.calExercise}出',
                                  style: _mutedStyle.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 14),
              _buildProgressGallery(gameState, gameNotifier),
              const SizedBox(height: 14),
              _buildExerciseTrends(gameState),
              const SizedBox(height: 14),
              _sectionCard(
                icon: Icons.monitor_weight_outlined,
                title: '记录今日体重',
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
                    const SizedBox(width: 10),
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
              const SizedBox(height: 14),
              _sectionCard(
                icon: Icons.show_chart_outlined,
                title: '体重趋势 (7日移动平均)',
                child: gameState.weightRecords.length < 2
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text('需要至少 2 天记录', style: _mutedStyle),
                        ),
                      )
                    : SizedBox(
                        height: 150,
                        child: _buildWeightChart(gameState.weightRecords),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本周雕琢',
            style: _displayStyle.copyWith(fontSize: 28, height: 1.15),
          ),
          const SizedBox(height: 6),
          Text(
            '称重、补水与回顾——在炉火旁记录每一刻变化',
            style: _mutedStyle.copyWith(height: 1.45),
          ),
        ],
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.copper, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: _displayStyle.copyWith(fontSize: 17),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
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
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: AppColors.bg,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.shield),
            ),
          ),
          const SizedBox(height: 6),
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
    return Material(
      color: AppColors.bg2,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.accessibility_new_outlined,
              color: AppColors.copper, size: 22),
          const SizedBox(width: 14),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bmiColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: bmiColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              bodyType,
              style: GoogleFonts.figtree(
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
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.copper, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: _displayStyle.copyWith(
                fontSize: 22,
                color: AppColors.copper,
              ),
            ),
            const SizedBox(height: 2),
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
        label: Text('添加', style: GoogleFonts.figtree(fontSize: 13)),
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
                                  style: GoogleFonts.figtree(
                                    fontSize: 9,
                                    color: AppColors.text2,
                                  ),
                                ),
                                if (photo.weight > 0)
                                  Text(
                                    '${photo.weight.toStringAsFixed(1)} kg',
                                    style: GoogleFonts.figtree(
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
                          child: GestureDetector(
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
      final emoji = entry.value['emoji'] as String;
      final count = entry.value['count'] as int;
      final duration = entry.value['duration'] as int;
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
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
              style: GoogleFonts.figtree(
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

  Widget _buildWeightChart(List<WeightRecord> records) {
    final maData = <MapEntry<String, double>>[];
    for (int i = 0; i < records.length; i++) {
      final start = i > 6 ? i - 6 : 0;
      final slice = records.sublist(start, i + 1);
      final avg = slice.fold(0.0, (s, r) => s + r.weight) / slice.length;
      maData.add(MapEntry(records[i].date, avg));
    }

    final weights = maData.map((e) => e.value).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b) - 1;
    final maxW = weights.reduce((a, b) => a > b ? a : b) + 1;
    final range = maxW - minW;

    return CustomPaint(
      painter: WeightChartPainter(
        data: maData,
        minWeight: minW,
        maxWeight: maxW,
        range: range,
      ),
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

/// 体重图表绘制器
class WeightChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> data;
  final double minWeight;
  final double maxWeight;
  final double range;

  WeightChartPainter({
    required this.data,
    required this.minWeight,
    required this.maxWeight,
    required this.range,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.copper
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = AppColors.ember
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    const padding = 20.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    for (int i = 0; i <= 4; i++) {
      final y = padding + (chartHeight / 4) * i;
      canvas.drawLine(
          Offset(padding, y), Offset(size.width - padding, y), gridPaint);
    }

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = padding + (i / (data.length - 1)) * chartWidth;
      final y =
          padding + (1 - (data[i].value - minWeight) / range) * chartHeight;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }

    canvas.drawPath(path, linePaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final step = (data.length / 5).ceil();
    for (int i = 0; i < data.length; i += step) {
      final x = padding + (i / (data.length - 1)) * chartWidth;
      textPainter.text = TextSpan(
        text: data[i].key.substring(5),
        style: GoogleFonts.figtree(color: AppColors.text2, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(x - textPainter.width / 2, size.height - 8));
    }

    for (int i = 0; i <= 4; i++) {
      final val = maxWeight - (range / 4) * i;
      final y = padding + (chartHeight / 4) * i;
      textPainter.text = TextSpan(
        text: val.toStringAsFixed(1),
        style: GoogleFonts.figtree(color: AppColors.text2, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(size.width - padding - textPainter.width, y - 4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
