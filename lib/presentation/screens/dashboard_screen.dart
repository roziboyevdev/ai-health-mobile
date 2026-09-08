import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    SizedBox(
                      height: 150,
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.35,
                        physics: const NeverScrollableScrollPhysics(),
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
                            value: steps == null || steps == 0 ? '--' : '$steps',
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
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.battery_charging_full_outlined),
                      title: const Text('Battery'),
                      subtitle: Text(data.device?.model ?? 'No device information'),
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
