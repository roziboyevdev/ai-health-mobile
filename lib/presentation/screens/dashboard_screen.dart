import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/metric_sample.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/history_providers.dart';
import '../widgets/metric_tile.dart';
import '../widgets/screen_header.dart';
import '../widgets/state_views.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(dashboardSnapshotProvider);
    final live = ref.watch(realTimeHealthProvider);
    final bluetooth = ref.watch(bluetoothNotifierProvider);

    return RefreshIndicator(
      onRefresh: () async {
        final connected = ref.read(bluetoothNotifierProvider).connectedDevice != null;
        if (connected) {
          await ref.read(syncNotifierProvider.notifier).syncNow();
        } else {
          ref.invalidate(dashboardSnapshotProvider);
        }
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ScreenHeader(
            title: 'AI Health',
            subtitle: bluetooth.connectedDevice?.name ?? 'Connect a smart band or BLE wearable',
            action: Icon(
              bluetooth.connectedDevice == null
                  ? Icons.bluetooth_disabled_outlined
                  : Icons.bluetooth_connected_outlined,
            ),
          ),
          AsyncBody(
            value: snapshot,
            builder: (data) {
              final heartRate = live?.heartRate ?? data.latestHeartRate?.bpm;
              final spo2 = live?.spo2 ?? data.latestSpO2?.percentage;
              final steps = live?.steps ?? data.latestSteps?.steps ?? data.summary?.steps;
              final sleep = data.latestSleep?.totalMinutes ??
                  (data.summary?.sleepMinutes == 0 ? null : data.summary?.sleepMinutes);
              final monthSteps = data.statsFor('steps');
              final monthHr = data.statsFor('heart_rate');
              final monthCalories = data.statsFor('calories');
              final monthDistance = data.statsFor('distance');
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 680 ? 4 : 2;
                        return GridView.count(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: constraints.maxWidth >= 680 ? 1.28 : 1.18,
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          children: [
                            MetricTile(
                              label: 'Heart rate',
                              value: heartRate == null ? '-- bpm' : '$heartRate bpm',
                              icon: Icons.favorite_outline,
                              color: Colors.redAccent,
                            ),
                            MetricTile(
                              label: 'SpO2',
                              value: spo2 == null ? '--%' : '$spo2%',
                              icon: Icons.air_outlined,
                              color: Colors.blueAccent,
                            ),
                            MetricTile(
                              label: 'Steps',
                              value: steps == null || steps == 0 ? '--' : NumberFormat.compact().format(steps),
                              icon: Icons.directions_walk_outlined,
                              color: Colors.green,
                            ),
                            MetricTile(
                              label: 'Sleep',
                              value: sleep == null ? '-- h' : '${(sleep / 60).toStringAsFixed(1)} h',
                              icon: Icons.bedtime_outlined,
                              color: Colors.indigoAccent,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _MonthStatsCard(
                      steps: monthSteps,
                      heartRate: monthHr,
                      calories: monthCalories,
                      distance: monthDistance,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.battery_charging_full_outlined),
                      title: const Text('Battery'),
                      subtitle: Text(
                        [
                          data.device?.model ?? 'No device information',
                          if (data.lastSyncAt != null)
                            'Last sample ${DateFormat.MMMd().add_jm().format(data.lastSyncAt!)}',
                        ].join(' - '),
                      ),
                      trailing: Text(
                        live?.batteryLevel != null
                            ? '${live!.batteryLevel}%'
                            : data.device?.batteryLevel == null
                                ? '--'
                                : '${data.device!.batteryLevel}%',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MonthStatsCard extends StatelessWidget {
  const _MonthStatsCard({
    required this.steps,
    required this.heartRate,
    required this.calories,
    required this.distance,
  });

  final MonthMetricStats? steps;
  final MonthMetricStats? heartRate;
  final MonthMetricStats? calories;
  final MonthMetricStats? distance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1-month statistics', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatChip(
                  label: 'Steps',
                  value: _whole(steps?.total),
                  delta: steps?.trendDelta,
                ),
                _StatChip(
                  label: 'Avg HR',
                  value: '${_whole(heartRate?.average)} bpm',
                  delta: heartRate?.trendDelta,
                ),
                _StatChip(
                  label: 'Calories',
                  value: '${_whole(calories?.total)} kcal',
                  delta: calories?.trendDelta,
                ),
                _StatChip(
                  label: 'Distance',
                  value: '${_fixed(distance?.total)} km',
                  delta: distance?.trendDelta,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _whole(num? value) => value == null || value == 0 ? '--' : NumberFormat.compact().format(value);
  static String _fixed(num? value) => value == null || value == 0 ? '--' : value.toStringAsFixed(1);
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, this.delta});

  final String label;
  final String value;
  final num? delta;

  @override
  Widget build(BuildContext context) {
    final deltaText = delta == null
        ? ''
        : delta! >= 0
            ? '+${NumberFormat.compact().format(delta)}'
            : NumberFormat.compact().format(delta);
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (deltaText.isNotEmpty) Text(deltaText, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
