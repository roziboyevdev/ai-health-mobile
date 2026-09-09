import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../localization/app_strings.dart';
import '../providers/history_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const _SettingsAppBar(),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate(const [
              _LanguageControl(),
              SizedBox(height: 12),
              _ThemeModeControl(),
              SizedBox(height: 12),
              _SyncCard(),
              SizedBox(height: 12),
              _DevicePasswordField(),
              SizedBox(height: 12),
              _ClearLocalDataTile(),
            ]),
          ),
        ),
      ],
    );
  }
}

class _SettingsAppBar extends ConsumerWidget {
  const _SettingsAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return SliverAppBar(
      pinned: true,
      toolbarHeight: 72,
      title: Text(strings.settings),
      centerTitle: false,
    );
  }
}

class _LanguageControl extends ConsumerWidget {
  const _LanguageControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final language = ref.watch(appLanguageProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);
    return _SettingsCard(
      icon: Icons.translate_outlined,
      title: strings.languageTitle,
      child: SegmentedButton<AppLanguage>(
        segments: [
          ButtonSegment(
            value: AppLanguage.uz,
            icon: const Icon(Icons.language_outlined),
            label: Text(strings.uzbek),
          ),
          ButtonSegment(
            value: AppLanguage.ru,
            icon: const Icon(Icons.language_outlined),
            label: Text(strings.russian),
          ),
        ],
        selected: {language},
        onSelectionChanged: (value) => notifier.setLanguage(value.first),
      ),
    );
  }
}

class _ThemeModeControl extends ConsumerWidget {
  const _ThemeModeControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final themeMode = ref.watch(
      settingsNotifierProvider.select((settings) => settings.themeMode),
    );
    final notifier = ref.read(settingsNotifierProvider.notifier);
    return _SettingsCard(
      icon: Icons.palette_outlined,
      title: strings.theme,
      child: SegmentedButton<ThemeMode>(
        segments: [
          ButtonSegment(
            value: ThemeMode.system,
            icon: const Icon(Icons.brightness_auto_outlined),
            label: Text(strings.system),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            icon: const Icon(Icons.light_mode_outlined),
            label: Text(strings.light),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: const Icon(Icons.dark_mode_outlined),
            label: Text(strings.dark),
          ),
        ],
        selected: {themeMode},
        onSelectionChanged: (value) => notifier.setThemeMode(value.first),
      ),
    );
  }
}

class _SyncCard extends ConsumerWidget {
  const _SyncCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final autoReconnect = ref.watch(
      settingsNotifierProvider.select((settings) => settings.autoReconnect),
    );
    final syncOnConnect = ref.watch(
      settingsNotifierProvider.select((settings) => settings.syncOnConnect),
    );
    final showAllBle = ref.watch(
      settingsNotifierProvider.select((settings) => settings.showAllBleDevices),
    );
    final notifier = ref.read(settingsNotifierProvider.notifier);
    return _SettingsCard(
      icon: Icons.sync_outlined,
      title: strings.syncNow,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: autoReconnect,
            onChanged: notifier.setAutoReconnect,
            title: Text(strings.autoReconnect),
            secondary: const Icon(Icons.bluetooth_connected_outlined),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: syncOnConnect,
            onChanged: notifier.setSyncOnConnect,
            title: Text(strings.syncOnConnect),
            secondary: const Icon(Icons.cloud_sync_outlined),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: showAllBle,
            onChanged: notifier.setShowAllBleDevices,
            title: Text(strings.showAllBle),
            secondary: const Icon(Icons.bluetooth_searching_outlined),
          ),
        ],
      ),
    );
  }
}

class _DevicePasswordField extends ConsumerWidget {
  const _DevicePasswordField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final password = ref.watch(
      settingsNotifierProvider.select((settings) => settings.devicePassword),
    );
    return _SettingsCard(
      icon: Icons.pin_outlined,
      title: strings.devicePassword,
      child: TextFormField(
        initialValue: password,
        decoration: InputDecoration(
          hintText: strings.devicePassword,
          floatingLabelBehavior: FloatingLabelBehavior.never,
          prefixIcon: const Icon(Icons.lock_outline),
        ),
        onChanged: ref.read(settingsNotifierProvider.notifier).setDevicePassword,
      ),
    );
  }
}

class _ClearLocalDataTile extends ConsumerWidget {
  const _ClearLocalDataTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.delete_outline),
        title: Text(strings.clearLocalData),
        subtitle: Text(strings.clearLocalDataHint),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final repository = ref.read(healthRepositoryProvider);
          await repository.clearAllData();
          ref.read(dashboardRefreshProvider.notifier).bump();
          ref.read(devicesRefreshProvider.notifier).bump();
          ref.read(heartRefreshProvider.notifier).bump();
          ref.read(activityRefreshProvider.notifier).bump();
          ref.read(sleepRefreshProvider.notifier).bump();
          for (final metricType in [
            'battery',
            'heart_rate',
            'spo2',
            'steps',
            'distance',
            'calories',
            'sleep_minutes',
            'deep_sleep_minutes',
            'hrv',
            'blood_pressure',
            'stress',
            'met',
            'ecg',
          ]) {
            ref.read(metricRefreshProvider(metricType).notifier).bump();
          }
        },
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
