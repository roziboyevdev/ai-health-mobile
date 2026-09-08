import '../../domain/repositories/ble_repository.dart';
import '../datasources/ble/ble_models.dart';
import '../datasources/ble/ble_service.dart';

class BleRepositoryImpl implements BleRepository {
  const BleRepositoryImpl(this._service);

  final BleService _service;

  @override
  Stream<BleDevice> get scanResults => _service.scanResults;

  @override
  Stream<BleConnectionStateType> get connectionState => _service.connectionState;

  @override
  Stream<RealTimeHealthData> get realTimeHealth => _service.realTimeHealth;

  @override
  Future<BleDeviceInfo> connect(BleDevice device, {required String password}) =>
      _service.connect(device, password: password);

  @override
  Future<BleDeviceInfo?> connectedDeviceInfo() => _service.connectedDeviceInfo();

  @override
  Future<void> disconnect() => _service.disconnect();

  @override
  Future<int?> readBatteryLevel() => _service.readBatteryLevel();

  @override
  Future<bool> requestPermissions() => _service.requestPermissions();

  @override
  Future<BleStatus> bleStatus() => _service.bleStatus();

  @override
  Future<void> startScan() => _service.startScan();

  @override
  Future<void> stopScan() => _service.stopScan();

  @override
  Future<HealthSyncResult> syncHealthHistory() => _service.syncHealthHistory();
}
