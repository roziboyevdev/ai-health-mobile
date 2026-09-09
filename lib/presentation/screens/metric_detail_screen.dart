import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/metric_sample.dart';
import '../localization/app_strings.dart';
import '../models/health_metric_ui.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/history_providers.dart';
import '../widgets/history_line_chart.dart';
import '../widgets/state_views.dart';

class MetricDetailScreen extends ConsumerWidget {
  const MetricDetailScreen({required this.type, super.key});

  final HealthMetricType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final definition = healthMetricDefinitions(strings).firstWhere(
      (item) => item.type == type,
      orElse: () => HealthMetricDefinition(
        type: HealthMetricType.steps,
        icon: Icons.directions_walk_outlined,
        color: Colors.indigo,
        title: strings.steps,
        description: strings.isRu ? 'Шаги за день' : 'Kunlik qadamlar',
      ),
    );
    final samples = _samples(ref);
    final stats = _stats(samples.asData?.value ?? const []);
    final isConnected = ref.watch(
      bluetoothNotifierProvider.select((state) => state.connectedDevice != null),
    );

    return RefreshIndicator(
      onRefresh: () async {
        final connected = ref.read(bluetoothNotifierProvider).connectedDevice != null;
        if (connected) {
          await ref.read(syncNotifierProvider.notifier).syncNow();
        } else {
          _refreshCurrent(ref);
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.medium(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/'),
            ),
            centerTitle: true,
            title: Text(definition.title),
            actions: [
              if (_canShare)
                IconButton(
                  tooltip: 'Share',
                  onPressed: null,
                  icon: const Icon(Icons.ios_share_outlined),
                ),
              IconButton(
                tooltip: strings.history,
                onPressed: () => context.go('/history'),
                icon: const Icon(Icons.calendar_month_outlined),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _DateNavigator(date: DateTime.now()),
                const SizedBox(height: 18),
                _SummaryCards(
                  definition: definition,
                  stats: stats,
                ),
                if (type == HealthMetricType.met) ...[
                  const SizedBox(height: 14),
                  _InfoCard(
                    icon: Icons.directions_walk_outlined,
                    title: strings.isRu ? 'Как рассчитывается?' : 'Qanday hisoblanadi?',
                    body: strings.metExplanation,
                    color: definition.color,
                  ),
                ],
                const SizedBox(height: 14),
                _DailyChartCard(
                  definition: definition,
                  stats: stats,
                  samples: samples,
                ),
                if (definition.canMeasure) ...[
                  const SizedBox(height: 14),
                  _MeasurementButton(
                    definition: definition,
                    isConnected: isConnected,
                  ),
                ],
                if (type == HealthMetricType.ecg) ...[
                  const SizedBox(height: 10),
                  _InfoCard(
                    icon: Icons.info_outline,
                    title: strings.howMeasured,
                    body: strings.ecgHelp,
                    color: definition.color,
                  ),
                ],
                const SizedBox(height: 14),
                _TrendCard(definition: definition, stats: stats, samples: samples),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canShare {
    return type == HealthMetricType.heart || type == HealthMetricType.met;
  }

  AsyncValue<List<MetricSample>> _samples(WidgetRef ref) {
    switch (type) {
      case HealthMetricType.heart:
        return ref.watch(metricHistoryProvider('heart_rate'));
      case HealthMetricType.spo2:
        return ref.watch(metricHistoryProvider('spo2'));
      case HealthMetricType.steps:
        return ref.watch(metricHistoryProvider('steps'));
      case HealthMetricType.sleep:
        return ref.watch(metricHistoryProvider('sleep_minutes'));
      case HealthMetricType.met:
        return ref.watch(metricHistoryProvider('met'));
      case HealthMetricType.bloodPressure:
        return ref.watch(metricHistoryProvider('blood_pressure'));
      case HealthMetricType.stress:
        return ref.watch(metricHistoryProvider('stress'));
      case HealthMetricType.ecg:
        return ref.watch(metricHistoryProvider('ecg'));
    }
  }

  void _refreshCurrent(WidgetRef ref) {
    switch (type) {
      case HealthMetricType.heart:
        ref.read(heartRefreshProvider.notifier).bump();
        ref.read(metricRefreshProvider('heart_rate').notifier).bump();
        break;
      case HealthMetricType.sleep:
        ref.read(sleepRefreshProvider.notifier).bump();
        ref.read(metricRefreshProvider('sleep_minutes').notifier).bump();
        break;
      case HealthMetricType.steps:
        ref.read(activityRefreshProvider.notifier).bump();
        ref.read(metricRefreshProvider('steps').notifier).bump();
        break;
      case HealthMetricType.spo2:
        ref.read(metricRefreshProvider('spo2').notifier).bump();
        break;
      case HealthMetricType.bloodPressure:
        ref.read(metricRefreshProvider('blood_pressure').notifier).bump();
        break;
      case HealthMetricType.stress:
        ref.read(metricRefreshProvider('stress').notifier).bump();
        break;
      case HealthMetricType.met:
        ref.read(metricRefreshProvider('met').notifier).bump();
        break;
      case HealthMetricType.ecg:
        ref.read(metricRefreshProvider('ecg').notifier).bump();
        break;
    }
  }
}

class _MetricStats {
  const _MetricStats({
    required this.latest,
    required this.average,
    required this.min,
    required this.max,
    required this.count,
    this.lastAt,
  });

  final double? latest;
  final double? average;
  final double? min;
  final double? max;
  final int count;
  final DateTime? lastAt;
}

_MetricStats _stats(List<MetricSample> samples) {
  final values = samples
      .where((item) => item.valueNumeric != null)
      .map((item) => item.valueNumeric!)
      .toList();
  if (values.isEmpty) {
    return const _MetricStats(
      latest: null,
      average: null,
      min: null,
      max: null,
      count: 0,
    );
  }
  return _MetricStats(
    latest: values.last,
    average: values.reduce((a, b) => a + b) / values.length,
    min: values.reduce((a, b) => a < b ? a : b),
    max: values.reduce((a, b) => a > b ? a : b),
    count: values.length,
    lastAt: samples.last.timestamp,
  );
}

class _DateNavigator extends StatelessWidget {
  const _DateNavigator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: Text(
              DateFormat('yyyy/MM/dd').format(date),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        IconButton.filledTonal(
          onPressed: null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _SummaryCards extends ConsumerWidget {
  const _SummaryCards({
    required this.definition,
    required this.stats,
  });

  final HealthMetricDefinition definition;
  final _MetricStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return Row(
      children: [
        Expanded(
          child: _MetricSummaryCard(
            icon: definition.icon,
            color: definition.color,
            label: strings.latest,
            value: _formatValue(stats.latest, definition),
            unit: definition.unit,
            footer: stats.latest == null ? strings.connectedRequired : strings.normal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricSummaryCard(
            icon: Icons.insert_chart_outlined,
            color: definition.color,
            label: strings.average,
            value: _formatValue(stats.average, definition),
            unit: definition.unit,
            footer: strings.isRu ? '${stats.count} измерений' : '${stats.count} ta o‘lchov',
          ),
        ),
      ],
    );
  }
}

class _MetricSummaryCard extends StatelessWidget {
  const _MetricSummaryCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
    required this.footer,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconBubble(icon: icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (unit.isNotEmpty)
                      TextSpan(
                        text: ' $unit',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              footer,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyChartCard extends ConsumerWidget {
  const _DailyChartCard({
    required this.definition,
    required this.stats,
    required this.samples,
  });

  final HealthMetricDefinition definition;
  final _MetricStats stats;
  final AsyncValue<List<MetricSample>> samples;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.dailyMetric,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 14),
            if (definition.type == HealthMetricType.heart) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: const Icon(Icons.circle, size: 10),
                  label: Text(
                    '${strings.normal} 60-100 ${definition.unit}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  backgroundColor: Colors.green.withValues(alpha: 0.12),
                  labelStyle: TextStyle(color: Colors.green.shade700),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              height: 220,
              child: samples.when(
                loading: () => const _ChartLoading(),
                error: (error, stack) => Center(child: Text(error.toString())),
                data: (items) {
                  if (definition.type == HealthMetricType.ecg) {
                    return _EcgGrid(color: definition.color, strings: strings);
                  }
                  if (items.isEmpty) {
                    return EmptyState(
                      icon: Icons.show_chart_outlined,
                      title: strings.noDataYet,
                      message: strings.connectedRequired,
                    );
                  }
                  return HistoryLineChart(
                    color: definition.color,
                    emptyLabel: strings.noDataYet,
                    points: [
                      for (var i = 0; i < items.length; i++)
                        if (items[i].valueNumeric != null)
                          FlSpot(i.toDouble(), items[i].valueNumeric!),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SmallStat(
                    value: _formatValue(stats.min, definition),
                    label: strings.min,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SmallStat(
                    value: _formatValue(stats.average, definition),
                    label: strings.average,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SmallStat(
                    value: _formatValue(stats.max, definition),
                    label: strings.max,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasurementButton extends ConsumerWidget {
  const _MeasurementButton({
    required this.definition,
    required this.isConnected,
  });

  final HealthMetricDefinition definition;
  final bool isConnected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: isConnected ? () {} : null,
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(isConnected ? strings.startMeasurement : strings.connectedRequired),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
          backgroundColor: definition.color,
        ),
      ),
    );
  }
}

class _TrendCard extends ConsumerWidget {
  const _TrendCard({
    required this.definition,
    required this.stats,
    required this.samples,
  });

  final HealthMetricDefinition definition;
  final _MetricStats stats;
  final AsyncValue<List<MetricSample>> samples;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.weeklyTrend,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${strings.average} '),
                  TextSpan(
                    text: _formatValue(stats.average, definition),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  if (definition.unit.isNotEmpty)
                    TextSpan(text: ' ${definition.unit}'),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: samples.when(
                loading: () => const Center(child: LinearProgressIndicator()),
                error: (error, stack) => Center(child: Text(error.toString())),
                data: (items) => HistoryLineChart(
                  color: definition.color,
                  emptyLabel: strings.noDataYet,
                  points: [
                    for (var i = 0; i < items.length; i++)
                      if (items[i].valueNumeric != null)
                        FlSpot(i.toDouble(), items[i].valueNumeric!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ChartLoading extends StatelessWidget {
  const _ChartLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 180,
        child: LinearProgressIndicator(),
      ),
    );
  }
}

class _EcgGrid extends StatelessWidget {
  const _EcgGrid({required this.color, required this.strings});

  final Color color;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _EcgGridPainter(color),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monitor_heart_outlined, size: 54, color: color),
            const SizedBox(height: 14),
            Text(
              strings.connectedRequired,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _EcgGridPainter extends CustomPainter {
  const _EcgGridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    const spacing = 32.0;
    for (var x = 0.0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EcgGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

String _formatValue(double? value, HealthMetricDefinition definition) {
  if (value == null || value == 0) return '--';
  switch (definition.type) {
    case HealthMetricType.heart:
    case HealthMetricType.spo2:
    case HealthMetricType.stress:
    case HealthMetricType.steps:
      return value.round().toString();
    case HealthMetricType.sleep:
      return (value / 60).toStringAsFixed(1);
    case HealthMetricType.met:
      return value.toStringAsFixed(1);
    case HealthMetricType.bloodPressure:
    case HealthMetricType.ecg:
      return value.round().toString();
  }
}
