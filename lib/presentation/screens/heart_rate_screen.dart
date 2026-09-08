import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

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
        SizedBox(
          height: 280,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: AsyncBody(
              value: history,
              builder: (records) => HistoryLineChart(
                color: color,
                points: [
                  for (var i = 0; i < records.length; i++) FlSpot(i.toDouble(), records[i].bpm.toDouble()),
                ],
              ),
            ),
          ),
        ),
        AsyncBody(
          value: history,
          builder: (records) => Column(
            children: [
              for (final record in records.reversed.take(20))
                ListTile(
                  leading: const Icon(Icons.favorite_outline),
                  title: Text('${record.bpm} bpm'),
                  subtitle: Text(DateFormat.yMMMd().add_jm().format(record.recordedAt)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
