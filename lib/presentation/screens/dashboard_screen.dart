import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../localization/app_strings.dart';
import '../models/health_metric_ui.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/history_providers.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final container = ProviderScope.containerOf(context, listen: false);
        if (container.read(bluetoothNotifierProvider).connectedDevice != null) {
          await container.read(syncNotifierProvider.notifier).syncNow();
        } else {
          container.read(dashboardRefreshProvider.notifier).bump();
        }
      },
      child: const CustomScrollView(
        slivers: [
          _HealthAppBar(),
          SliverToBoxAdapter(child: _WellnessSummary()),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            sliver: _MetricGrid(),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 24),
            sliver: SliverToBoxAdapter(child: _HistoryCard()),
          ),
        ],
      ),
    );
  }
}

class _HealthAppBar extends ConsumerWidget {
  const _HealthAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final deviceName = ref.watch(
      bluetoothNotifierProvider.select((state) => state.connectedDevice?.name),
    );
    final syncing = ref.watch(syncNotifierProvider).isLoading;

    return SliverAppBar(
      pinned: true,
      centerTitle: true,
      toolbarHeight: 72,
      expandedHeight: 132,
      title: Text(
        strings.health,
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Tooltip(
            message: strings.syncNow,
            child: IconButton.filledTonal(
              onPressed: syncing
                  ? null
                  : () async {
                      if (ref.read(bluetoothNotifierProvider).connectedDevice !=
                          null) {
                        await ref.read(syncNotifierProvider.notifier).syncNow();
                      } else {
                        ref.read(dashboardRefreshProvider.notifier).bump();
                      }
                    },
              icon: syncing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_outlined),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: FilledButton.tonalIcon(
              onPressed: () => context.go('/devices'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer,
              ),
              icon: Icon(
                deviceName == null
                    ? Icons.bluetooth_disabled_outlined
                    : Icons.bluetooth_connected_outlined,
              ),
              label: Text(
                deviceName ?? strings.noDevice,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WellnessSummary extends ConsumerWidget {
  const _WellnessSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final snapshot = ref.watch(dashboardSnapshotProvider);
    final liveSteps = ref.watch(
      bluetoothNotifierProvider.select((state) => state.realTimeHealth?.steps),
    );
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: snapshot.when(
            loading: () => const SizedBox(
              height: 210,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => SizedBox(
              height: 160,
              child: Center(child: Text(error.toString())),
            ),
            data: (data) {
              final steps = liveSteps ?? data.latestSteps?.steps ?? 0;
              final calories = data.statsFor('calories')?.latest ?? 0;
              final distance = data.statsFor('distance')?.latest ?? 0;
              return Column(
                children: [
                  SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _WellnessArcPainter(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.tertiary,
                          theme.colorScheme.secondary,
                        ],
                        progress: [
                          _progress(calories, 800),
                          _progress(steps, 10000),
                          _progress(distance, 7),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniGoal(
                          icon: Icons.local_fire_department_outlined,
                          label: strings.calories,
                          value: calories == 0
                              ? '--'
                              : NumberFormat.compact().format(calories),
                          goal: '/800 kkal',
                          color: Colors.deepOrange,
                        ),
                      ),
                      Expanded(
                        child: _MiniGoal(
                          icon: Icons.directions_walk_outlined,
                          label: strings.steps,
                          value: steps == 0
                              ? '--'
                              : NumberFormat.compact().format(steps),
                          goal: '/10 000',
                          color: Colors.indigo,
                        ),
                      ),
                      Expanded(
                        child: _MiniGoal(
                          icon: Icons.route_outlined,
                          label: strings.distance,
                          value: distance == 0
                              ? '--'
                              : distance.toStringAsFixed(1),
                          goal: '/7 km',
                          color: Colors.cyan,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double _progress(num value, num goal) {
    if (goal <= 0) return 0;
    return (value / goal).clamp(0, 1).toDouble();
  }
}

class _MetricGrid extends ConsumerWidget {
  const _MetricGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final definitions = healthMetricDefinitions(strings);
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final columns = width >= 720 ? 3 : 2;
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: width >= 720 ? 1 : 0.8,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _MetricCard(definition: definitions[index]),
            childCount: definitions.length,
          ),
        );
      },
    );
  }
}

class _MetricCard extends ConsumerWidget {
  const _MetricCard({required this.definition});

  final HealthMetricDefinition definition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final display = _displayValue(ref, strings, definition);
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/metric/${definition.type.slug}'),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        overlayColor: AppTheme.overlayFor(definition.color),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconBubble(icon: definition.icon, color: definition.color),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: theme.colorScheme.outline),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                definition.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  definition.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: display.value,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (display.unit.isNotEmpty)
                        TextSpan(
                          text: ' ${display.unit}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (display.status != null || definition.canMeasure) ...[
                const SizedBox(height: 8),
                _MetricStatusPill(
                  color: definition.color,
                  label: display.status ?? strings.measure,
                  icon: definition.canMeasure
                      ? Icons.play_arrow_rounded
                      : Icons.insights_outlined,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  MetricDisplayValue _displayValue(
    WidgetRef ref,
    AppStrings strings,
    HealthMetricDefinition definition,
  ) {
    final snapshot = ref.watch(dashboardSnapshotProvider).asData?.value;
    final live = ref.watch(
      bluetoothNotifierProvider.select((state) => state.realTimeHealth),
    );
    switch (definition.type) {
      case HealthMetricType.heart:
        final value = live?.heartRate ?? snapshot?.latestHeartRate?.bpm;
        return MetricDisplayValue(
          value: value == null ? '--' : '$value',
          unit: definition.unit,
          status: value == null ? strings.measure : strings.normal,
        );
      case HealthMetricType.spo2:
        final value = live?.spo2 ?? snapshot?.latestSpO2?.percentage;
        return MetricDisplayValue(
          value: value == null ? '--' : '$value',
          unit: '%',
          status: strings.measure,
        );
      case HealthMetricType.sleep:
        final minutes =
            snapshot?.latestSleep?.totalMinutes ??
            (snapshot?.summary?.sleepMinutes == 0
                ? null
                : snapshot?.summary?.sleepMinutes);
        return MetricDisplayValue(
          value: minutes == null ? '--' : (minutes / 60).toStringAsFixed(1),
          unit: minutes == null ? '' : definition.unit,
        );
      case HealthMetricType.met:
        final latest = snapshot?.statsFor('met')?.latest;
        return MetricDisplayValue(
          value: latest == null || latest == 0
              ? '--'
              : latest.toStringAsFixed(1),
          unit: latest == null ? '' : 'MET',
        );
      case HealthMetricType.steps:
        final value = live?.steps ?? snapshot?.latestSteps?.steps;
        return MetricDisplayValue(
          value: value == null || value == 0
              ? '--'
              : NumberFormat.compact().format(value),
        );
      case HealthMetricType.bloodPressure:
      case HealthMetricType.stress:
      case HealthMetricType.ecg:
        return MetricDisplayValue(value: '--', status: strings.measure);
    }
  }
}

class _MetricStatusPill extends StatelessWidget {
  const _MetricStatusPill({
    required this.color,
    required this.label,
    required this.icon,
  });

  final Color color;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.70), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => context.go('/history'),
        leading: _IconBubble(
          icon: Icons.stacked_line_chart_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          strings.history,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(strings.last7Days),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _MiniGoal extends StatelessWidget {
  const _MiniGoal({
    required this.icon,
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 6),
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          goal,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _WellnessArcPainter extends CustomPainter {
  const _WellnessArcPainter({required this.colors, required this.progress});

  final List<Color> colors;
  final List<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 1.02);
    final strokeWidth = math.min(size.width, size.height) * 0.10;
    for (var i = 0; i < colors.length; i++) {
      final radius = size.width * (0.42 - i * 0.075);
      final rect = Rect.fromCircle(center: center, radius: radius);
      final base = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = colors[i].withValues(alpha: 0.14);
      canvas.drawArc(rect, math.pi, math.pi, false, base);
      final active = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = colors[i].withValues(alpha: 0.48);
      canvas.drawArc(
        rect,
        math.pi,
        math.pi * progress[i].clamp(0, 1),
        false,
        active,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WellnessArcPainter oldDelegate) {
    return oldDelegate.colors != colors || oldDelegate.progress != progress;
  }
}
