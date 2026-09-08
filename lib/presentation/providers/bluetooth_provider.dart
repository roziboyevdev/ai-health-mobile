import 'dart:async';

import 'package:collection/collection.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/datasources/ble/ble_models.dart';
import '../../data/models/daily_summary.dart';
import '../../data/models/device.dart';
import '../../data/models/heart_rate_record.dart';
import '../../data/models/metric_sample.dart';
import '../../data/models/sleep_session.dart';
import '../../data/models/spo2_record.dart';
import '../../data/models/step_record.dart';
import 'repository_providers.dart';
import 'settings_provider.dart';

final bluetoothNotifierProvider =
    NotifierProvider<BluetoothNotifier, BluetoothState>(BluetoothNotifier.new);

final bluetoothProvider = bluetoothNotifierProvider;

final connectedDeviceProvider = Provider<Device?>((ref) {
  return ref.watch(bluetoothNotifierProvider).connectedDevice;
});

final realTimeHealthProvider = Provider<RealTimeHealthData?>((ref) {
  return ref.watch(bluetoothNotifierProvider).realTimeHealth;
});

class BluetoothState {
  const BluetoothState({
    this.connectionState = BleConnectionStateType.disconnected,
    this.devices = const [],
    this.connectedDevice,
    this.realTimeHealth,
    this.isScanning = false,
    this.isBusy = false,
    this.errorMessage,
    this.healthEpoch = 0,
  });

  final BleConnectionStateType connectionState;
  final List<BleDevice> devices;
  final Device? connectedDevice;
  final RealTimeHealthData? realTimeHealth;
  final bool isScanning;
  final bool isBusy;
  final String? errorMessage;
  final int healthEpoch;

  BluetoothState copyWith({
    BleConnectionStateType? connectionState,
    List<BleDevice>? devices,
    Device? connectedDevice,
    RealTimeHealthData? realTimeHealth,
    bool? isScanning,
    bool? isBusy,
    String? errorMessage,
    int? healthEpoch,
    bool clearConnectedDevice = false,
    bool clearError = false,
  }) {
    return BluetoothState(
      connectionState: connectionState ?? this.connectionState,
      devices: devices ?? this.devices,
      connectedDevice: clearConnectedDevice ? null : connectedDevice ?? this.connectedDevice,
      realTimeHealth: realTimeHealth ?? this.realTimeHealth,
      isScanning: isScanning ?? this.isScanning,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      healthEpoch: healthEpoch ?? this.healthEpoch,
    );
  }
}

class BluetoothNotifier extends Notifier<BluetoothState> {
  StreamSubscription<BleDevice>? _scanSub;
  StreamSubscription<BleConnectionStateType>? _connectionSub;
  StreamSubscription<RealTimeHealthData>? _healthSub;
  Timer? _scanTimeout;
  Timer? _catchUpSyncTimer;

  @override
  BluetoothState build() {
    final ble = ref.read(bleRepositoryProvider);
    _scanSub = ble.scanResults.listen(_onScanResult, onError: _onError);
    _connectionSub =
        ble.connectionState.listen((event) => state = state.copyWith(connectionState: event));
    _healthSub = ble.realTimeHealth.listen(_onHealthData, onError: _onError);
    ref.onDispose(() {
      _scanTimeout?.cancel();
      _catchUpSyncTimer?.cancel();
      _scanSub?.cancel();
      _connectionSub?.cancel();
      _healthSub?.cancel();
    });
    _hydrateConnectedDevice();
    return const BluetoothState();
  }

  Future<void> startScan() async {
    _scanTimeout?.cancel();
    state = state.copyWith(
      isBusy: true,
      clearError: true,
      devices: const [],
      isScanning: false,
    );
    try {
      final ble = ref.read(bleRepositoryProvider);
      final granted = await ble.requestPermissions();
      if (!granted) {
        state = state.copyWith(
          isBusy: false,
          errorMessage: 'Bluetooth permissions are required. Allow Nearby devices and try again.',
        );
        return;
      }
      final status = await ble.bleStatus();
      if (!status.bluetoothOn) {
        state = state.copyWith(
          isBusy: false,
          errorMessage: 'Bluetooth is turned off. Enable it and scan again.',
        );
        return;
      }
      if (status.androidSdk > 0 && status.androidSdk < 31 && !status.locationOn) {
        state = state.copyWith(
          isBusy: false,
          errorMessage: 'Turn on Location services to scan for nearby bands.',
        );
        return;
      }
      await ble.startScan();
      state = state.copyWith(isBusy: false, isScanning: true);
      _scanTimeout = Timer(const Duration(seconds: 25), stopScan);
    } catch (error) {
      _onError(error);
    }
  }

  Future<void> stopScan() async {
    _scanTimeout?.cancel();
    await ref.read(bleRepositoryProvider).stopScan();
    state = state.copyWith(isScanning: false);
  }

  Future<void> connect(BleDevice device) async {
    _scanTimeout?.cancel();
    state = state.copyWith(isBusy: true, clearError: true, isScanning: false);
    try {
      await ref.read(bleRepositoryProvider).stopScan();
      final settings = ref.read(settingsNotifierProvider);
      final info = await ref.read(bleRepositoryProvider).connect(
            device,
            password: settings.devicePassword,
          );
      final repository = ref.read(healthRepositoryProvider);
      await repository.markAllDisconnected();
      final model = Device()
        ..deviceId = info.deviceId
        ..name = info.name
        ..macAddress = info.macAddress
        ..firmware = info.firmware
        ..model = info.model
        ..batteryLevel = info.batteryLevel
        ..autoReconnect = settings.autoReconnect
        ..isConnected = true
        ..lastSeenAt = DateTime.now();
      await repository.upsertDevice(model);
      await repository.recordConnectionSession(deviceId: model.deviceId, startedAt: DateTime.now());
      if (settings.syncOnConnect) {
        final sync = await ref.read(bleRepositoryProvider).syncHealthHistory();
        await _persistSync(sync, model);
        if (sync.batteryLevel != null) {
          model.batteryLevel = sync.batteryLevel;
          await repository.upsertDevice(model);
        }
      }
      state = state.copyWith(
        connectedDevice: model,
        connectionState: BleConnectionStateType.connected,
        isBusy: false,
        healthEpoch: state.healthEpoch + 1,
      );
      _startCatchUpSync();
    } catch (error) {
      _onError(error);
    }
  }

  Future<void> syncHistory() async {
    final device = state.connectedDevice;
    if (device == null) {
      throw StateError('No band is connected.');
    }
    final sync = await ref.read(bleRepositoryProvider).syncHealthHistory();
    await _persistSync(sync, device);
    if (sync.batteryLevel != null) {
      device.batteryLevel = sync.batteryLevel;
      await ref.read(healthRepositoryProvider).upsertDevice(device);
      state = state.copyWith(connectedDevice: device, healthEpoch: state.healthEpoch + 1);
    } else {
      state = state.copyWith(healthEpoch: state.healthEpoch + 1);
    }
  }

  Future<void> disconnect() async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await ref.read(bleRepositoryProvider).disconnect();
      final repository = ref.read(healthRepositoryProvider);
      await repository.markAllDisconnected();
      state = state.copyWith(
        connectionState: BleConnectionStateType.disconnected,
        isBusy: false,
        clearConnectedDevice: true,
      );
      _catchUpSyncTimer?.cancel();
    } catch (error) {
      _onError(error);
    }
  }

  void _onScanResult(BleDevice device) {
    final existing = [...state.devices]..removeWhere((item) => item.id == device.id);
    existing.add(device);
    existing.sort((a, b) {
      if (a.isValdusFamily != b.isValdusFamily) {
        return a.isValdusFamily ? -1 : 1;
      }
      return (b.rssi ?? -999).compareTo(a.rssi ?? -999);
    });
    state = state.copyWith(devices: existing, isScanning: true);
  }

  Future<void> _onHealthData(RealTimeHealthData data) async {
    state = state.copyWith(realTimeHealth: data);
    final device = state.connectedDevice;
    if (device == null) return;
    final repository = ref.read(healthRepositoryProvider);
    device.lastSeenAt = data.recordedAt;
    if (data.batteryLevel != null && device.batteryLevel != data.batteryLevel) {
      device.batteryLevel = data.batteryLevel;
      await repository.upsertDevice(device);
    }
    await repository.saveMetricSamples([
      if (data.hrv != null)
        MetricSample(
          deviceId: device.deviceId,
          metricType: 'hrv',
          timestamp: data.recordedAt,
          valueNumeric: data.hrv!.toDouble(),
          unit: 'ms',
          rawPayload: {'hrv': data.hrv, 'source': 'live'},
        ),
      if (data.batteryLevel != null)
        MetricSample(
          deviceId: device.deviceId,
          metricType: 'battery',
          timestamp: data.recordedAt,
          valueNumeric: data.batteryLevel!.toDouble(),
          unit: '%',
          rawPayload: {'batteryLevel': data.batteryLevel, 'source': 'live'},
        ),
    ]);
    if (data.heartRate != null) {
      await repository.saveHeartRate(
        HeartRateRecord()
          ..deviceId = device.deviceId
          ..recordedAt = data.recordedAt
          ..bpm = data.heartRate!
          ..isRealtime = true,
      );
    }
    if (data.spo2 != null) {
      await repository.saveSpO2(
        SpO2Record()
          ..deviceId = device.deviceId
          ..recordedAt = data.recordedAt
          ..percentage = data.spo2!
          ..isRealtime = true,
      );
    }
    if (data.steps != null) {
      await repository.saveSteps(
        StepRecord()
          ..deviceId = device.deviceId
          ..date = DateTime(data.recordedAt.year, data.recordedAt.month, data.recordedAt.day)
          ..steps = data.steps!,
      );
    }
    state = state.copyWith(healthEpoch: state.healthEpoch + 1);
  }

  Future<void> _persistSync(HealthSyncResult sync, Device device) async {
    final repository = ref.read(healthRepositoryProvider);
    for (final sample in sync.heartRate.where((item) => item.bpm > 0)) {
      await repository.saveHeartRate(
        HeartRateRecord()
          ..deviceId = device.deviceId
          ..recordedAt = sample.recordedAt
          ..bpm = sample.bpm
          ..isRealtime = false,
      );
    }
    for (final sample in sync.spo2.where((item) => item.percentage > 0)) {
      await repository.saveSpO2(
        SpO2Record()
          ..deviceId = device.deviceId
          ..recordedAt = sample.recordedAt
          ..percentage = sample.percentage
          ..isRealtime = false,
      );
    }
    for (final sample in sync.steps.where((item) => item.steps > 0)) {
      await repository.saveSteps(
        StepRecord()
          ..deviceId = device.deviceId
          ..date = DateTime(sample.date.year, sample.date.month, sample.date.day)
          ..steps = sample.steps
          ..distanceKm = sample.distanceKm
          ..calories = sample.calories,
      );
    }
    for (final sample in sync.sleep.where((item) => item.totalMinutes > 0)) {
      await repository.saveSleep(
        SleepSession()
          ..deviceId = device.deviceId
          ..startedAt = sample.startedAt
          ..endedAt = sample.endedAt
          ..totalMinutes = sample.totalMinutes
          ..deepMinutes = sample.deepMinutes
          ..lightMinutes = sample.lightMinutes
          ..remMinutes = sample.remMinutes
          ..awakeMinutes = sample.awakeMinutes,
      );
    }

    final todaySteps = sync.steps.where((item) => item.steps > 0).fold<int>(0, (sum, item) {
      final sameDay = item.date.year == DateTime.now().year &&
          item.date.month == DateTime.now().month &&
          item.date.day == DateTime.now().day;
      return sameDay ? item.steps > sum ? item.steps : sum : sum;
    });
    final latestHr = sync.heartRate.where((item) => item.bpm > 0).lastOrNull?.bpm;
    final latestSpo2 = sync.spo2.where((item) => item.percentage > 0).lastOrNull?.percentage;
    final latestSleep = sync.sleep.where((item) => item.totalMinutes > 0).lastOrNull?.totalMinutes;
    await repository.upsertDailySummary(
      DailySummary()
        ..deviceId = device.deviceId
        ..date = DateTime.now()
        ..steps = todaySteps
        ..restingHeartRate = latestHr
        ..averageSpO2 = latestSpo2
        ..sleepMinutes = latestSleep ?? 0,
    );
  }

  Future<void> _hydrateConnectedDevice() async {
    final repository = ref.read(healthRepositoryProvider);
    final device = await repository.connectedDevice();
    if (device != null) {
      state = state.copyWith(connectedDevice: device);
      _startCatchUpSync();
    }
  }

  void _startCatchUpSync() {
    _catchUpSyncTimer?.cancel();
    _catchUpSyncTimer = Timer.periodic(const Duration(minutes: 30), (_) async {
      if (state.connectedDevice == null || state.connectionState != BleConnectionStateType.connected) {
        return;
      }
      try {
        await syncHistory();
      } catch (_) {
        // Background catch-up must not surface transient BLE failures over active UI state.
      }
    });
  }

  void _onError(Object error) {
    state = state.copyWith(isBusy: false, isScanning: false, errorMessage: error.toString());
  }
}
