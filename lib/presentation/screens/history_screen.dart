import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../localization/app_strings.dart';
import '../models/health_metric_ui.dart';
import '../providers/history_providers.dart';
import '../widgets/history_line_chart.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final definitions = healthMetricDefinitions(strings)
        .where((item) => item.type != HealthMetricType.ecg)
        .toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar.medium(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          title: Text(strings.history),
          centerTitle: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HistoryMetricCard(definition: definitions[index]),
              );
            },
              childCount: definitions.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryMetricCard extends ConsumerWidget {
  const _HistoryMetricCard({required this.definition});

  final HealthMetricDefinition definition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final samples = ref.watch(metricHistoryProvider(_metricType));
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/metric/${definition.type.slug}'),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        overlayColor: AppTheme.overlayFor(definition.color),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(definition.icon, color: definition.color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          definition.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          strings.last7Days,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: samples.when(
                  loading: () => const Center(
                    child: SizedBox(
                      width: 160,
                      child: LinearProgressIndicator(),
                    ),
                  ),
                  error: (error, stack) =>
                      Center(child: Text(error.toString())),
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
      ),
    );
  }

  String get _metricType {
    switch (definition.type) {
      case HealthMetricType.heart:
        return 'heart_rate';
      case HealthMetricType.spo2:
        return 'spo2';
      case HealthMetricType.sleep:
        return 'sleep_minutes';
      case HealthMetricType.met:
        return 'met';
      case HealthMetricType.bloodPressure:
        return 'blood_pressure';
      case HealthMetricType.stress:
        return 'stress';
      case HealthMetricType.steps:
        return 'steps';
      case HealthMetricType.ecg:
        return 'ecg';
    }
  }
}
