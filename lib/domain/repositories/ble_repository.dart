import '../../data/datasources/ble/ble_models.dart';

abstract interface class BleRepository {
  Stream<BleDevice> get scanResults;
  Stream<BleConnectionStateType> get connectionState;
  Stream<RealTimeHealthData> get realTimeHealth;

  Future<bool> requestPermissions();
  Future<BleStatus> bleStatus();
  Future<void> startScan();
  Future<void> stopScan();
  Future<BleDeviceInfo> connect(BleDevice device, {required String password});
  Future<void> disconnect();
  Future<BleDeviceInfo?> connectedDeviceInfo();
  Future<int?> readBatteryLevel();
  Future<HealthSyncResult> syncHealthHistory();
}
