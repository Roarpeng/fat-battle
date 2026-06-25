import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../models/game_models.dart';
import '../providers/game_provider.dart';
import '../services/game_algorithm.dart';
import '../widgets/hp_bar.dart';

/// 统计页面
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});
  
  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  final _weightController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);
    
    if (!gameState.hasGame) {
      return const Center(child: Text('请先创建角色'));
    }
    
    final user = gameState.user;
    final progress = GameAlgorithm.calcProgress(
      gameState.weightRecords.isNotEmpty ? gameState.weightRecords.first.weight : user.weight,
      user.weight,
      user.targetWeight,
    );
    final bmi = GameAlgorithm.calcBMI(user.weight, user.height);
    final bodyType = GameAlgorithm.getBodyType(bmi);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 战斗统计'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 减肥进度
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🎯 减肥进度', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('当前: ${user.weight.toInt()}kg', style: TextStyle(color: AppColors.text2)),
                        Text('目标: ${user.targetWeight.toInt()}kg', style: TextStyle(color: AppColors.text2)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ProgressBar(
                      percent: progress / 100,
                      text: '${progress.toStringAsFixed(1)}%',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // BMI显示
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    bmi.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: bmi < 18.5 ? Colors.blue 
                          : bmi < 24 ? AppColors.green 
                          : bmi < 28 ? AppColors.gold 
                          : AppColors.red,
                    ),
                  ),
                  Text(bodyType),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 统计网格
            Row(
              children: [
                _buildStatCard('${gameState.kills}', '击杀怪物'),
                const SizedBox(width: 10),
                _buildStatCard('${gameState.user.totalDamage.toInt()}', '总伤害'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStatCard('${gameState.user.totalExercise.toInt()}', '总消耗(千卡)'),
                const SizedBox(width: 10),
                _buildStatCard('${gameState.streak}', '连续天数'),
              ],
            ),
            const SizedBox(height: 16),
            
            // 本周概览
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📅 本周概览', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (gameState.weekData.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text('暂无数据', style: TextStyle(color: AppColors.text2)),
                        ),
                      )
                    else
                      Column(
                        children: gameState.weekData.map((d) => 
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.bg2,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Text('Day ${d.day} - ${d.date}'),
                                const Spacer(),
                                Text(
                                  d.completed ? '✅ 完成' : '❌ 未完成',
                                  style: TextStyle(color: d.completed ? AppColors.green : AppColors.red),
                                ),
                                const SizedBox(width: 8),
                                Text('${d.calIn}入/${d.calExercise}出', style: TextStyle(color: AppColors.text2)),
                              ],
                            ),
                          ),
                        ).toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 记录体重
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⚖️ 记录今日体重', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _weightController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '输入体重(kg)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final weight = double.tryParse(_weightController.text);
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 体重趋势
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📈 体重趋势 (7日移动平均)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (gameState.weightRecords.length < 2)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text('需要至少2天记录', style: TextStyle(color: AppColors.text2)),
                        ),
                      )
                    else
                      SizedBox(
                        height: 150,
                        child: _buildWeightChart(gameState.weightRecords),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 统计卡片
  Widget _buildStatCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label, style: TextStyle(color: AppColors.text2, fontSize: 12)),
          ],
        ),
      ),
    );
  }
  
  /// 体重趋势图（简化版）
  Widget _buildWeightChart(List<WeightRecord> records) {
    // 计算移动平均
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
  
  /// 显示提示
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.card,
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
    final paint = Paint()
      ..color = AppColors.purple
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final dotPaint = Paint()
      ..color = AppColors.purple
      ..style = PaintingStyle.fill;
    
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;
    
    final padding = 20.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;
    
    // 绘制网格
    for (int i = 0; i <= 4; i++) {
      final y = padding + (chartHeight / 4) * i;
      canvas.drawLine(Offset(padding, y), Offset(size.width - padding, y), gridPaint);
    }
    
    // 绘制折线
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = padding + (i / (data.length - 1)) * chartWidth;
      final y = padding + (1 - (data[i].value - minWeight) / range) * chartHeight;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      
      // 绘制点
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
    
    canvas.drawPath(path, paint);
    
    // 绘制标签
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    // 日期标签
    final step = (data.length / 5).ceil();
    for (int i = 0; i < data.length; i += step) {
      final x = padding + (i / (data.length - 1)) * chartWidth;
      textPainter.text = TextSpan(
        text: data[i].key.substring(5),
        style: TextStyle(color: AppColors.text2, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - 8));
    }
    
    // 体重标签
    for (int i = 0; i <= 4; i++) {
      final val = maxWeight - (range / 4) * i;
      final y = padding + (chartHeight / 4) * i;
      textPainter.text = TextSpan(
        text: val.toStringAsFixed(1),
        style: TextStyle(color: AppColors.text2, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - padding - textPainter.width, y - 4));
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}