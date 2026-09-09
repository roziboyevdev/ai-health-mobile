import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/bluetooth_provider.dart';
import '../providers/history_providers.dart';
import '../widgets/history_line_chart.dart';
import '../widgets/screen_header.dart';
import '../widgets/state_views.dart';

class HeartRateScreen extends StatelessWidget {
  const HeartRateScreen({super.key});

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
          container.read(heartRefreshProvider.notifier).bump();
          container.read(metricRefreshProvider('heart_rate').notifier).bump();
        }
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: const [
          _HeartHeader(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _HeartSummary(),
          ),
          _HeartChartSection(),
          _HeartHistoryList(),
        ],
      ),
    );
  }
}

class _HeartHeader extends ConsumerWidget {
  const _HeartHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveBpm = ref.watch(
      bluetoothNotifierProvider.select(
        (state) => state.realTimeHealth?.heartRate,
      ),
    );
    return ScreenHeader(
      title: 'Heart Rate',
      subtitle: liveBpm == null
          ? 'Waiting for real-time data'
          : '$liveBpm bpm now',
    );
  }
}

class _HeartSummary extends StatelessWidget {
  const _HeartSummary();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _LiveHeartTile()),
        SizedBox(width: 8),
        Expanded(child: _AverageHeartTile()),
        SizedBox(width: 8),
        Expanded(child: _MinMaxHeartTile()),
      ],
    );
  }
}

class _LiveHeartTile extends ConsumerWidget {
  const _LiveHeartTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveBpm = ref.watch(
      bluetoothNotifierProvider.select(
        (state) => state.realTimeHealth?.heartRate,
      ),
    );
    return _SummaryTile(
      label: 'Now',
      value: liveBpm == null ? '--' : '$liveBpm',
    );
  }
}

class _AverageHeartTile extends ConsumerWidget {
  const _AverageHeartTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(heartRateHistoryProvider);
    return AsyncBody(
      value: history,
      builder: (records) {
        final values = records.map((record) => record.bpm).toList();
        final avg = values.isEmpty
            ? null
            : values.reduce((a, b) => a + b) / values.length;
        return _SummaryTile(
          label: 'Avg',
          value: avg == null ? '--' : avg.toStringAsFixed(0),
        );
      },
    );
  }
}

class _MinMaxHeartTile extends ConsumerWidget {
  const _MinMaxHeartTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(heartRateHistoryProvider);
    return AsyncBody(
      value: history,
      builder: (records) {
        final values = records.map((record) => record.bpm).toList();
        final min = values.isEmpty
            ? null
            : values.reduce((a, b) => a < b ? a : b);
        final max = values.isEmpty
            ? null
            : values.reduce((a, b) => a > b ? a : b);
        return _SummaryTile(
          label: 'Min/Max',
          value: min == null ? '--' : '$min/$max',
        );
      },
    );
  }
}

class _HeartChartSection extends ConsumerWidget {
  const _HeartChartSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(heartRateHistoryProvider);
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        height: 260,
        child: AsyncBody(
          value: history,
          builder: (records) => HistoryLineChart(
            color: color,
            emptyLabel: 'No heart-rate samples yet',
            points: [
              for (var i = 0; i < records.length; i++)
                FlSpot(i.toDouble(), records[i].bpm.toDouble()),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeartHistoryList extends ConsumerWidget {
  const _HeartHistoryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(heartRateHistoryProvider);
    return AsyncBody(
      value: history,
      builder: (records) {
        if (records.isEmpty) {
          return const SizedBox(
            height: 220,
            child: EmptyState(
              icon: Icons.favorite_outline,
              title: 'No heart history',
              message:
                  'Connect a bracelet and sync to see recent heart-rate samples.',
            ),
          );
        }
        return Column(
          children: [
            for (final record in records.reversed.take(20))
              ListTile(
                leading: const Icon(Icons.favorite_outline),
                title: Text('${record.bpm} bpm'),
                subtitle: Text(
                  DateFormat.yMMMd().add_jm().format(record.recordedAt),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              '$value bpm',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
