import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class HistoryLineChart extends StatelessWidget {
  const HistoryLineChart({
    required this.points,
    required this.color,
    this.emptyLabel = 'No chart data yet',
    this.leftReservedSize = 40,
    super.key,
  });

  final List<FlSpot> points;
  final Color color;
  final String emptyLabel;
  final double leftReservedSize;

  @override
  Widget build(BuildContext context) {
    final validPoints =
        points.where((point) => point.x.isFinite && point.y.isFinite).toList()
          ..sort((a, b) => a.x.compareTo(b.x));

    if (validPoints.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(emptyLabel, textAlign: TextAlign.center),
        ),
      );
    }

    final values = validPoints.map((point) => point.y).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final rangePadding = ((maxY - minY).abs() * 0.12)
        .clamp(1, double.infinity)
        .toDouble();
    final minX = validPoints.first.x;
    final maxX = validPoints.last.x == minX ? minX + 1 : validPoints.last.x;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight || constraints.maxHeight < 48) {
          return const SizedBox.shrink();
        }

        final showBottom =
            validPoints.length > 1 && constraints.maxHeight >= 120;
        final showLeft = constraints.maxWidth >= 96;
        final labelStyle = Theme.of(context).textTheme.labelSmall;

        return Padding(
          padding: const EdgeInsets.only(right: 8, top: 8),
          child: LineChart(
            LineChartData(
              clipData: const FlClipData.all(),
              minX: minX,
              maxX: maxX,
              minY: minY - rangePadding,
              maxY: maxY + rangePadding,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(handleBuiltInTouches: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: showBottom,
                    reservedSize: 22,
                    interval: (validPoints.length / 4)
                        .ceilToDouble()
                        .clamp(1, double.infinity),
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      space: 2,
                      child: Text(
                        value.toInt().toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle,
                      ),
                    ),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: showLeft,
                    reservedSize: leftReservedSize,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      space: 4,
                      child: Text(
                        value.abs() >= 1000
                            ? '${(value / 1000).toStringAsFixed(1)}k'
                            : value.toStringAsFixed(0),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle,
                      ),
                    ),
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: validPoints,
                  isCurved: validPoints.length > 2,
                  preventCurveOverShooting: true,
                  barWidth: 3,
                  color: color,
                  dotData: FlDotData(show: validPoints.length < 3),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
