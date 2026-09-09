import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/bluetooth_provider.dart';
import '../providers/history_providers.dart';
import '../widgets/screen_header.dart';
import '../widgets/state_views.dart';

class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

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
          container.read(sleepRefreshProvider.notifier).bump();
          container
              .read(metricRefreshProvider('sleep_minutes').notifier)
              .bump();
          container
              .read(metricRefreshProvider('deep_sleep_minutes').notifier)
              .bump();
        }
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: const [
          ScreenHeader(title: 'Sleep', subtitle: 'Sessions and sleep stages'),
          _SleepHistorySection(),
        ],
      ),
    );
  }
}

class _SleepHistorySection extends ConsumerWidget {
  const _SleepHistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(sleepHistoryProvider);
    return AsyncBody(
      value: history,
      builder: (sessions) {
        if (sessions.isEmpty) {
          return const SizedBox(
            height: 360,
            child: EmptyState(
              icon: Icons.bedtime_outlined,
              title: 'No sleep history',
              message: 'Sync a connected band to show sleep sessions.',
            ),
          );
        }
        return Column(
          children: [
            for (final session in sessions.reversed)
              ListTile(
                leading: const Icon(Icons.nightlight_outlined),
                title: Text(
                  '${(session.totalMinutes / 60).toStringAsFixed(1)} hours',
                ),
                subtitle: Text(
                  '${DateFormat.MMMd().add_jm().format(session.startedAt)} - '
                  '${DateFormat.jm().format(session.endedAt)}',
                ),
                trailing: Text('${session.deepMinutes}m deep'),
              ),
          ],
        );
      },
    );
  }
}
