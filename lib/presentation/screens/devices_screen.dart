import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/bluetooth_provider.dart';
import '../providers/history_providers.dart';
import '../widgets/screen_header.dart';
import '../widgets/state_views.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bluetooth = ref.watch(bluetoothNotifierProvider);
    final savedDevices = ref.watch(devicesHistoryProvider);
    final notifier = ref.read(bluetoothNotifierProvider.notifier);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ScreenHeader(
          title: 'Devices',
          subtitle: bluetooth.isScanning
              ? 'Scanning nearby BLE devices (${bluetooth.devices.length} found)'
              : bluetooth.connectionState.name,
          action: FilledButton.icon(
            onPressed: bluetooth.isBusy
                ? null
                : () => bluetooth.isScanning ? notifier.stopScan() : notifier.startScan(),
            icon: bluetooth.isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.search_outlined),
            label: Text(bluetooth.isScanning ? 'Stop' : 'Scan'),
          ),
        ),
        if (bluetooth.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              bluetooth.errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (bluetooth.isScanning || bluetooth.devices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              'Keep the band close and in pairing mode. VALDUS VANTA / VITRO should appear as VITRO or VANTA.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        AsyncBody(
          value: savedDevices,
          builder: (devices) {
            final connected = devices.where((device) => device.isConnected).toList();
            final disconnected = devices.where((device) => !device.isConnected).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionTitle('Connected devices'),
                if (connected.isEmpty)
                  const _EmptySection(message: 'No bracelet is connected.')
                else
                  for (final device in connected)
                    ListTile(
                      leading: const Icon(Icons.watch_outlined),
                      title: Text(device.name),
                      subtitle: Text(
                        [
                          device.macAddress ?? device.deviceId,
                          if (device.batteryLevel != null) '${device.batteryLevel}% battery',
                        ].join(' - '),
                      ),
                      trailing: TextButton(
                        onPressed: bluetooth.isBusy ? null : notifier.disconnect,
                        child: const Text('Disconnect'),
                      ),
                    ),
                const _SectionTitle('Disconnected / previously paired devices'),
                if (disconnected.isEmpty)
                  const _EmptySection(message: 'Previously paired devices will appear here.')
                else
                  for (final device in disconnected)
                    ListTile(
                      leading: const Icon(Icons.watch_outlined),
                      title: Text(device.name),
                      subtitle: Text(
                        [
                          device.macAddress ?? device.deviceId,
                          if (device.lastSeenAt != null)
                            'Last seen ${DateFormat.MMMd().add_jm().format(device.lastSeenAt!)}',
                        ].join(' - '),
                      ),
                    ),
              ],
            );
          },
        ),
        const _SectionTitle('Available scan results'),
        if (bluetooth.devices.isEmpty && !bluetooth.isScanning)
          const SizedBox(
            height: 260,
            child: EmptyState(
              icon: Icons.bluetooth_searching_outlined,
              title: 'No bands found',
              message:
                  'Start scanning near a powered smart band. Other BLE bracelets should appear too, including unnamed devices.',
            ),
          )
        else if (bluetooth.devices.isEmpty && bluetooth.isScanning)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          for (final device in bluetooth.devices)
            ListTile(
              leading: Icon(
                device.isValdusFamily ? Icons.watch_outlined : Icons.bluetooth_outlined,
                color: device.isValdusFamily ? theme.colorScheme.primary : null,
              ),
              title: Row(
                children: [
                  Flexible(child: Text(device.name)),
                  if (device.isValdusFamily) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: const Text('VALDUS'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      labelStyle: theme.textTheme.labelSmall,
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                [
                  device.macAddress ?? device.id,
                  if (device.rssi != null) '${device.rssi} dBm',
                ].join(' - '),
              ),
              trailing: FilledButton(
                onPressed: bluetooth.isBusy ? null : () => notifier.connect(device),
                child: const Text('Connect'),
              ),
            ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(message, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
