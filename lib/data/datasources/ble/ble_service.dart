import 'ble_models.dart';

abstract interface class BleService {
  Stream<BleDevice> get scanResults;
  Stream<BleConnectionStateType> get connectionState;
  Stream<RealTimeHealthData> get realTimeHealth;

  Future<bool> requestPermissions();
  Future<BleStatus> bleStatus();
  Future<void> startScan();
  Future<void> stopScan();
  Future<BleDeviceInfo> connect(BleDevice device, {String password = '0000'});
  Future<void> disconnect();
  Future<BleDeviceInfo?> connectedDeviceInfo();
  Future<int?> readBatteryLevel();
  Future<HealthSyncResult> syncHealthHistory();
}
