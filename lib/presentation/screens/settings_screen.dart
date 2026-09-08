import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/history_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/settings_provider.dart';
import '../widgets/screen_header.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const ScreenHeader(title: 'Settings', subtitle: 'Theme, password and sync'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('System')),
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (value) => notifier.setThemeMode(value.first),
          ),
        ),
        SwitchListTile(
          value: settings.autoReconnect,
          onChanged: notifier.setAutoReconnect,
          title: const Text('Auto reconnect'),
          secondary: const Icon(Icons.sync_outlined),
        ),
        SwitchListTile(
          value: settings.syncOnConnect,
          onChanged: notifier.setSyncOnConnect,
          title: const Text('Sync on connect'),
          secondary: const Icon(Icons.cloud_sync_outlined),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextFormField(
            initialValue: settings.devicePassword,
            decoration: const InputDecoration(
              labelText: 'Device password',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
            onChanged: notifier.setDevicePassword,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Clear local data'),
          subtitle: const Text('Removes devices and health history from this phone.'),
          onTap: () async {
            final repository = ref.read(healthRepositoryProvider);
            await repository.clearAllData();
            ref.invalidate(dashboardSnapshotProvider);
            ref.invalidate(heartRateHistoryProvider);
            ref.invalidate(spo2HistoryProvider);
            ref.invalidate(stepHistoryProvider);
            ref.invalidate(sleepHistoryProvider);
          },
        ),
      ],
    );
  }
}
