import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/metric_sample.dart';
import '../providers/history_providers.dart';
import '../widgets/history_line_chart.dart';
import '../widgets/screen_header.dart';
import '../widgets/state_views.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  static const _metricTypes = [
    _MetricConfig('steps', 'Steps', Icons.directions_walk_outlined, Colors.green),
    _MetricConfig('calories', 'Calories', Icons.local_fire_department_outlined, Colors.deepOrange),
    _MetricConfig('distance', 'Distance', Icons.route_outlined, Colors.blue),
    _MetricConfig('sleep_minutes', 'Active recovery', Icons.bedtime_outlined, Colors.indigo),
    _MetricConfig('hrv', 'Intensity / HRV', Icons.monitor_heart_outlined, Colors.purple),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepHistory = ref.watch(stepHistoryProvider);
    final metricValues = {
      for (final metric in _metricTypes) metric.type: ref.watch(metricHistoryProvider(metric.type)),
    };

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const ScreenHeader(title: 'Activity', subtitle: 'Steps, calories, distance and bracelet activity metrics'),
        for (final metric in _metricTypes)
          _MetricChartSection(config: metric, samples: metricValues[metric.type]!),
        AsyncBody(
          value: stepHistory,
          builder: (records) {
            if (records.isEmpty) {
              return const SizedBox(
                height: 220,
                child: EmptyState(
                  icon: Icons.directions_walk_outlined,
                  title: 'No activity history',
                  message: 'Sync a bracelet to store daily steps, calories and distance.',
                ),
              );
            }
            return Column(
              children: [
                for (final record in records.reversed)
                  ListTile(
                    leading: const Icon(Icons.directions_walk_outlined),
                    title: Text('${NumberFormat.decimalPattern().format(record.steps)} steps'),
                    subtitle: Text(DateFormat.yMMMd().format(record.date)),
                    trailing: Text('${record.calories} kcal - ${record.distanceKm.toStringAsFixed(1)} km'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MetricChartSection extends StatelessWidget {
  const _MetricChartSection({required this.config, required this.samples});

  final _MetricConfig config;
  final AsyncValue<List<MetricSample>> samples;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(config.icon, color: config.color),
              const SizedBox(width: 8),
              Text(config.label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: AsyncBody(
              value: samples,
              builder: (items) => HistoryLineChart(
                color: config.color,
                emptyLabel: 'No ${config.label.toLowerCase()} data yet',
                points: [
                  for (var i = 0; i < items.length; i++)
                    if (items[i].valueNumeric != null) FlSpot(i.toDouble(), items[i].valueNumeric!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricConfig {
  const _MetricConfig(this.type, this.label, this.icon, this.color);

  final String type;
  final String label;
  final IconData icon;
  final Color color;
}
