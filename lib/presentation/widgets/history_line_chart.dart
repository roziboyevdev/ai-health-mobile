import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class HistoryLineChart extends StatelessWidget {
  const HistoryLineChart({
    required this.points,
    required this.color,
    this.emptyLabel = 'No chart data yet',
    this.leftReservedSize = 44,
    super.key,
  });

  final List<FlSpot> points;
  final Color color;
  final String emptyLabel;
  final double leftReservedSize;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(child: Text(emptyLabel, textAlign: TextAlign.center));
    }

    final values = points.map((point) => point.y).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final rangePadding = ((maxY - minY).abs() * 0.12).clamp(1, double.infinity).toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        minY: minY == maxY ? minY - rangePadding : minY - rangePadding,
        maxY: minY == maxY ? maxY + rangePadding : maxY + rangePadding,
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: points.length > 1,
              reservedSize: 28,
              interval: (points.length / 4).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: leftReservedSize,
              getTitlesWidget: (value, meta) => Text(
                value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: points,
            isCurved: true,
            barWidth: 3,
            color: color,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
