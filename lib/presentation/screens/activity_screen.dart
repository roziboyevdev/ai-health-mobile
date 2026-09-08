import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/history_providers.dart';
import '../widgets/history_line_chart.dart';
import '../widgets/screen_header.dart';
import '../widgets/state_views.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(stepHistoryProvider);
    final color = Theme.of(context).colorScheme.tertiary;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const ScreenHeader(title: 'Activity', subtitle: 'Steps, distance and calories'),
        SizedBox(
          height: 280,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: AsyncBody(
              value: history,
              builder: (records) => HistoryLineChart(
                color: color,
                points: [
                  for (var i = 0; i < records.length; i++)
                    FlSpot(i.toDouble(), records[i].steps.toDouble()),
                ],
              ),
            ),
          ),
        ),
        AsyncBody(
          value: history,
          builder: (records) => Column(
            children: [
              for (final record in records.reversed)
                ListTile(
                  leading: const Icon(Icons.directions_walk_outlined),
                  title: Text('${record.steps} steps'),
                  subtitle: Text(DateFormat.yMMMd().format(record.date)),
                  trailing: Text('${record.calories} kcal'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
