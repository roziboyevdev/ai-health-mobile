import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../localization/app_strings.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/history_providers.dart';
import '../providers/settings_provider.dart';
import '../widgets/state_views.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const _DevicesAppBar(),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate(const [
              _ScanControlCard(),
              SizedBox(height: 12),
              _SavedDevicesSection(),
              SizedBox(height: 12),
              _ScanResultsSection(),
            ]),
          ),
        ),
      ],
    );
  }
}

class _DevicesAppBar extends ConsumerWidget {
  const _DevicesAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return SliverAppBar(
      pinned: true,
      toolbarHeight: 72,
      title: Text(strings.devices),
      centerTitle: false,
    );
  }
}

class _ScanControlCard extends ConsumerWidget {
  const _ScanControlCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final scanState = ref.watch(
      bluetoothNotifierProvider.select(
        (state) => (
          isBusy: state.isBusy,
          isScanning: state.isScanning,
          error: state.errorMessage,
          count: state.devices.length,
        ),
      ),
    );
    final showAllBle = ref.watch(
      settingsNotifierProvider.select((settings) => settings.showAllBleDevices),
    );
    final notifier = ref.read(bluetoothNotifierProvider.notifier);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  scanState.isScanning
                      ? Icons.bluetooth_searching_outlined
                      : Icons.watch_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    scanState.isScanning
                        ? showAllBle
                            ? (strings.isRu
                                ? 'Поиск BLE устройств (${scanState.count})'
                                : 'BLE qurilmalar qidirilmoqda (${scanState.count})')
                            : (strings.isRu
                                ? 'Поиск браслетов (${scanState.count})'
                                : 'Brasletlar qidirilmoqda (${scanState.count})')
                        : strings.connectedRequired,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: scanState.isBusy
                      ? null
                      : () => scanState.isScanning
                          ? notifier.stopScan()
                          : notifier.startScan(),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                  ),
                  icon: scanState.isScanning
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search_outlined),
                  label: Text(
                    scanState.isScanning
                        ? (strings.isRu ? 'Стоп' : 'To‘xtatish')
                        : (strings.isRu ? 'Поиск' : 'Qidirish'),
                  ),
                ),
              ],
            ),
            if (scanState.error != null) ...[
              const SizedBox(height: 12),
              Text(
                scanState.error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SavedDevicesSection extends ConsumerWidget {
  const _SavedDevicesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final devices = ref.watch(devicesHistoryProvider);
    final busy = ref.watch(bluetoothNotifierProvider.select((state) => state.isBusy));
    final notifier = ref.read(bluetoothNotifierProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.isRu ? 'Сохраненные устройства' : 'Saqlangan qurilmalar',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            devices.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: LinearProgressIndicator()),
              ),
              error: (error, stack) => Text(error.toString()),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.watch_off_outlined,
                    title: strings.noDevice,
                    message: strings.connectedRequired,
                  );
                }
                return Column(
                  children: [
                    for (final device in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.watch_outlined),
                        title: Text(device.name),
                        subtitle: Text(
                          [
                            device.macAddress ?? device.deviceId,
                            if (device.lastSeenAt != null)
                              DateFormat.MMMd().add_jm().format(device.lastSeenAt!),
                          ].join(' • '),
                        ),
                        trailing: device.isConnected
                            ? TextButton(
                                onPressed: busy
                                    ? null
                                    : () async {
                                        await notifier.disconnect();
                                        ref.read(devicesRefreshProvider.notifier).bump();
                                        ref.read(dashboardRefreshProvider.notifier).bump();
                                      },
                                child: Text(strings.isRu ? 'Отключить' : 'Uzish'),
                              )
                            : null,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanResultsSection extends ConsumerWidget {
  const _ScanResultsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final bluetooth = ref.watch(
      bluetoothNotifierProvider.select(
        (state) => (
          devices: state.devices,
          isBusy: state.isBusy,
          isScanning: state.isScanning,
        ),
      ),
    );
    final notifier = ref.read(bluetoothNotifierProvider.notifier);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.isRu ? 'Найденные устройства' : 'Topilgan qurilmalar',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            if (bluetooth.devices.isEmpty && !bluetooth.isScanning)
              EmptyState(
                icon: Icons.bluetooth_searching_outlined,
                title: strings.isRu ? 'Браслеты не найдены' : 'Braslet topilmadi',
                message: strings.isRu
                    ? 'Начните поиск рядом с включенным браслетом.'
                    : 'Yoniq braslet yonida qidirishni boshlang.',
              )
            else if (bluetooth.devices.isEmpty && bluetooth.isScanning)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (final device in bluetooth.devices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    device.isValdusFamily
                        ? Icons.watch_outlined
                        : Icons.bluetooth_outlined,
                    color: device.isValdusFamily ? theme.colorScheme.primary : null,
                  ),
                  title: Text(device.name),
                  subtitle: Text(
                    [
                      device.macAddress ?? device.id,
                      if (device.rssi != null) '${device.rssi} dBm',
                    ].join(' • '),
                  ),
                  trailing: FilledButton(
                    onPressed: bluetooth.isBusy
                        ? null
                        : () async {
                            await notifier.connect(device);
                            ref.read(devicesRefreshProvider.notifier).bump();
                            ref.read(dashboardRefreshProvider.notifier).bump();
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    child: Text(strings.isRu ? 'Подключить' : 'Ulash'),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
