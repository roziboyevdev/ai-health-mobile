import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/heart_rate_record.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/history_providers.dart';
import '../widgets/history_line_chart.dart';
import '../widgets/screen_header.dart';
import '../widgets/state_views.dart';

class HeartRateScreen extends ConsumerWidget {
  const HeartRateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(realTimeHealthProvider);
    final history = ref.watch(heartRateHistoryProvider);
    final color = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ScreenHeader(
          title: 'Heart Rate',
          subtitle: live?.heartRate == null ? 'Waiting for real-time data' : '${live!.heartRate} bpm now',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AsyncBody(
            value: history,
            builder: (records) => _HeartSummary(records: records, liveBpm: live?.heartRate),
          ),
        ),
        Padding(
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
        ),
        AsyncBody(
          value: history,
          builder: (records) {
            if (records.isEmpty) {
              return const SizedBox(
                height: 220,
                child: EmptyState(
                  icon: Icons.favorite_outline,
                  title: 'No heart history',
                  message: 'Connect a bracelet and sync to see recent heart-rate samples.',
                ),
              );
            }
            return Column(
              children: [
                for (final record in records.reversed.take(20))
                  ListTile(
                    leading: const Icon(Icons.favorite_outline),
                    title: Text('${record.bpm} bpm'),
                    subtitle: Text(DateFormat.yMMMd().add_jm().format(record.recordedAt)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HeartSummary extends StatelessWidget {
  const _HeartSummary({required this.records, this.liveBpm});

  final List<HeartRateRecord> records;
  final int? liveBpm;

  @override
  Widget build(BuildContext context) {
    final values = records.map((record) => record.bpm).toList();
    final avg = values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
    final min = values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b);
    final max = values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);
    return Row(
      children: [
        Expanded(child: _SummaryTile(label: 'Now', value: liveBpm == null ? '--' : '$liveBpm')),
        const SizedBox(width: 8),
        Expanded(child: _SummaryTile(label: 'Avg', value: avg == null ? '--' : avg.toStringAsFixed(0))),
        const SizedBox(width: 8),
        Expanded(child: _SummaryTile(label: 'Min/Max', value: min == null ? '--' : '$min/$max')),
      ],
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
            Text('$value bpm', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
