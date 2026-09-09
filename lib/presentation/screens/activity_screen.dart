import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/bluetooth_provider.dart';
import '../providers/history_providers.dart';
import '../widgets/history_line_chart.dart';
import '../widgets/state_views.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  static const _metricTypes = [
    _MetricConfig(
      'steps',
      'Steps',
      Icons.directions_walk_outlined,
      Colors.green,
    ),
    _MetricConfig(
      'calories',
      'Calories',
      Icons.local_fire_department_outlined,
      Colors.deepOrange,
    ),
    _MetricConfig('distance', 'Distance', Icons.route_outlined, Colors.blue),
    _MetricConfig(
      'sleep_minutes',
      'Active recovery',
      Icons.bedtime_outlined,
      Colors.indigo,
    ),
    _MetricConfig(
      'hrv',
      'Intensity / HRV',
      Icons.monitor_heart_outlined,
      Colors.purple,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final container = ProviderScope.containerOf(context, listen: false);
        final connected =
            container.read(bluetoothNotifierProvider).connectedDevice != null;
        if (connected) {
          await container.read(syncNotifierProvider.notifier).syncNow();
        } else {
          container.read(activityRefreshProvider.notifier).bump();
          for (final metric in _metricTypes) {
            container.read(metricRefreshProvider(metric.type).notifier).bump();
          }
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
            title: const Text('Activity'),
            centerTitle: true,
          ),
          SliverList.list(
            children: [
              for (final metric in _metricTypes)
                _MetricChartSection(config: metric),
              const _StepHistoryList(),
              const SizedBox(height: 24),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChartSection extends ConsumerWidget {
  const _MetricChartSection({required this.config});

  final _MetricConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final samples = ref.watch(metricHistoryProvider(config.type));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(config.icon, color: config.color),
              const SizedBox(width: 8),
              Text(
                config.label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
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
                    if (items[i].valueNumeric != null)
                      FlSpot(i.toDouble(), items[i].valueNumeric!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepHistoryList extends ConsumerWidget {
  const _StepHistoryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepHistory = ref.watch(stepHistoryProvider);
    return AsyncBody(
      value: stepHistory,
      builder: (records) {
        if (records.isEmpty) {
          return const SizedBox(
            height: 220,
            child: EmptyState(
              icon: Icons.directions_walk_outlined,
              title: 'No activity history',
              message:
                  'Sync a bracelet to store daily steps, calories and distance.',
            ),
          );
        }
        return Column(
          children: [
            for (final record in records.reversed)
              ListTile(
                leading: const Icon(Icons.directions_walk_outlined),
                title: Text(
                  '${NumberFormat.decimalPattern().format(record.steps)} steps',
                ),
                subtitle: Text(DateFormat.yMMMd().format(record.date)),
                trailing: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${record.calories} kcal\n${record.distanceKm.toStringAsFixed(1)} km',
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
          ],
        );
      },
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
