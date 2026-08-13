import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/forge_theme.dart';
import '../theme/tokens.dart';

/// 进度折线：主线（平滑/腰围）+ 可选次线（每日体重）。
class TrendLineChart extends StatelessWidget {
  final List<FlSpot> primary;
  final List<FlSpot> secondary;
  final List<String> labels;
  final Color primaryColor;
  final Color secondaryColor;
  final bool showSecondary;

  const TrendLineChart({
    super.key,
    required this.primary,
    this.secondary = const [],
    this.labels = const [],
    this.primaryColor = AppColors.copper,
    this.secondaryColor = AppColors.text2,
    this.showSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    if (primary.length < 2) {
      return Center(
        child: Text(
          '记录再多几天就能看到趋势',
          style: AppFonts.body(color: AppColors.text2, fontSize: 13),
        ),
      );
    }

    final ys = [
      ...primary.map((s) => s.y),
      if (showSecondary) ...secondary.map((s) => s.y),
    ];
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY).abs() < 0.5 ? 0.5 : (maxY - minY) * 0.15);

    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        minX: 0,
        maxX: (primary.length - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, _) => Text(
                value.toStringAsFixed(1),
                style: AppFonts.body(color: AppColors.text2, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: _bottomInterval(primary.length),
              getTitlesWidget: (value, _) {
                final i = value.round();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                final label = labels[i];
                final short = label.length > 5 ? label.substring(5) : label;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    short,
                    style: AppFonts.body(color: AppColors.text2, fontSize: 9),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: primary,
            isCurved: true,
            color: primaryColor,
            barWidth: 2.4,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: primaryColor.withValues(alpha: 0.12),
            ),
          ),
          if (showSecondary && secondary.length >= 2)
            LineChartBarData(
              spots: secondary,
              isCurved: false,
              color: secondaryColor.withValues(alpha: 0.45),
              barWidth: 1.2,
              dashArray: const [4, 4],
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 2.2,
                  color: secondaryColor.withValues(alpha: 0.7),
                  strokeWidth: 0,
                  strokeColor: Colors.transparent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _bottomInterval(int n) {
    if (n <= 6) return 1;
    return (n / 5).ceilToDouble();
  }
}
